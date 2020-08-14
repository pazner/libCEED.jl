const CeedScalar = C.CeedScalar
const CeedInt = C.CeedInt

const QuadMode = C.CeedQuadMode
const GAUSS = C.CEED_GAUSS
const GAUSS_LOBATTO = C.CEED_GAUSS_LOBATTO

const MemType = C.CeedMemType
const MEM_HOST = C.CEED_MEM_HOST
const MEM_DEVICE = C.CEED_MEM_DEVICE

const CopyMode = C.CeedCopyMode
const COPY_VALUES = C.CEED_COPY_VALUES
const USE_POINTER = C.CEED_USE_POINTER
const OWN_POINTER = C.CEED_OWN_POINTER

const EvalMode = C.CeedEvalMode
const EVAL_NONE = C.CEED_EVAL_NONE
const EVAL_INTERP = C.CEED_EVAL_INTERP
const EVAL_GRAD = C.CEED_EVAL_GRAD
const EVAL_DIV = C.CEED_EVAL_DIV
const EVAL_CURL = C.CEED_EVAL_CURL
const EVAL_WEIGHT = C.CEED_EVAL_WEIGHT

function set_globals()
    global STRIDES_BACKEND = C.CEED_STRIDES_BACKEND[]
end
