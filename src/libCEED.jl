module libCEED

using StaticArrays
using UnsafeArrays: UnsafeArray

# import low-level C interface
include("C.jl")
import .C

# types and functions
export Ceed, CeedScalar, CeedInt
export Basis, BasisCollocated, create_tensor_h1_lagrange_basis
export ElemRestriction, ElemRestrictionNone, create_elem_restriction, create_elem_restriction_strided
export CeedVector, CeedVectorActive, CeedVectorNone, witharray, witharray_read, @witharray, @witharray_read
export gauss_quadrature, lobatto_quadrature, Abscissa, AbscissaAndWeights
export UserQFunction, QFunction, QFunctionNone, create_interior_qfunction, add_input!, add_output!, set_context!, extract_context, extract_array, @user_qfunction, @withdim
export Operator, set_field!, apply!
export Context, set_data!
export RequestImmediate, RequestOrdered
export CeedDim, det, setvoigt, setvoigt!, getvoigt, getvoigt!
# enums and globals
export QuadMode, GAUSS, GAUSS_LOBATTO
export MemType, MEM_HOST, MEM_DEVICE
export CopyMode, COPY_VALUES, USE_POINTER, OWN_POINTER
export EvalMode, EVAL_NONE, EVAL_INTERP, EVAL_GRAD, EVAL_DIV, EVAL_CURL, EVAL_WEIGHT
export STRIDES_BACKEND

include("Globals.jl")
include("Ceed.jl")
include("Basis.jl")
include("ElemRestriction.jl")
include("CeedVector.jl")
include("Quadrature.jl")
include("Context.jl")
include("QFunction.jl")
include("UserQFunction.jl")
include("Request.jl")
include("Operator.jl")
include("Misc.jl")

function __init__()
    set_globals()
end

end # module
