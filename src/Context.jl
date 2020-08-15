mutable struct Context <: AbstractElemRestriction
    ref::Ref{C.CeedQFunctionContext}
    ceed::Ceed
    data::Any
    function Context(ref, ceed)
        obj = new(ref, ceed, nothing)
        finalizer(obj) do x
            C.CeedQFunctionContextDestroy(x.ref)
        end
        return obj
    end
end
Base.getindex(ctx::Context) = ctx.ref[]

function Context(c::Ceed, data)
    ref = Ref{C.CeedQFunctionContext}()
    C.CeedQFunctionContextCreate(c[], ref)
    ctx = Context(ref, c)
    ctx[] = data
    return ctx
end

function Context(c::Ceed)
    ref = Ref{C.CeedQFunctionContext}()
    C.CeedQFunctionContextCreate(c[], ref)
    Context(ref, c)
end

function set_data!(ctx::Context, mtype, cmode, data)
    C.CeedQFunctionContextSetData(ctx[], mtype, cmode, sizeof(data), pointer_from_objref(data))
end

function Base.setindex!(ctx::Context, data)
    set_data!(ctx, MEM_HOST, USE_POINTER, data)
    ctx.data = data
end
