# Automatically generated using Clang.jl

const FILE = Cvoid

# Skipping MacroDefinition: CEED_QFUNCTION ( name ) static const char name ## _loc [ ] = __FILE__ ":" # name ; static int name

# Skipping MacroDefinition: CeedError ( ceed , ecode , ... ) ( CeedErrorImpl ( ( ceed ) , __FILE__ , __LINE__ , __func__ , ( ecode ) , __VA_ARGS__ ) ? : ( ecode ) )

const CeedInt = Int32
const CeedScalar = Cdouble
const Ceed_private = Cvoid
const Ceed = Ptr{Ceed_private}
const CeedRequest_private = Cvoid
const CeedRequest = Ptr{CeedRequest_private}
const CeedVector_private = Cvoid
const CeedVector = Ptr{CeedVector_private}
const CeedElemRestriction_private = Cvoid
const CeedElemRestriction = Ptr{CeedElemRestriction_private}
const CeedBasis_private = Cvoid
const CeedBasis = Ptr{CeedBasis_private}
const CeedQFunction_private = Cvoid
const CeedQFunction = Ptr{CeedQFunction_private}
const CeedQFunctionContext_private = Cvoid
const CeedQFunctionContext = Ptr{CeedQFunctionContext_private}
const CeedOperator_private = Cvoid
const CeedOperator = Ptr{CeedOperator_private}

@cenum CeedMemType::UInt32 begin
    CEED_MEM_HOST = 0
    CEED_MEM_DEVICE = 1
end

@cenum CeedCopyMode::UInt32 begin
    CEED_COPY_VALUES = 0
    CEED_USE_POINTER = 1
    CEED_OWN_POINTER = 2
end

@cenum CeedNormType::UInt32 begin
    CEED_NORM_1 = 0
    CEED_NORM_2 = 1
    CEED_NORM_MAX = 2
end

@cenum CeedTransposeMode::UInt32 begin
    CEED_NOTRANSPOSE = 0
    CEED_TRANSPOSE = 1
end

@cenum CeedEvalMode::UInt32 begin
    CEED_EVAL_NONE = 0
    CEED_EVAL_INTERP = 1
    CEED_EVAL_GRAD = 2
    CEED_EVAL_DIV = 4
    CEED_EVAL_CURL = 8
    CEED_EVAL_WEIGHT = 16
end

@cenum CeedQuadMode::UInt32 begin
    CEED_GAUSS = 0
    CEED_GAUSS_LOBATTO = 1
end

@cenum CeedElemTopology::UInt32 begin
    CEED_LINE = 65536
    CEED_TRIANGLE = 131073
    CEED_QUAD = 131074
    CEED_TET = 196611
    CEED_PYRAMID = 196612
    CEED_PRISM = 196613
    CEED_HEX = 196614
end


const CeedQFunctionUser = Ptr{Cvoid}
