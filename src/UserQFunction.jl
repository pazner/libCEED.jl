struct UserQFunction{F}
    f::F
    fptr::Ptr{Nothing}
end

function extract_context(ptr, ::Type{T}) where T
    unsafe_load(Ptr{T}(ptr))
end

function extract_array(ptr, idx, dims)
    UnsafeArray(Ptr{CeedScalar}(unsafe_load(ptr, idx)), dims)
end

macro user_qfunction(f)
    if !Meta.isexpr(f, :function)
        throw(ArgumentError("@user_qfunction must be called with a function"))
    end
    # extract signature and body from fuction definition
    fcall = f.args[1]
    if length(fcall.args) < 3
        throw(ArgumentError("@user_qfunction: function must take at least 2 arguments"))
    end
    # extract function body
    fbody = esc(f.args[2])

    # get name of function
    fname = fcall.args[1]
    # parse parameter list
    ctx_expr = fcall.args[2]
    if !Meta.isexpr(ctx_expr, :(::))
        throw(ArgumentError("@user_qfunction: first argument (context) must be typed"))
    end

    # if the context argument is anonymous (e.g. ::Nothing), then don't assign
    # it to any variable
    skip_ctx = false
    if length(ctx_expr.args) == 2
        ctx_name = ctx_expr.args[1]
        ctx_type = esc(ctx_expr.args[2])
    else
        skip_ctx = true
    end

    Q = fcall.args[3]
    if Q isa Symbol
        Q_name = esc(Q)
    elseif Meta.isexpr(Q, :(::)) && length(Q.args) > 1
        Q_name = esc(Q.args[1])
    else
        # if the Q argument was anonymous, name it ourselves
        Q_name = :Q
    end

    # parse input/output parameters
    inout_assignments = []
    n_in = 0
    n_out = 0
    inout_errmsg = "@user_qfunction: input/output arguments must be named and typed with ::([:in,:out], dims...)"
    for i=4:length(fcall.args)
        arg = fcall.args[i]
        if !Meta.isexpr(arg, :(::)) || length(arg.args) != 2
            throw(ArgumentError(inout_errmsg))
        end
        argname = arg.args[1]
        argspec = arg.args[2]
        # argspec is of the form ([:in,:out], dims...), first we look at the
        # symbol do determine if it's an input or output argument
        inout = argspec.args[1]
        if !(inout isa QuoteNode)
            throw(ArgumentError(inout_errmsg))
        end
        if inout.value == :in
            ptr = :in_ptr
            n_in += 1
            i_inout = n_in
        elseif inout.value == :out
            ptr = :out_ptr
            n_out += 1
            i_inout = n_out
        else
            throw(ArgumentError(inout_errmsg))
        end
        ndim = length(argspec.args) - 1
        dims = Vector{Expr}(undef, ndim)
        for d=1:ndim
            dims[d] = esc(:(Int($(argspec.args[d+1]))))
        end
        expr = :($(esc(argname)) = extract_array($ptr, $i_inout, ($(dims...),)))
        push!(inout_assignments, expr)
    end

    assignments = []
    if !skip_ctx
        push!(assignments, :($(esc(ctx_name)) = extract_context(ctx_ptr, $ctx_type)))
    end
    append!(assignments, inout_assignments)

    fname_gen = gensym(fname)

    ctx_ptr_type = esc(Ptr{Cvoid})
    Q_type = esc(CeedInt)
    arr_type = esc(Ptr{Ptr{CeedScalar}})

    fn_def = :(
        @inline function $(esc(fname_gen))(ctx_ptr::$ctx_ptr_type, $Q_name::$Q_type, in_ptr::$arr_type, out_ptr::$arr_type)
            $(assignments...)
            $fbody
        end
    )
    cfn_assignment = :(
        $(esc(fname)) = UserQFunction($(esc(fname_gen)), @cfunction($fname_gen, CeedInt, (Ptr{Cvoid}, C.CeedInt, Ptr{Ptr{C.CeedScalar}}, Ptr{Ptr{C.CeedScalar}})))
    )

    # have to execute the definitions at the top-level because of issues with
    # ccall
    return Expr(:toplevel, fn_def, cfn_assignment)
end

macro withdim(assignment, expr)
    if !Meta.isexpr(assignment, :(=))
        throw(ArgumentError("@withdim: must be of the form @withdim D=dim f(args...)"))
    end
    D = esc(assignment.args[1])
    dim = esc(assignment.args[2])
    body = esc(expr)
    quote
        if $dim == 1
            $D = CeedDim(1)
            $body
        elseif $dim == 2
            $D = CeedDim(2)
            $body
        elseif $dim == 3
            $D = CeedDim(3)
            $body
        else
            error("Dimension must be 1, 2, or 3")
        end
    end
end
