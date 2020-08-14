# A structure used to pass additional data to f_build_mass
mutable struct BuildContext
   dim::CeedInt
   space_dim::CeedInt
end

# libCEED Q-function for building quadrature data for a mass operator
function f_build_mass(ctx_ptr::Ptr{Cvoid}, Q::CeedInt, in::Ptr{Ptr{CeedScalar}}, out::Ptr{Ptr{CeedScalar}})
    # in[0] is Jacobians with shape [dim, nc=dim, Q]
    # in[1] is quadrature weights, size (Q)
    ctx = unsafe_pointer_to_objref(Ptr{BuildContext}(ctx_ptr))
    J = unsafe_wrap(Array, unsafe_load(in, 1), (Q,ctx.dim^2))
    w = unsafe_wrap(Array, unsafe_load(in, 2), Q)
    qdata = unsafe_wrap(Array, unsafe_load(out), Q)
    if ctx.dim == 1
        for i=1:Q
            qdata[i] = J[i]*w[i]
        end
    elseif ctx.dim == 2
        for i=1:Q
            qdata[i] = (J[i,1]*J[i,4] - J[i,2]*J[i,3]) * w[i];
        end
    elseif ctx.dim == 3
        for i=1:Q
            qdata[i] = (J[i,1]*(J[i,5]*J[i,9] - J[i,6]*J[i,8]) -
                        J[i,2]*(J[i,4]*J[i,9] - J[i,6]*J[i,7]) +
                        J[i,3]*(J[i,4]*J[i,8] - J[i,5]*J[i,7])) * w[i]
        end
    else
        error("Bad dimension")
    end
    return CeedInt(0)
end

# libCEED Q-function for applying a mass operator
function f_apply_mass(ctx, Q::CeedInt, in::Ptr{Ptr{CeedScalar}}, out::Ptr{Ptr{CeedScalar}})
    u = unsafe_wrap(Array, unsafe_load(in, 1), Q)
    qdata = unsafe_wrap(Array, unsafe_load(in, 2), Q)
    v = unsafe_wrap(Array, unsafe_load(out), Q)
    for i=1:Q
       v[i] = qdata[i]*u[i]
    end
    return CeedInt(0)
end
