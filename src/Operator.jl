mutable struct Operator
    ref::Ref{C.CeedOperator}
    function Operator(ref)
        obj = new(ref)
        finalizer(obj) do x
            # ccall(:jl_safe_printf, Cvoid, (Cstring, Cstring), "Finalizing %s.\n", repr(x))
            C.CeedOperatorDestroy(x.ref)
        end
        return obj
    end
end
Base.getindex(op::Operator) = op.ref[]

function Operator(c::Ceed, qf::AbstractQFunction, dqf::AbstractQFunction, dqfT::AbstractQFunction)
    ref = Ref{C.CeedOperator}()
    C.CeedOperatorCreate(c[], qf[], dqf[], dqfT[], ref)
    Operator(ref)
end


function set_field!(op::Operator, fieldname::AbstractString, r::AbstractElemRestriction, b::AbstractBasis, v::AbstractCeedVector)
    C.CeedOperatorSetField(op[], fieldname, r[], b[], v[])
end

function Operator(c::Ceed; qf, dqf=QFunctionNone(), dqfT=QFunctionNone(), fields)
    op = Operator(c, qf, dqf, dqfT)
    for f ∈ fields
        set_field!(op, String(f[1]), f[2], f[3], f[4])
    end
    op
end

function apply!(op::Operator, vin::AbstractCeedVector, vout::AbstractCeedVector, request::AbstractRequest)
    try
        C.CeedOperatorApply(op[], vin[], vout[], request[])
    catch e
        # Cannot recover from exceptions in operator apply
        printstyled(stderr, "libCEED.jl: ", color=:red, bold=true)
        println("error occurred when applying operator")
        Base.display_error(stderr, Base.catch_stack())
        # Exit without running atexit hooks or finalizers
        ccall(:exit, Cvoid, (Cint,), 1)
    end
end
