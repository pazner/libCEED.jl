import LinearAlgebra: norm

abstract type AbstractCeedVector end

struct CeedVectorActive <: AbstractCeedVector end
Base.getindex(::CeedVectorActive) = C.CEED_VECTOR_ACTIVE[]

struct CeedVectorNone <: AbstractCeedVector end
Base.getindex(::CeedVectorNone) = C.CEED_VECTOR_NONE[]

mutable struct CeedVector <: AbstractCeedVector
    ref::Ref{C.CeedVector}
    CeedVector(ref::Ref{C.CeedVector}) = new(ref)
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
        destroy(x)
    end
    return obj
end
destroy(v::CeedVector) = C.CeedVectorDestroy(v.ref)
Base.getindex(v::CeedVector) = v.ref[]

Base.summary(io::IO, v::CeedVector) = print(io, length(v), "-element CeedVector")
function Base.show(io::IO, ::MIME"text/plain", v::CeedVector)
    summary(io, v)
    println(io, ":")
    witharray_read(v, MEM_HOST) do arr
        Base.print_array(io, arr)
    end
end

Base.ndims(::CeedVector) = 1
Base.ndims(::Type{CeedVector}) = 1
Base.axes(v::CeedVector) = (Base.OneTo(length(v)),)

function Base.length(::Type{T}, v::CeedVector) where T
    len = Ref{C.CeedInt}()
    C.CeedVectorGetLength(v[], len)
    return T(len[])
end

"""
    setvalue!(v::CeedVector, val::CeedScalar)
    v[] = val

Set the [`CeedVector`](@ref) to a constant value.
"""
setvalue!(v::CeedVector, val::CeedScalar) = C.CeedVectorSetValue(v[], val)
Base.setindex!(v::CeedVector, val::CeedScalar) = setvalue!(v, val)

"""
    norm(v::CeedVector, ntype::NormType)

Return the norm of the given [`CeedVector`](@ref).

The norm type can either be specified as one of `NORM_1`, `NORM_2`, `NORM_MAX`.
"""
function norm(v::CeedVector, ntype::NormType)
    nrm = Ref{CeedScalar}()
    C.CeedVectorNorm(v[], ntype, nrm)
    nrm[]
end

"""
    norm(v::CeedVector, p::Real)

Return the norm of the given [`CeedVector`](@ref), see [`norm(::CeedVector,
::NormType)`](@ref).

`p` can have value 1, 2, or Inf, corresponding to `NORM_1`, `NORM_2`, and
`NORM_MAX`, respectively.
"""
function norm(v::CeedVector, p::Real)
    if p == 1
        ntype = NORM_1
    elseif p == 2
        ntype = NORM_2
    elseif isinf(p)
        ntype = NORM_MAX
    else
        error("norm(v::CeedVector, p): p must be 1, 2, or Inf")
    end
    norm(v, ntype)
end

"""
    reciprocal!(v::CeedVector)

Set `v` to be equal to its elementwise reciprocal.
"""
reciprocal!(v::CeedVector) = C.CeedVectorReciprocal(v[])

"""
    @witharray(v_arr=v, [mtype], body)

Executes `body`, having extracted the contents of the [`CeedVector`](@ref) `v`
as an array with name `v_arr`. If the [`memory type`](@ref MemType) `mtype` is
not provided, `MEM_HOST` will be used.

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

Same as [`@witharray`](@ref), but provides read-only access to the data.
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

"""
    length(v::CeedVector)

Return the number of elements in the given [`CeedVector`](@ref).
"""
Base.length(v::CeedVector) = length(Int, v)

"""
    witharray(f, v::CeedVector, mtype=MEM_HOST)

Calls `f` with an array containing the data of the `CeedVector` `v`, using
[`memory type`](@ref MemType) `mtype`.

Because of performance issues involving closures, if `f` is a complex operation,
it may be more efficient to use the macro version `@witharray` (cf. the section
on "Performance of captured variable" in the
[Julia documentation](https://docs.julialang.org/en/v1/manual/performance-tips)
and related [GitHub issue](https://github.com/JuliaLang/julia/issues/15276).

# Examples

Return the sum of a vector:
```
witharray(sum, v)
```
"""
function witharray(f, v::CeedVector, mtype::MemType=MEM_HOST)
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
    witharray_read(f, v::CeedVector, mtype::MemType=MEM_HOST)

Same as [`witharray`](@ref), but with read-only access to the data.

# Examples

Display the contents of a vector:
```
witharray_read(display, v)
```
"""
function witharray_read(f, v::CeedVector, mtype::MemType=MEM_HOST)
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
