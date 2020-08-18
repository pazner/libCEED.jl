mutable struct Context
    ref::Ref{C.CeedQFunctionContext}
    function Context(ref::Ref{C.CeedQFunctionContext})
        obj = new(ref)
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
    ctx = Context(ref)
    ctx[] = data
    return ctx
end

function Context(c::Ceed)
    ref = Ref{C.CeedQFunctionContext}()
    C.CeedQFunctionContextCreate(c[], ref)
    Context(ref)
end

function set_data!(ctx::Context, mtype, cmode, data)
    C.CeedQFunctionContextSetData(ctx[], mtype, cmode, sizeof(data), pointer_from_objref(data))
end

Base.setindex!(ctx::Context, data) = set_data!(ctx, MEM_HOST, USE_POINTER, data)
