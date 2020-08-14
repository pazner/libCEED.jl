using libCEED.C, Printf

include("ex1-qfunction-c.jl")

function get_cartesian_mesh_size(dim, order, prob_size)
   dims = zeros(Int,dim)
   # Use the approximate formula:
   #    prob_size ~ num_elem * order^dim
   num_elem = div(prob_size,order^dim)
   s = 0 # find s: num_elem/2 < 2^s <= num_elem

   while num_elem > 1
      num_elem /= 2
      s += 1
   end

   r = s%dim
   for d=1:dim
      sd = div(s,dim)
      if r > 0
         sd += 1
         r -= 1
      end
      dims[d] = 2^sd
   end
   dims
end

function build_cartesian_restriction(ceed, dim, nxyz, order, ncomp, num_qpts; form_strided=false)
   p = order
   pp1 = p+1
   nnodes = pp1^dim # number of scal. nodes per element
   elem_qpts = num_qpts^dim # number of qpts per element
   num_elem = 1
   scalar_size = 1

   nd = p*nxyz .+ 1
   num_elem = prod(nxyz)
   scalar_size = prod(nd)
   size = scalar_size*ncomp

   # elem:         0             1                 n-1
   #        |---*-...-*---|---*-...-*---|- ... -|--...--|
   # nnodes:   0   1    p-1  p  p+1       2*p             n*p

   el_nodes = zeros(CeedInt, num_elem*nnodes)
   for e=0:(num_elem-1)
      exyz = ones(Int, dim)
      re = e
      for d=1:dim
         exyz[d] = re%nxyz[d]
         re = div(re, nxyz[d])
      end
      for lnodes=0:(nnodes-1)
         gnodes = 0
         gnodes_stride = 1
         rnodes = lnodes
         for d=1:dim
            gnodes += (exyz[d]*p + rnodes%pp1) * gnodes_stride
            gnodes_stride *= nd[d]
            rnodes = div(rnodes, pp1)
         end
         el_nodes[e*nnodes + lnodes + 1] = gnodes
      end
   end

   restr = Ref{CeedElemRestriction}()
   CeedElemRestrictionCreate(ceed[], num_elem, nnodes, ncomp, scalar_size,
                             ncomp*scalar_size, CEED_MEM_HOST, CEED_COPY_VALUES,
                             el_nodes, restr)
   if form_strided
      restr_i = Ref{CeedElemRestriction}()
      err = CeedElemRestrictionCreateStrided(ceed[], num_elem, elem_qpts,
                                             ncomp, ncomp*elem_qpts*num_elem,
                                             CEED_STRIDES_BACKEND[], restr_i)
      return size, restr, restr_i
   else
      return size, restr
   end
end

function set_cartesian_mesh_coords(dim, nxyz, mesh_order, mesh_coords)
   p = mesh_order
   nd = p*nxyz .+ 1
   num_elem = prod(nxyz)
   scalar_size = prod(nd)

   coords_ref = Ref{Ptr{CeedScalar}}()
   CeedVectorGetArray(mesh_coords[], CEED_MEM_HOST, coords_ref)
   coords = unsafe_wrap(Array, coords_ref[], scalar_size*dim)

   nodes = zeros(CeedScalar, p+1)
   # The H1 basis uses Lobatto quadrature points as nodes.
   CeedLobattoQuadrature(p+1, nodes, C_NULL) # nodes are in [-1,1]
   nodes = 0.5 .+ 0.5*nodes
   for gsnodes=0:(scalar_size-1)
      rnodes = gsnodes
      for d=1:dim
         d1d = rnodes%nd[d]
         coords[gsnodes+scalar_size*(d-1) + 1] = (div(d1d,p)+nodes[d1d%p+1]) / nxyz[d]
         rnodes = div(rnodes, nd[d])
      end
   end
   CeedVectorRestoreArray(mesh_coords[], coords_ref)
end

