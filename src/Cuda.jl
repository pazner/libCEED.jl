struct FieldsCuda
    inputs::NTuple{16, Int}
    outputs::NTuple{16, Int}
end

function generate_kernel(qf)
    input_sz, output_sz = get_field_sizes(qf)

    ninputs = length(input_sz)
    noutputs = length(output_sz)

    ins = [Symbol("ins_$i") for i=1:ninputs]
    outs = [Symbol("outs_$i") for i=1:ninputs]

    f_ins = [Symbol("rqi$i") for i=1:ninputs]
    f_outs = [Symbol("rqo$i") for i=1:noutputs]

    def_ins = [:($(f_ins[i]) = MVector{$(Int(input_sz[i])),Float64}(undef)) for i=1:ninputs]
    def_outs = [:($(f_outs[i]) = MVector{$(Int(output_sz[i])),Float64}(undef)) for i=1:noutputs]

    assign_ins = [:(ins[$i] = pointer($(f_ins[i]))) for i=1:ninputs]
    assign_outs = [:(outs[$i] = pointer($(f_outs[i]))) for i=1:noutputs]

    read_quads_in = [
        :(for j=1:$(input_sz[i])
            $(f_ins[i])[j] = unsafe_load(Ptr{CeedScalar}(fields.inputs[$i]), q + (j-1)*Q)
          end)
        for i=1:ninputs
    ]

    write_quads_out = [
        :(for j=1:$(output_sz[i])
            unsafe_store!(Ptr{CeedScalar}(fields.outputs[$i]), $(f_outs[i])[j], q+(j-1)*Q)
          end)
        for i=1:noutputs
    ]

    quote
        function (ctx_ptr, Q, fields)
            gd = gridDim()
            bi = blockIdx()
            bd = blockDim()
            ti = threadIdx()

            inc = bd.x*gd.x

            ins = MVector{$ninputs,Ptr{CeedScalar}}(undef)
            outs = MVector{$noutputs,Ptr{CeedScalar}}(undef)

            $(def_ins...)
            $(def_outs...)

            $(assign_ins...)
            $(assign_outs...)

            for q=(ti.x + (bi.x-1)*bd.x):inc:Q
                $(read_quads_in...)
                $(qf.user_qf.f)(ctx_ptr, CeedInt(1), pointer(ins), pointer(outs))
                $(write_quads_out...)
            end
            return
        end
    end
end

function set_cufunction!(ceed, qf)
    if !iscuda(ceed)
        return
    end

    if !has_cuda()
        error("No valid CUDA installation found")
    end

    k_fn = eval(generate_kernel(qf))
    tt = Tuple{Ptr{Nothing}, Int32, FieldsCuda}
    k = cufunction(k_fn, tt, maxregs=64)
    C.CeedQFunctionSetCUDAUserFunction(qf[], k.fun.handle)
end
