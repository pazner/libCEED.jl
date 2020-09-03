struct FieldsCuda
    inputs::NTuple{16, Int}
    outputs::NTuple{16, Int}
end

function generate_kernel(kf, dims_in, dims_out)
    ninputs = length(dims_in)
    noutputs = length(dims_out)

    input_sz = prod.(dims_in)
    output_sz = prod.(dims_out)

    ins = [Symbol("ins_$i") for i=1:ninputs]
    outs = [Symbol("outs_$i") for i=1:ninputs]

    f_ins = [Symbol("rqi$i") for i=1:ninputs]
    f_outs = [Symbol("rqo$i") for i=1:noutputs]

    args = [f_ins ; f_outs]

    def_ins = [:($(f_ins[i]) = MArray{Tuple{1,$(dims_in[i]...)},Float64}(undef)) for i=1:ninputs]
    def_outs = [:($(f_outs[i]) = MArray{Tuple{1,$(dims_out[i]...)},Float64}(undef)) for i=1:noutputs]

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
                $kf(ctx_ptr, CeedInt(1), $(args...))
                $(write_quads_out...)
            end
            return
        end
    end
end

function mk_cufunction(ceed, kf, dims_in, dims_out)
    if !iscuda(ceed)
        return nothing
    end

    if !has_cuda()
        error("No valid CUDA installation found")
    end

    k_fn = eval(generate_kernel(kf, dims_in, dims_out))
    tt = Tuple{Ptr{Nothing}, Int32, FieldsCuda}
    cufunction(k_fn, tt, maxregs=64)
end