function transform_mesh_coords(dim, mesh_size, mesh_coords)
   coords_ref = Ref{Ptr{CeedScalar}}()
   CeedVectorGetArray(mesh_coords[], CEED_MEM_HOST, coords_ref)
   coords = unsafe_wrap(Array, coords_ref[], mesh_size)

   if dim == 1
      for i=1:mesh_size
         # map [0,1] to [0,1] varying the mesh density
         coords[i] = 0.5+1.0/sqrt(3.)*sin((2.0/3.0)*pi*(coords[i]-0.5))
      end
      exact_volume = 1
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

   CeedVectorRestoreArray(mesh_coords[], coords_ref)
   return exact_volume
end

ceed_spec = "/cpu/self"
dim = 3
ncompx = dim
mesh_order = 4
sol_order = 4
num_qpts = sol_order+2
prob_size = 256*1024

ceed = Ref{Ceed}()
CeedInit(ceed_spec, ceed)

mesh_basis = Ref{CeedBasis}()
sol_basis = Ref{CeedBasis}()
CeedBasisCreateTensorH1Lagrange(ceed[], dim, ncompx, mesh_order+1, num_qpts, CEED_GAUSS, mesh_basis)
CeedBasisCreateTensorH1Lagrange(ceed[], dim, 1, sol_order+1, num_qpts, CEED_GAUSS, sol_basis)

# Determine the mesh size based on the given approximate problem size.
nxyz = get_cartesian_mesh_size(dim, sol_order, prob_size)
println("Mesh size: ", nxyz)

# Build CeedElemRestriction objects describing the mesh and solution discrete
# representations.
mesh_size, mesh_restr = build_cartesian_restriction(ceed, dim, nxyz, mesh_order, ncompx, num_qpts)
sol_size, sol_restr, sol_restr_i = build_cartesian_restriction(ceed, dim, nxyz, sol_order, 1, num_qpts, form_strided=true)
println("Number of mesh nodes     : ", div(mesh_size,dim))
println("Number of solution nodes : ", sol_size)

# Create a CeedVector with the mesh coordinates.
mesh_coords = Ref{CeedVector}()
CeedVectorCreate(ceed[], mesh_size, mesh_coords)
set_cartesian_mesh_coords(dim, nxyz, mesh_order, mesh_coords)
# Apply a transformation to the mesh.
exact_vol = transform_mesh_coords(dim, mesh_size, mesh_coords);

# Create the Q-function that builds the mass operator (i.e. computes its
# quadrature data) and set its context data.
build_qfunc = Ref{CeedQFunction}()
gallery = false

build_ctx = BuildContext(dim, dim)

if !gallery
   qf_build_mass = @cfunction(f_build_mass, CeedInt, (Ptr{Cvoid}, CeedInt, Ptr{Ptr{CeedScalar}}, Ptr{Ptr{CeedScalar}}))
   # This creates the QFunction directly.
    CeedQFunctionCreateInterior(ceed[], 1, qf_build_mass, "julia", build_qfunc)
    CeedQFunctionAddInput(build_qfunc[], "dx", ncompx*dim, CEED_EVAL_GRAD)
    CeedQFunctionAddInput(build_qfunc[], "weights", 1, CEED_EVAL_WEIGHT)
    CeedQFunctionAddOutput(build_qfunc[], "qdata", 1, CEED_EVAL_NONE)
    CeedQFunctionSetContext(build_qfunc[], pointer_from_objref(build_ctx), sizeof(build_ctx))
else
   # This creates the QFunction via the gallery.
   name = "Mass$(dim)DBuild"
   CeedQFunctionCreateInteriorByName(ceed[], name, build_qfunc)
end

# Create the operator that builds the quadrature data for the mass operator.
build_oper = Ref{CeedOperator}()
CeedOperatorCreate(ceed[], build_qfunc[], CEED_QFUNCTION_NONE[], CEED_QFUNCTION_NONE[], build_oper);
CeedOperatorSetField(build_oper[], "dx", mesh_restr[], mesh_basis[], CEED_VECTOR_ACTIVE[])
CeedOperatorSetField(build_oper[], "weights", CEED_ELEMRESTRICTION_NONE[], mesh_basis[], CEED_VECTOR_NONE[])
CeedOperatorSetField(build_oper[], "qdata", sol_restr_i[], CEED_BASIS_COLLOCATED[], CEED_VECTOR_ACTIVE[])

