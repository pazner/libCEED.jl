using libCEED, Printf

include("common.jl")
include("ex2-qfunction.jl")

function transform_mesh_coords!(dim, mesh_size, mesh_coords)
    @witharray mesh_coords MEM_HOST coords begin
        for i=1:mesh_size
            # map [0,1] to [0,1] varying the mesh density
            coords[i] = 0.5+1.0/sqrt(3.)*sin((2.0/3.0)*pi*(coords[i]-0.5))
        end
    end
    exact_sa = (dim==1 ? 2 : dim==2 ? 4 : 6)
end

function run_ex2(; ceed_spec, dim, mesh_order, sol_order, num_qpts, prob_size)
    dim = Int32(dim)
    mesh_order = Int32(mesh_order)
    sol_order = Int32(sol_order)
    num_qpts = Int32(num_qpts)
    prob_size = Int32(prob_size)

    ncompx = dim
    prob_size < 0 && (prob_size = 256*1024)
    gallery = true

    mesh_order = max(mesh_order, sol_order)
    sol_order = mesh_order

    ceed = Ceed(ceed_spec)
    mesh_basis = create_tensor_h1_lagrange_basis(ceed, dim, ncompx, mesh_order+1, num_qpts, GAUSS)
    sol_basis = create_tensor_h1_lagrange_basis(ceed, dim, 1, sol_order+1, num_qpts, GAUSS)

    nxyz = get_cartesian_mesh_size(dim, sol_order, prob_size)
    println("Mesh size: ", nxyz)

    # Build CeedElemRestriction objects describing the mesh and solution discrete
    # representations.
    mesh_size, mesh_restr, _ = build_cartesian_restriction(ceed, dim, nxyz, mesh_order, ncompx, num_qpts, mode=RestrictionOnly)
    sol_size, _, qdata_restr_i = build_cartesian_restriction(ceed, dim, nxyz, sol_order, div(dim*(dim+1),2), num_qpts, mode=StridedOnly)
    sol_size, sol_restr, sol_restr_i = build_cartesian_restriction(ceed, dim, nxyz, sol_order, 1, num_qpts, mode=RestrictionAndStrided)
    println("Number of mesh nodes     : ", div(mesh_size,dim))
    println("Number of solution nodes : ", sol_size)

    # Create a CeedVector with the mesh coordinates.
    mesh_coords = CeedVector(ceed, mesh_size)
    set_cartesian_mesh_coords!(dim, nxyz, mesh_order, mesh_coords)

    # Apply a transformation to the mesh.
    exact_sa = transform_mesh_coords!(dim, mesh_size, mesh_coords)

    # Create the Q-function that builds the diffusion operator (i.e. computes its
    # quadrature data) and set its context data.
    ctx = Context(ceed, BuildContext(dim, dim))
    if !gallery
        build_qfunc = create_interior_qfunction(ceed, 1, f_build_diff)
        add_input!(build_qfunc, "dx", ncompx*dim, EVAL_GRAD)
        add_input!(build_qfunc, "weights", 1, EVAL_WEIGHT)
        add_output!(build_qfunc, "qdata", div(dim*(dim+1),2), EVAL_NONE)
        set_context!(build_qfunc, ctx)
    else
        build_qfunc = create_interior_qfunction(ceed, "Poisson$(dim)DBuild")
    end

    # Create the operator that builds the quadrature data for the diffusion
    # operator.
    build_oper = Operator(ceed, build_qfunc, QFunctionNone(), QFunctionNone())
    set_field!(build_oper, "dx", mesh_restr, mesh_basis, CeedVectorActive())
    set_field!(build_oper, "weights", ElemRestrictionNone(), mesh_basis, CeedVectorNone())
    set_field!(build_oper, "qdata", qdata_restr_i, BasisCollocated(), CeedVectorActive())

    # Compute the quadrature data for the diffusion operator.
    elem_qpts = num_qpts^dim
    num_elem = prod(nxyz)
    qdata = CeedVector(ceed, num_elem*elem_qpts*div(dim*(dim+1),2))
    print("Computing the quadrature data for the diffusion operator ...")
    flush(stdout)
    apply!(build_oper, mesh_coords, qdata, RequestImmediate())
    println(" done.")

    # Create the Q-function that defines the action of the diffusion operator.
    if !gallery
        apply_qfunc = create_interior_qfunction(ceed, 1, f_apply_diff)
        add_input!(apply_qfunc, "du", dim, EVAL_GRAD)
        add_input!(apply_qfunc, "qdata", div(dim*(dim+1),2), EVAL_NONE)
        add_output!(apply_qfunc, "dv", dim, EVAL_GRAD)
        set_context!(apply_qfunc, ctx)
    else
        apply_qfunc = create_interior_qfunction(ceed, "Poisson$(dim)DApply")
    end

    # Create the diffusion operator.
    oper = Operator(ceed, apply_qfunc, QFunctionNone(), QFunctionNone())
    set_field!(oper, "du", sol_restr, sol_basis, CeedVectorActive())
    set_field!(oper, "qdata", qdata_restr_i, BasisCollocated(), qdata)
    set_field!(oper, "dv", sol_restr, sol_basis, CeedVectorActive())

    # Compute the mesh surface area using the diff operator:
    #                                             sa = 1^T \cdot abs( K \cdot x).
    print("Computing the mesh surface area using the formula: sa = 1^T.|K.x| ...")
    flush(stdout)

    # Create auxiliary solution-size vectors.
    u = CeedVector(ceed, sol_size)
    v = CeedVector(ceed, sol_size)
    # Initialize 'u' with sum of coordinates, x+y+z.
    @witharray_read(mesh_coords, MEM_HOST, x_host,
        @witharray(u, MEM_HOST, u_host, begin
            for i=1:sol_size
                u_host[i] = 0.0
                for d=1:dim
                    u_host[i] += x_host[i + (d-1)*sol_size]
                end
            end
        end))

    # Apply the diffusion operator: 'u' -> 'v'.
    apply!(oper, u, v, RequestImmediate())
    sa = witharray_read(x -> sum(abs,x), v, MEM_HOST)

    println(" done.")
    @printf("Exact mesh surface area    : % .14g\n", exact_sa)
    @printf("Computed mesh surface area : % .14g\n", sa)
    @printf("Surface area error         : % .14g\n", sa-exact_sa)
end

run_ex2(
   ceed_spec  = "/cpu/self",
   dim        = 3,
   mesh_order = 4,
   sol_order  = 4,
   num_qpts   = 6,
   prob_size  = -1
)

using Profile

@time @profile run_ex2(
   ceed_spec  = "/cpu/self",
   dim        = 3,
   mesh_order = 4,
   sol_order  = 4,
   num_qpts   = 6,
   prob_size  = 10000000
)

open("prof", write=true) do f
    Profile.print(f)
end

open("prof_flat", write=true) do f
    Profile.print(f, format=:flat, sortedby=:count)
end

function prof()

end
