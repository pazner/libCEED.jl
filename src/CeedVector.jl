abstract type AbstractCeedVector end

struct CeedVectorActive <: AbstractCeedVector end
Base.getindex(::CeedVectorActive) = C.CEED_VECTOR_ACTIVE[]

struct CeedVectorNone <: AbstractCeedVector end
Base.getindex(::CeedVectorNone) = C.CEED_VECTOR_NONE[]

mutable struct CeedVector <: AbstractCeedVector
    ref::Ref{C.CeedVector}
end

function CeedVector(c::Ceed, len)
    ref = Ref{C.CeedVector}()
    C.CeedVectorCreate(c[], len, ref)
    obj = CeedVector(ref)
    finalizer(obj) do x
        # ccall(:jl_safe_printf, Cvoid, (Cstring, Cstring), "Finalizing %s.\n", repr(x))
        C.CeedVectorDestroy(x.ref)
    end
    return obj
end
Base.getindex(v::CeedVector) = v.ref[]
Base.setindex!(v::CeedVector, val::CeedScalar) = C.CeedVectorSetValue(v[], val)

macro witharray(v, mtype, arr, body)
    quote
        arr_ref = Ref{Ptr{C.CeedScalar}}()
        C.CeedVectorGetArray($(esc(v))[], $(esc(mtype)), arr_ref)
        $(esc(arr)) = UnsafeArray(arr_ref[], (length($(esc(v))),))
        try
            $(esc(body))
        finally
            C.CeedVectorRestoreArray($(esc(v))[], arr_ref)
        end
    end
end

macro witharray_read(v, mtype, arr, body)
    quote
        arr_ref = Ref{Ptr{C.CeedScalar}}()
        C.CeedVectorGetArrayRead($(esc(v))[], $(esc(mtype)), arr_ref)
        $(esc(arr)) = UnsafeArray(arr_ref[], (length($(esc(v))),))
        try
            $(esc(body))
        finally
            C.CeedVectorRestoreArrayRead($(esc(v))[], arr_ref)
        end
    end
end

Base.ndims(::CeedVector) = 1
Base.ndims(::Type{CeedVector}) = 1
Base.axes(v::CeedVector) = (Base.OneTo(length(v)),)

function Base.copyto!(dest::CeedVector, bc::Base.Broadcast.Broadcasted)
    @witharray dest MEM_HOST arr arr .= bc
    dest
end

function Base.length(::Type{T}, v::CeedVector) where T
    len = Ref{C.CeedInt}()
    C.CeedVectorGetLength(v[], len)
    return T(len[])
end

Base.length(v::CeedVector) = length(Int, v)

function witharray(f, v::CeedVector, mtype::MemType)
    arr_ref = Ref{Ptr{C.CeedScalar}}()
    C.CeedVectorGetArray(v[], mtype, arr_ref)
    arr = UnsafeArray(arr_ref[], (length(v),))
    local res
    try
        res = f(arr)
    finally
        C.CeedVectorRestoreArray(v[], arr_ref)
    end
    return res
end

function witharray_read(f, v::CeedVector, mtype::MemType)
    arr_ref = Ref{Ptr{C.CeedScalar}}()
    C.CeedVectorGetArrayRead(v[], mtype, arr_ref)
    arr = UnsafeArray(arr_ref[], (length(v),))
    local res
    try
        res = f(arr)
    finally
        C.CeedVectorRestoreArrayRead(v[], arr_ref)
    end
    return res
end