# Compute the quadrature data for the mass operator.
qdata = Ref{CeedVector}()
elem_qpts = num_qpts^dim
num_elem = prod(nxyz)
CeedVectorCreate(ceed[], num_elem*elem_qpts, qdata);

print("Computing the quadrature data for the mass operator ...")
flush(stdout)
CeedOperatorApply(build_oper[], mesh_coords[], qdata[], CEED_REQUEST_IMMEDIATE);
println(" done.")

# Create the Q-function that defines the action of the mass operator.
apply_qfunc = Ref{CeedQFunction}()
if !gallery
   qf_apply_mass = @cfunction(f_apply_mass, CeedInt, (Ptr{Cvoid}, CeedInt, Ptr{Ptr{CeedScalar}}, Ptr{Ptr{CeedScalar}}))
   # This creates the QFunction directly.
   CeedQFunctionCreateInterior(ceed[], 1, qf_apply_mass, "julia", apply_qfunc)
   CeedQFunctionAddInput(apply_qfunc[], "u", 1, CEED_EVAL_INTERP);
   CeedQFunctionAddInput(apply_qfunc[], "qdata", 1, CEED_EVAL_NONE);
   CeedQFunctionAddOutput(apply_qfunc[], "v", 1, CEED_EVAL_INTERP);
else
   # This creates the QFunction via the gallery.
   CeedQFunctionCreateInteriorByName(ceed[], "MassApply", apply_qfunc);
end

# Create the mass operator.
oper = Ref{CeedOperator}()
CeedOperatorCreate(ceed[], apply_qfunc[], CEED_QFUNCTION_NONE[], CEED_QFUNCTION_NONE[], oper)
CeedOperatorSetField(oper[], "u", sol_restr[], sol_basis[], CEED_VECTOR_ACTIVE[])
CeedOperatorSetField(oper[], "qdata", sol_restr_i[], CEED_BASIS_COLLOCATED[], qdata[])
CeedOperatorSetField(oper[], "v", sol_restr[], sol_basis[], CEED_VECTOR_ACTIVE[])

# Compute the mesh volume using the mass operator: vol = 1^T \cdot M \cdot 1
print("Computing the mesh volume using the formula: vol = 1^T.M.1 ...")
flush(stdout)
# Create auxiliary solution-size vectors.
u = Ref{CeedVector}()
v = Ref{CeedVector}()
CeedVectorCreate(ceed[], sol_size, u)
CeedVectorCreate(ceed[], sol_size, v)

# Initialize 'u' with ones.
CeedVectorSetValue(u[], 1.0)

# Apply the mass operator: 'u' -> 'v'.
CeedOperatorApply(oper[], u[], v[], CEED_REQUEST_IMMEDIATE)

# Compute and print the sum of the entries of 'v' giving the mesh volume.
v_host_ref = Ref{Ptr{CeedScalar}}()
CeedVectorGetArrayRead(v[], CEED_MEM_HOST, v_host_ref)
v_host = unsafe_wrap(Array, v_host_ref[], sol_size)
vol = sum(v_host)
CeedVectorRestoreArrayRead(v[], v_host_ref)

println(" done.")
@printf("Exact mesh volume    : % .14g\n", exact_vol)
@printf("Computed mesh volume : % .14g\n", vol)
@printf("Volume error         : % .14g\n", vol-exact_vol)

# Free dynamically allocated memory.
CeedVectorDestroy(u)
CeedVectorDestroy(v)
CeedVectorDestroy(qdata)
CeedVectorDestroy(mesh_coords)
CeedOperatorDestroy(oper)
CeedQFunctionDestroy(apply_qfunc)
CeedOperatorDestroy(build_oper)
CeedQFunctionDestroy(build_qfunc)
CeedElemRestrictionDestroy(sol_restr)
CeedElemRestrictionDestroy(mesh_restr)
CeedElemRestrictionDestroy(sol_restr_i)
CeedBasisDestroy(sol_basis)
CeedBasisDestroy(mesh_basis)
CeedDestroy(ceed)
