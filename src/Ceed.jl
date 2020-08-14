mutable struct Ceed
    ref::Ref{C.Ceed}
end

function Ceed(spec::AbstractString = "/cpu/self")
    obj = Ceed(Ref{C.Ceed}())
    C.CeedInit(spec, obj.ref)
    finalizer(obj) do x
        # ccall(:jl_safe_printf, Cvoid, (Cstring, Cstring), "Finalizing %s.\n", repr(x))
        C.CeedDestroy(x.ref)
    end
    return obj
end
Base.getindex(c::Ceed) = c.ref[]
