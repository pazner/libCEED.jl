abstract type AbstractCeedVector end

struct CeedVectorActive <: AbstractCeedVector end
Base.getindex(::CeedVectorActive) = C.CEED_VECTOR_ACTIVE[]

struct CeedVectorNone <: AbstractCeedVector end
Base.getindex(::CeedVectorNone) = C.CEED_VECTOR_NONE[]

mutable struct CeedVector <: AbstractCeedVector
    ref::Ref{C.CeedVector}
end

"""
    CeedVector(c::Ceed, len)

Creates a `CeedVector` of given length.
"""
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

"""
    @witharray(v_arr=v, [mtype], body)

Executes `body`, having extracted the contents of the `CeedVector` `v` as an
array with name `v_arr`. If the memory type `mtype` is not provided, `MEM_HOST`
will be used.

# Examples
Negate the contents of `CeedVector` `v`:
```
@witharray v_arr=v MEM_HOST v_arr *= -1.0
```
"""
macro witharray(assignment, args...)
    if !Meta.isexpr(assignment, :(=))
        error("@witharray must have first argument of the form v_arr=v")
    end
    arr = assignment.args[1]
    v = assignment.args[2]

    if length(args) == 1
        mtype = MEM_HOST
        body = args[1]
    elseif length(args) == 2
        mtype = args[1]
        body = args[2]
    else
        error("Incorrect call to @witharray")
    end

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

"""
    @witharray_read(v_arr=v, [mtype], body)

Same as `@with_array`, but provides read-only access to the data.
"""
macro witharray_read(assignment, args...)
    if !Meta.isexpr(assignment, :(=))
        error("@witharray_read must have first argument of the form v_arr=v")
    end
    arr = assignment.args[1]
    v = assignment.args[2]

    if length(args) == 1
        mtype = MEM_HOST
        body = args[1]
    elseif length(args) == 2
        mtype = args[1]
        body = args[2]
    else
        error("Incorrect call to @witharray_read")
    end

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
    @witharray arr=dest MEM_HOST arr .= bc
    dest
end

function Base.length(::Type{T}, v::CeedVector) where T
    len = Ref{C.CeedInt}()
    C.CeedVectorGetLength(v[], len)
    return T(len[])
end

Base.length(v::CeedVector) = length(Int, v)

"""
    witharray(f, v::CeedVector, mtype)

Calls `f` with an array containing the data of the `CeedVector` `v`, using
memory type `mtype`.

Because of performance issues involving closures, if `f` is a complex operation,
it may be more efficient to use the macro version `@witharray` (cf. the section
on "Performance of captured variable" in
https://docs.julialang.org/en/v1/manual/performance-tips
and Julia issue https://github.com/JuliaLang/julia/issues/15276)

# Examples

Return the sum of a vector:
```
witharray(sum, v, MEM_HOST)
```
"""
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

"""
    witharray_read(f, v::CeedVector, mtype)

Same as `witharray`, but with read-only access to the data.
"""
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
