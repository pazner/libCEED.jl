abstract type AbstractQFunction end

struct QFunctionNone <: AbstractQFunction end
Base.getindex(::QFunctionNone) = C.CEED_QFUNCTION_NONE[]

mutable struct QFunction <: AbstractQFunction
    ref::Ref{C.CeedQFunction}
    user_qf::Union{Nothing,UserQFunction}
    function QFunction(ref, user_qf)
        obj = new(ref, user_qf)
        finalizer(obj) do x
            # ccall(:jl_safe_printf, Cvoid, (Cstring, Cstring), "Finalizing %s.\n", repr(x))
            C.CeedQFunctionDestroy(x.ref)
        end
        return obj
    end
end
Base.getindex(qf::QFunction) = qf.ref[]

function create_interior_qfunction(c::Ceed, f::UserQFunction; vlength=1)
    ref = Ref{C.CeedQFunction}()
    # Use empty string as source location to indicate to libCEED that there is
    # no C source for this Q-function
    C.CeedQFunctionCreateInterior(c[], vlength, f.fptr, "", ref)
    QFunction(ref, f)
end

function create_interior_qfunction(c::Ceed, name::AbstractString)
    ref = Ref{C.CeedQFunction}()
    C.CeedQFunctionCreateInteriorByName(c.ref[], name, ref)
    QFunction(ref, nothing)
end

function add_input!(qf::AbstractQFunction, name::AbstractString, size, emode)
    C.CeedQFunctionAddInput(qf[], name, size, emode)
end

function add_output!(qf::AbstractQFunction, name::AbstractString, size, emode)
    C.CeedQFunctionAddOutput(qf[], name, size, emode)
end

function set_context!(qf::AbstractQFunction, ctx)
    C.CeedQFunctionSetContext(qf[], ctx[])
end

function get_field_sizes(qf::AbstractQFunction)
    ninputs = Ref{CeedInt}()
    noutputs = Ref{CeedInt}()

    C.CeedQFunctionGetNumArgs(qf[], ninputs, noutputs)

    inputs = Ref{Ptr{C.CeedQFunctionField}}()
    outputs = Ref{Ptr{C.CeedQFunctionField}}()
    C.CeedQFunctionGetFields(qf[], inputs, outputs)

    input_sizes = zeros(CeedInt, ninputs[])
    output_sizes = zeros(CeedInt, noutputs[])

    for i=1:ninputs[]
        field = unsafe_load(inputs[], i)
        C.CeedQFunctionFieldGetSize(field, pointer(input_sizes, i))
    end

    for i=1:noutputs[]
        field = unsafe_load(outputs[], i)
        C.CeedQFunctionFieldGetSize(field, pointer(output_sizes, i))
    end

    input_sizes, output_sizes
end
