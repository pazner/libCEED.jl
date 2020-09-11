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
        C.CeedDestroy(x.ref)
    end
    return obj
end
Base.getindex(c::Ceed) = c.ref[]

"""
    iscuda(c::Ceed)

Returns true if `c` has resource "/gpu/cuda/*" and false otherwise.
"""
function iscuda(c::Ceed)
    res = Ref{Cstring}()
    C.CeedGetResource(c[], res)
    res_split = split(unsafe_string(res[]), "/")
    length(res_split) >= 3 && res_split[3] == "cuda"
end
