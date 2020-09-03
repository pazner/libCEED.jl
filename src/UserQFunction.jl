struct UserQFunction{F}
    f::F
    fptr::Ptr{Nothing}
end

@inline function extract_context(ptr, ::Type{T}) where T
    unsafe_load(Ptr{T}(ptr))
end

@inline function extract_array(ptr, idx, dims)
    UnsafeArray(Ptr{CeedScalar}(unsafe_load(ptr, idx)), dims)
end

function generate_user_qfunction(Q, constants, body)
    assignments = []
    for c ∈ constants
        push!(assignments, :($(c[1]) = $(c[2])))
    end
    quote
        @inline function $(gensym())(ctx_ptr::Ptr{Cvoid}, $Q::CeedInt, in_ptr::Ptr{Ptr{CeedScalar}}, out_ptr::Ptr{Ptr{CeedScalar}})
            $(assignments...)
            $body
        end
    end
end

function create_user_qfunction(Q, constants, body)
    fn = eval(generate_user_qfunction(Q, constants, body))
    fn_q = QuoteNode(fn)
    rt = :CeedInt
    at = :(Core.svec(Ptr{Cvoid}, CeedInt, Ptr{Ptr{CeedScalar}}, Ptr{Ptr{CeedScalar}}))
    cfn = eval(Expr(:cfunction, Ptr{Cvoid}, fn_q, rt, at, QuoteNode(:ccall)))
    UserQFunction(fn, cfn)
end

function user_qfunction(Q, args)
    Q_name = Meta.quot(Q)

    body = nothing
    constants = []
    assignments = []

    n_in = 0
    n_out = 0

    for a ∈ args
        if Meta.isexpr(a, :(=))
            a1 = Meta.quot(a.args[1])
            a2 = esc(a.args[2])
            push!(constants, :(($a1, $a2)))
        elseif Meta.isexpr(a, :tuple)
            arr_name = a.args[1]
            inout = a.args[2].value
            ndim = length(a.args) - 3
            dims = Vector{Expr}(undef, ndim)
            for d=1:ndim
                dims[d] = :(Int($(a.args[d+3])))
            end
            if inout == :in
                ptr = :in_ptr
                n_in += 1
                i_inout = n_in
            elseif inout == :out
                ptr = :out_ptr
                n_out += 1
                i_inout = n_out
            else
                error("Array specification must be either :in or :out. Given $inout.")
            end
            ptr = (inout == :in) ? :in_ptr : :out_ptr
            push!(assignments, :($arr_name = extract_array($ptr, $i_inout, ($(dims...),))))
        elseif Meta.isexpr(a, :block) || Meta.isexpr(a, :for)
            body = a
        elseif Meta.isexpr(a, :(::))
            ctx_name = a.args[1]
            ctx_type = a.args[2]
            push!(assignments, :($ctx_name = extract_context(ctx_ptr, $ctx_type)))
        else
            error("Bad argument to @user_qfunction")
        end
    end

    if isnothing(body)
        error("No valid user Q-function body")
    end

    body = Meta.quot(quote
        $(assignments...)
        $body
        CeedInt(0)
    end)

    return :(create_user_qfunction(
        $Q_name,
        [$(constants...)],
        $body
    ))
end

macro interior_qf(args)
    if Meta.isexpr(args, :(=))
        name = esc(args.args[1])
        args = args.args[2].args
        ceed = esc(args[1])
    else
        error("@interior_qf must be of form `qf = (body)`")
    end

    fields_in = []
    fields_out = []
    for a ∈ args
        if Meta.isexpr(a, :tuple)
            field_name = String(a.args[1])
            inout = a.args[2].value
            evalmode = a.args[3]

            # Skip first dim (num qpts)
            ndim = length(a.args) - 4
            dims = Vector{Expr}(undef, ndim)
            for d=1:ndim
                dims[d] = esc(:(Int($(a.args[d+4]))))
            end
            sz_expr = :(prod(($(dims...),)))
            if inout == :in
                push!(fields_in, :(add_input!($name, $field_name, $sz_expr, $evalmode)))
            elseif inout == :out
                push!(fields_out, :(add_output!($name, $field_name, $sz_expr, $evalmode)))
            end
        end
    end

    user_qf = user_qfunction(args[2], args[3:end])

    quote
        $name = create_interior_qfunction($ceed,
            $user_qf
        )
        $(fields_in...)
        $(fields_out...)
        set_cufunction!($ceed, $name)
    end
end
