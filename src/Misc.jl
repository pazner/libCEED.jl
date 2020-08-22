import LinearAlgebra: det

struct CeedDim{dim} end
CeedDim(dim) = CeedDim{Int(dim)}()

det(J, ::CeedDim{1}) = @inbounds J[1]

det(J, ::CeedDim{2}) = @inbounds J[1]*J[4] - J[3]*J[2]

det(J, ::CeedDim{3}) = @inbounds (J[1]*(J[5]*J[9] - J[6]*J[8]) -
    J[2]*(J[4]*J[9] - J[6]*J[7]) +
    J[3]*(J[4]*J[8] - J[5]*J[7]))
