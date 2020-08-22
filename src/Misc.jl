using StaticArrays
import LinearAlgebra: det

struct CeedDim{dim} end
CeedDim(dim) = CeedDim{Int(dim)}()

det(J, ::CeedDim{1}) = @inbounds J[1]

det(J, ::CeedDim{2}) = @inbounds J[1]*J[4] - J[3]*J[2]

det(J, ::CeedDim{3}) = @inbounds (J[1]*(J[5]*J[9] - J[6]*J[8]) -
    J[2]*(J[4]*J[9] - J[6]*J[7]) +
    J[3]*(J[4]*J[8] - J[5]*J[7]))

@inline setvoigt(J::StaticArray{Tuple{D,D},T,2}) where {D,T} = setvoigt(J, CeedDim(D))
@inline setvoigt(J, ::CeedDim{1}) = @inbounds @SVector [J[1]]
@inline setvoigt(J, ::CeedDim{2}) = @inbounds @SVector [J[1], J[4], J[2]]
@inline setvoigt(J, ::CeedDim{3}) =
    @inbounds @SVector [J[1], J[5], J[9], J[6], J[3], J[2]]

@inline function setvoigt!(V, J, ::CeedDim{1})
    @inbounds V[1] = J[1]
end

@inline function setvoigt!(V, J, ::CeedDim{2})
    @inbounds begin
        V[1] = J[1] ; V[2] = J[4] ; V[3] = J[2]
    end
end

@inline function setvoigt!(V, J, ::CeedDim{3})
    @inbounds begin
        V[1] = J[1] ; V[2] = J[5] ; V[3] = J[9]
        V[4] = J[6] ; V[5] = J[3] ; V[6] = J[2]
    end
end

@inline getvoigt(V, ::CeedDim{1}) = @inbounds @SMatrix [V[1]]
@inline getvoigt(V, ::CeedDim{2}) = @inbounds @SMatrix [V[1] V[3] ; V[3] V[2]]
@inline getvoigt(V, ::CeedDim{3}) = @inbounds @SMatrix [
    V[1]  V[6]  V[5]
    V[6]  V[2]  V[4]
    V[5]  V[4]  V[3]
]

@inline function getvoigt!(J, V, ::CeedDim{1})
    @inbounds J[1,1] = V[1]
end

@inline function getvoigt!(J, V, ::CeedDim{2})
    @inbounds begin
        J[1,1] = V[1] ; J[1,2] = V[3]
        J[2,1] = V[3] ; J[2,2] = V[2]
    end
end

@inline function getvoigt!(J, V, ::CeedDim{3})
    @inbounds begin
        J[1,1] = V[1] ; J[1,2] = V[6] ; J[1,3] = V[5]
        J[2,1] = V[6] ; J[2,2] = V[2] ; J[2,3] = V[4]
        J[3,1] = V[5] ; J[3,2] = V[4] ; J[3,3] = V[3]
    end
end
