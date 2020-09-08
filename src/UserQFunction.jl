struct UserQFunction{F,K}
    f::F
    fptr::Ptr{Nothing}
    kf::K
    cuf::Union{Nothing,CUDA.HostKernel}
    dims_in::Vector{Vector{Int}}
    dims_out::Vector{Vector{Int}}
end

function UserQFunction(ceed::Ceed, f, kf, cuf, dims_in, dims_out)

    UserQFunction(f, kf, fptr, cuf, dims_in, dims_out)
end

@inline function extract_context(ptr, ::Type{T}) where T
    unsafe_load(Ptr{T}(ptr))
end

@inline function extract_array(ptr, idx, dims)
    UnsafeArray(Ptr{CeedScalar}(unsafe_load(ptr, idx)), dims)
end

function generate_user_qfunction(ceed, Q, constants, array_names, ctx, arrays, dims_in, dims_out, body)
    const_assignments = []
    for c ∈ constants
        push!(const_assignments, :($(c[1]) = $(c[2])))
    end

    f = eval(quote
        @inline function(ctx_ptr::Ptr{Cvoid}, $Q::CeedInt, in_ptr::Ptr{Ptr{CeedScalar}}, out_ptr::Ptr{Ptr{CeedScalar}})
            $(const_assignments...)
            $ctx
            $arrays
            $body
            CeedInt(0)
        end
    end)
    f_qn = QuoteNode(f)
    rt = :CeedInt
    at = :(Core.svec(Ptr{Cvoid}, CeedInt, Ptr{Ptr{CeedScalar}}, Ptr{Ptr{CeedScalar}}))
    fptr = eval(Expr(:cfunction, Ptr{Cvoid}, f_qn, rt, at, QuoteNode(:ccall)))

    kf = eval(quote
        @inline function(ctx_ptr::Ptr{Cvoid}, $Q::CeedInt, $(array_names...))
            $(const_assignments...)
            $ctx
            $body
            nothing
        end
    end)
    cuf = mk_cufunction(ceed, kf, dims_in, dims_out)

    UserQFunction(f, fptr, kf, cuf, dims_in, dims_out)
end

function meta_user_qfunction(ceed, Q, args)
    Q_name = Meta.quot(Q)

    body = nothing
    ctx = nothing
    constants = []
    arrays = []
    dims_in = []
    dims_out = []
    names_in = []
    names_out = []

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
                arr = dims_in
                i_inout = length(dims_in) + 1
                push!(names_in, arr_name)
            elseif inout == :out
                ptr = :out_ptr
                arr = dims_out
                i_inout = length(dims_out) + 1
                push!(names_out, arr_name)
            else
                error("Array specification must be either :in or :out. Given $inout.")
            end
            push!(arrays, :($arr_name = extract_array($ptr, $i_inout, ($(dims...),))))
            push!(arr, :(Int[$(esc.(a.args[5:end])...)]))
        elseif Meta.isexpr(a, :block) || Meta.isexpr(a, :for)
            body = Meta.quot(a)
        elseif Meta.isexpr(a, :(::))
            ctx_name = a.args[1]
            ctx_type = a.args[2]
            ctx = Meta.quot(:($ctx_name = extract_context(ctx_ptr, $ctx_type)))
        else
            error("Bad argument to @user_qfunction")
        end
    end

    if isnothing(body)
        error("No valid user Q-function body")
    end

    arrays = Meta.quot(quote
        $(arrays...)
    end)

    arr_names = [names_in ; names_out]

    return :(generate_user_qfunction(
        $ceed,
        $Q_name,
        [$(constants...)],
        $arr_names,
        $ctx,
        $arrays,
        [$(dims_in...)],
        [$(dims_out...)],
        $body
    ))
end

macro interior_qf(args)
    if Meta.isexpr(args, :(=))
        user_qf = esc(args.args[1])
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
                push!(fields_in, :(add_input!($user_qf, $field_name, $sz_expr, $evalmode)))
            elseif inout == :out
                push!(fields_out, :(add_output!($user_qf, $field_name, $sz_expr, $evalmode)))
            end
        end
    end

    gen_user_qf = meta_user_qfunction(ceed, args[2], args[3:end])

    quote
        $user_qf = create_interior_qfunction($ceed, $gen_user_qf)
        $(fields_in...)
        $(fields_out...)
    end
end
