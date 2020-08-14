abstract type AbstractBasis end

struct BasisCollocated <: AbstractBasis end
Base.getindex(::BasisCollocated) = C.CEED_BASIS_COLLOCATED[]

mutable struct Basis <: AbstractBasis
    ref::Ref{C.CeedBasis}
    ceed::Ceed
    function Basis(ref, ceed)
        obj = new(ref, ceed)
        finalizer(obj) do x
            # ccall(:jl_safe_printf, Cvoid, (Cstring, Cstring), "Finalizing %s.\n", repr(x))
            C.CeedBasisDestroy(x.ref)
        end
        return obj
    end
end
Base.getindex(b::Basis) = b.ref[]

function create_tensor_h1_lagrange_basis(c::Ceed, dim, ncomp, p, q, quad_mode::QuadMode)
    ref = Ref{C.CeedBasis}()
    C.CeedBasisCreateTensorH1Lagrange(c[], dim, ncomp, p, q, quad_mode, ref)
    Basis(ref, c)
end
