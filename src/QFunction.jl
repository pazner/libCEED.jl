abstract type AbstractQFunction end

struct QFunctionNone <: AbstractQFunction end
Base.getindex(::QFunctionNone) = C.CEED_QFUNCTION_NONE[]

mutable struct QFunction <: AbstractQFunction
    ref::Ref{C.CeedQFunction}
    ceed::Union{Ceed,Nothing}

    function QFunction(ref, ceed)
        obj = new(ref, ceed)
        isnothing(ceed) || finalizer(obj) do x
            #  ccall(:jl_safe_printf, Cvoid, (Cstring, Cstring), "Finalizing %s.\n", repr(x))
            C.CeedQFunctionDestroy(x.ref)
       end
       return obj
    end
end
Base.getindex(qf::QFunction) = qf.ref[]

function create_interior_qfunction(c::Ceed, vlength, f)
    ## TODO: fix this (source location)
    ref = Ref{C.CeedQFunction}()
    C.CeedQFunctionCreateInterior(c[], vlength, f, "julia", ref)
    QFunction(ref, c)
end

function create_interior_qfunction(c::Ceed, name::AbstractString)
    ref = Ref{C.CeedQFunction}()
    C.CeedQFunctionCreateInteriorByName(c.ref[], name, ref)
    QFunction(ref, c)
end

function add_input!(qf::AbstractQFunction, name::AbstractString, size, emode)
    C.CeedQFunctionAddInput(qf[], name, size, emode)
end

function add_output!(qf::AbstractQFunction, name::AbstractString, size, emode)
    C.CeedQFunctionAddOutput(qf[], name, size, emode)
end

function set_context!(qf::AbstractQFunction, ctx)
    C.CeedQFunctionSetContext(qf[], pointer_from_objref(ctx), sizeof(ctx))
end
