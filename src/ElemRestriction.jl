abstract type AbstractElemRestriction end

struct ElemRestrictionNone <: AbstractElemRestriction end
Base.getindex(::ElemRestrictionNone) = C.CEED_ELEMRESTRICTION_NONE[]

mutable struct ElemRestriction <: AbstractElemRestriction
    ref::Ref{C.CeedElemRestriction}
    ceed::Ceed
    function ElemRestriction(ref, ceed)
        obj = new(ref, ceed)
        finalizer(obj) do x
            # ccall(:jl_safe_printf, Cvoid, (Cstring, Cstring), "Finalizing %s.\n", repr(x))
            C.CeedElemRestrictionDestroy(x.ref)
        end
        return obj
    end
end
Base.getindex(r::ElemRestriction) = r.ref[]

function create_elem_restriction(c::Ceed, nelem, elemsize, ncomp, compstride, lsize, mtype::MemType, cmode::CopyMode, offsets::AbstractArray{CeedInt})
    ref = Ref{C.CeedElemRestriction}()
    C.CeedElemRestrictionCreate(c[], nelem, elemsize, ncomp, compstride, lsize, mtype, cmode, offsets, ref)
    ElemRestriction(ref, c)
end

function create_elem_restriction_strided(c::Ceed, nelem, elemsize, ncomp, lsize, strides)
    ref = Ref{C.CeedElemRestriction}()
    C.CeedElemRestrictionCreateStrided(c[], nelem, elemsize, ncomp, lsize, strides, ref)
    ElemRestriction(ref, c)
end
