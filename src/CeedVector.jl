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
    CeedVector(c::Ceed, len::Integer)

Creates a `CeedVector` of given length.
"""
function CeedVector(c::Ceed, len::Integer)
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

Set the [`CeedVector`](@ref) to a constant value.
"""
setvalue!(v::CeedVector, val::CeedScalar) = C.CeedVectorSetValue(v[], val)
"""
    setindex!(v::CeedVector, val::CeedScalar)
    v[] = val

Set the [`CeedVector`](@ref) to a constant value, synonymous to
[`setvalue!`](@ref).
"""
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
    setarray!(v::CeedVector, mtype::MemType, cmode::CopyMode, arr)

Set the array used by a [`CeedVector`](@ref), freeing any previously allocated
array if applicable. The backend may copy values to a different
[`MemType`](@ref). See also [`sync_array!`](@ref) and [`take_array!`](@ref).

!!! warning "Avoid OWN_POINTER CopyMode"
    The [`CopyMode`](@ref) `OWN_POINTER` is not suitable for use with arrays
    that are allocated by Julia, since those cannot be properly freed from
    libCEED.
"""
function setarray!(v::CeedVector, mtype::MemType, cmode::CopyMode, arr)
    C.CeedVectorSetArray(v[], mtype, cmode, arr)
end

"""
    sync_array!(v::CeedVector, mtype::MemType)

Sync the [`CeedVector`](@ref) to a specified [`MemType`](@ref). This function is
used to force synchronization of arrays set with [`setarray!`](@ref). If the
requested memtype is already synchronized, this function results in a no-op.
"""
sync_array!(v::CeedVector, mtype::MemType) = C.CeedVectorSyncArray(v[], mtype)

"""
    take_array!(v::CeedVector, mtype::MemType)

Take ownership of the [`CeedVector`](@ref) array and remove the array from the
[`CeedVector`](@ref). The caller is responsible for managing and freeing the
array. The array is returns as a `Ptr{CeedScalar}`.
"""
function take_array!(v::CeedVector, mtype::MemType)
    ptr = Ref{Ptr{CeedScalar}}()
    C.CeedVectorTakeArray(v[], mtype, ptr)
    ptr[]
end

# Helper function to parse arguments of @witharray and @witharray_read
function witharray_parse(assignment, args)
    if !Meta.isexpr(assignment, :(=))
        error("@witharray must have first argument of the form v_arr=v")
    end
    arr = assignment.args[1]
    v = assignment.args[2]
    mtype = MEM_HOST
    sz = :((length($(esc(v))),))
    body = args[end]
    for i=1:length(args)-1
        a = args[i]
        if !Meta.isexpr(a, :(=))
            error("Incorrect call to @witharray or @witharray_read")
        end
        if a.args[1] == :mtype
            mtype = a.args[2]
        elseif a.args[1] == :size
            sz = esc(a.args[2])
        end
    end
    arr, v, sz, mtype, body
end

"""
    @witharray(v_arr=v, [size=(dims...)], [mtype=MEM_HOST], body)

Executes `body`, having extracted the contents of the [`CeedVector`](@ref) `v`
as an array with name `v_arr`. If the [`memory type`](@ref MemType) `mtype` is
not provided, `MEM_HOST` will be used. If the size is not specified, a flat
vector will be assumed.

# Examples
Negate the contents of `CeedVector` `v`:
```
@witharray v_arr=v v_arr *= -1.0
```
"""
macro witharray(assignment, args...)
    arr, v, sz, mtype, body = witharray_parse(assignment, args)
    quote
        arr_ref = Ref{Ptr{C.CeedScalar}}()
        C.CeedVectorGetArray($(esc(v))[], $(esc(mtype)), arr_ref)
        try
            $(esc(arr)) = UnsafeArray(arr_ref[], Int.($sz))
            $(esc(body))
        finally
            C.CeedVectorRestoreArray($(esc(v))[], arr_ref)
        end
    end
end

"""
    @witharray_read(v_arr=v, [size=(dims...)], [mtype=MEM_HOST], body)

Same as [`@witharray`](@ref), but provides read-only access to the data.
"""
macro witharray_read(assignment, args...)
    arr, v, sz, mtype, body = witharray_parse(assignment, args)
    quote
        arr_ref = Ref{Ptr{C.CeedScalar}}()
        C.CeedVectorGetArrayRead($(esc(v))[], $(esc(mtype)), arr_ref)
        try
            $(esc(arr)) = UnsafeArray(arr_ref[], Int.($sz))
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
    setindex!(v::CeedVector, v2::AbstractArray)
    v[] = v2

Sets the values of [`CeedVector`](@ref) `v` equal to those of `v2` using
broadcasting.
"""
Base.setindex!(v::CeedVector, v2::AbstractArray) = @witharray a=v a .= v2

"""
    CeedVector(c::Ceed, v2::AbstractVector)

Creates a new [`CeedVector`](@ref) by copying the contents of `v2`.
"""
function CeedVector(c::Ceed, v2::AbstractVector)
    v = CeedVector(c, length(v2))
    v[] = v2
    v
end

"""
    Vector(v::CeedVector)

Create a new `Vector` by copying the contents of `v`.
"""
function Base.Vector(v::CeedVector)
    v2 = Vector{CeedScalar}(undef, length(v))
    @witharray_read a=v v2 .= a
end

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
