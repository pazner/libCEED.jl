module libCEED

# import low-level C interface
include("C.jl")
import .C

# types and functions
export Ceed, CeedScalar, CeedInt
export Basis, BasisCollocated, create_tensor_h1_lagrange_basis
export ElemRestriction, ElemRestrictionNone, create_elem_restriction, create_elem_restriction_strided
export CeedVector, CeedVectorActive, CeedVectorNone, with_array, with_array_read
export gauss_quadrature, lobatto_quadrature, Abscissa, AbscissaAndWeights
export QFunction, QFunctionNone, create_interior_qfunction, add_input!, add_output!, set_context!
export Operator, set_field!, apply!
export Context, set_data!
export RequestImmediate, RequestOrdered
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
include("QFunction.jl")
include("Request.jl")
include("Operator.jl")
include("Context.jl")

function __init__()
    set_globals()
end

end # module