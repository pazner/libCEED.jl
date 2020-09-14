mutable struct Ceed
    ref::Ref{C.Ceed}
end

"""
    Ceed(spec="/cpu/self")

Wraps a libCEED `Ceed` object, created with the given resource specification
string.
"""
function Ceed(spec::AbstractString="/cpu/self")
    obj = Ceed(Ref{C.Ceed}())
    C.CeedInit(spec, obj.ref)
    finalizer(obj) do x
        # ccall(:jl_safe_printf, Cvoid, (Cstring, Cstring), "Finalizing %s.\n", repr(x))
        destroy(x.ref)
    end
    return obj
end
destroy(c::Ceed) = C.CeedDestroy(c.ref)
Base.getindex(c::Ceed) = c.ref[]

function Base.show(io::IO, c::Ceed)
    mktemp() do fname,f
        cf = Libc.FILE(f)
        er = C.CeedView(c[], cf.ptr)
        ccall(:fflush, Cint, (Ptr{Cvoid},), cf)
        seek(f, 0)
        str = read(f, String)
        write(io, str)
    end
    return nothing
end

"""
    getresource(c::Ceed)

Returns the resource string associated with the given [`Ceed`](@ref) object.
"""
function getresource(c::Ceed)
    res = Ref{Cstring}()
    C.CeedGetResource(c[], res)
    unsafe_string(res[])
end

"""
    isdeterministic(c::Ceed)

Returns true if backend of the given [`Ceed`](@ref) object is deterministic,
and false otherwise.
"""
function isdeterministic(c::Ceed)
    isdet = Ref{Bool}()
    C.CeedIsDeterministic(c[], isdet)
    isdet[]
end

function get_preferred_memtype(c::Ceed)
    mtype = Ref{MemType}()
    C.CeedGetPreferredMemType(c[], mtype)
    mtype[]
end

"""
    iscuda(c::Ceed)

Returns true if the given [`Ceed`](@ref) object has resource `"/gpu/cuda/*"` and
false otherwise.
"""
function iscuda(c::Ceed)
    res_split = split(getresource(c), "/")
    length(res_split) >= 3 && res_split[3] == "cuda"
end
