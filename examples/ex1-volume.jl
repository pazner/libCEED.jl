using libCEED, Printf

include("common.jl")
include("ex1-qfunction.jl")

function transform_mesh_coords!(dim, mesh_size, mesh_coords)
    @witharray mesh_coords MEM_HOST coords begin
        if dim == 1
            for i=1:mesh_size
                # map [0,1] to [0,1] varying the mesh density
                coords[i] = 0.5+1.0/sqrt(3.)*sin((2.0/3.0)*pi*(coords[i]-0.5))
            end
            exact_volume = 1.0
        else
            num_nodes = div(mesh_size, dim)
            for i=1:num_nodes
                # map (x,y) from [0,1]x[0,1] to the quarter annulus with polar
                # coordinates, (r,phi) in [1,2]x[0,pi/2] with area = 3/4*pi
                u = coords[i]
                v = coords[i+num_nodes]
                u = 1.0+u;
                v = pi/2*v;
                coords[i] = u*cos(v)
                coords[i+num_nodes] = u*sin(v)
            end
            exact_volume = 3.0/4.0*pi
        end
        return exact_volume
    end
end

function run_ex1(; ceed_spec, dim, mesh_order, sol_order, num_qpts, prob_size)
    ncompx = dim
    prob_size < 0 && (prob_size = 256*1024)

    gallery = false

    c = Ceed(ceed_spec)
    mesh_basis = create_tensor_h1_lagrange_basis(c, dim, ncompx, mesh_order+1, num_qpts, GAUSS)
    sol_basis = create_tensor_h1_lagrange_basis(c, dim, 1, sol_order+1, num_qpts, GAUSS)

    # Determine the mesh size based on the given approximate problem size.
    nxyz = get_cartesian_mesh_size(dim, sol_order, prob_size)
    println("Mesh size: ", nxyz)

    # Build CeedElemRestriction objects describing the mesh and solution discrete
    # representations.
    mesh_size, mesh_restr, _ = build_cartesian_restriction(c, dim, nxyz, mesh_order, ncompx, num_qpts)
    sol_size, sol_restr, sol_restr_i = build_cartesian_restriction(c, dim, nxyz, sol_order, 1, num_qpts, mode=RestrictionAndStrided)
    println("Number of mesh nodes     : ", div(mesh_size,dim))
    println("Number of solution nodes : ", sol_size)

    # Create a CeedVector with the mesh coordinates.
    mesh_coords = CeedVector(c, mesh_size)
    set_cartesian_mesh_coords!(dim, nxyz, mesh_order, mesh_coords)
    # Apply a transformation to the mesh.
    exact_vol = transform_mesh_coords!(dim, mesh_size, mesh_coords);

    ctx = Context(c, BuildContext(dim, dim))
    # Create the Q-function that builds the mass operator (i.e. computes its
    # quadrature data) and set its context data.
    if !gallery
        build_qfunc = create_interior_qfunction(c, 1, f_build_mass)
        add_input!(build_qfunc, "dx", ncompx*dim, EVAL_GRAD)
        add_input!(build_qfunc, "weights", 1, EVAL_WEIGHT)
        add_output!(build_qfunc, "qdata", 1, EVAL_NONE)
        set_context!(build_qfunc, ctx)
    else
        build_qfunc = create_interior_qfunction(c, "Mass$(dim)DBuild")
    end

    # Create the operator that builds the quadrature data for the mass operator.
    build_oper = Operator(c, build_qfunc, QFunctionNone(), QFunctionNone())
    set_field!(build_oper, "dx", mesh_restr, mesh_basis, CeedVectorActive())
    set_field!(build_oper, "weights", ElemRestrictionNone(), mesh_basis, CeedVectorNone())
    set_field!(build_oper, "qdata", sol_restr_i, BasisCollocated(), CeedVectorActive())

    # Compute the quadrature data for the mass operator.
    elem_qpts = num_qpts^dim
    num_elem = prod(nxyz)
    qdata = CeedVector(c, num_elem*elem_qpts)

    print("Computing the quadrature data for the mass operator ...")
    flush(stdout)
    GC.@preserve ctx apply!(build_oper, mesh_coords, qdata, RequestImmediate())
    apply!(build_oper, mesh_coords, qdata, RequestImmediate())
    println(" done.")

    # Create the Q-function that defines the action of the mass operator.
    if !gallery
        apply_qfunc = create_interior_qfunction(c, 1, f_apply_mass)
        add_input!(apply_qfunc, "u", 1, EVAL_INTERP)
        add_input!(apply_qfunc, "qdata", 1, EVAL_NONE)
        add_output!(apply_qfunc, "v", 1, EVAL_INTERP)
    else
        apply_qfunc = create_interior_qfunction(c, "MassApply")
    end

    # Create the mass operator.
    oper = Operator(c, apply_qfunc, QFunctionNone(), QFunctionNone())
    set_field!(oper, "u", sol_restr, sol_basis, CeedVectorActive())
    set_field!(oper, "qdata", sol_restr_i, BasisCollocated(), qdata)
    set_field!(oper, "v", sol_restr, sol_basis, CeedVectorActive())

    # Compute the mesh volume using the mass operator: vol = 1^T \cdot M \cdot 1
    print("Computing the mesh volume using the formula: vol = 1^T.M.1 ...")
    flush(stdout)
    # Create auxiliary solution-size vectors.
    u = CeedVector(c, sol_size)
    v = CeedVector(c, sol_size)
    # Initialize 'u' with ones.
    u[] = 1.0
    # Apply the mass operator: 'u' -> 'v'.
    apply!(oper, u, v, RequestImmediate())
    # Compute and print the sum of the entries of 'v' giving the mesh volume.
    vol = witharray_read(sum, v, MEM_HOST)

    println(" done.")
    @printf("Exact mesh volume    : % .14g\n", exact_vol)
    @printf("Computed mesh volume : % .14g\n", vol)
    @printf("Volume error         : % .14g\n", vol-exact_vol)
end

run_ex1(
    ceed_spec  = "/cpu/self",
    dim        = 3,
    mesh_order = 4,
    sol_order  = 4,
    num_qpts   = 4+2,
    prob_size  = -1)
