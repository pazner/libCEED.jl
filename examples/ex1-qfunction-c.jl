using UnsafeArrays

# A structure used to pass additional data to f_build_mass
mutable struct BuildContextC
   dim::CeedInt
   space_dim::CeedInt
end

# libCEED Q-function for building quadrature data for a mass operator
function f_build_mass_c(ctx_ptr::Ptr{Cvoid}, Q::CeedInt, in_ptr::Ptr{Ptr{CeedScalar}}, out_ptr::Ptr{Ptr{CeedScalar}})
    # in[0] is Jacobians with shape [dim, nc=dim, Q]
    # in[1] is quadrature weights, size (Q)
    ctx = unsafe_load(Ptr{BuildContextC}(ctx_ptr))
    J = UnsafeArray(unsafe_load(in_ptr, 1), (Int(Q),Int(ctx.dim^2)))
    w = UnsafeArray(unsafe_load(in_ptr, 2), (Int(Q),))
    qdata = UnsafeArray(unsafe_load(out_ptr, 1), (Int(Q),))
    if ctx.dim == 1
        @inbounds @simd for i=1:Q
            qdata[i] = J[i]*w[i]
        end
    elseif ctx.dim == 2
        @inbounds @simd for i=1:Q
            qdata[i] = (J[i,1]*J[i,4] - J[i,2]*J[i,3]) * w[i];
        end
    elseif ctx.dim == 3
        @inbounds @simd for i=1:Q
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
function f_apply_mass_c(ctx, Q::CeedInt, in_ptr::Ptr{Ptr{CeedScalar}}, out_ptr::Ptr{Ptr{CeedScalar}})
    u = UnsafeArray(unsafe_load(in_ptr, 1), (Int(Q),))
    qdata = UnsafeArray(unsafe_load(in_ptr, 2), (Int(Q),))
    v = UnsafeArray(unsafe_load(out_ptr, 1), (Int(Q),))
    @inbounds @simd for i=1:Q
       v[i] = qdata[i]*u[i]
    end
    return CeedInt(0)
end
