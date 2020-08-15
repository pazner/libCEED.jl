using libCEED

# A structure used to pass additional data to f_build_mass
mutable struct BuildContext
    dim::CeedInt
    space_dim::CeedInt
 end

@user_qfunction(
function f_build_mass(
        ctx::BuildContext,
        Q,
        J::(:in, Q, ctx.dim, ctx.dim),
        w::(:in, Q),
        qdata::(:out, Q))
    if ctx.dim == 1
        for i=1:Q
            qdata[i] = J[i]*w[i]
        end
    elseif ctx.dim == 2
        for i=1:Q
            qdata[i] = (J[i,1,1]*J[i,2,2] - J[i,2,1]*J[i,1,2]) * w[i];
        end
    elseif ctx.dim == 3
        for i=1:Q
            qdata[i] = (J[i,1,1]*(J[i,2,2]*J[i,3,3] - J[i,3,2]*J[i,2,3]) -
                        J[i,2,1]*(J[i,1,2]*J[i,3,3] - J[i,3,2]*J[i,1,3]) +
                        J[i,3,1]*(J[i,1,2]*J[i,2,3] - J[i,2,2]*J[i,1,3]))*w[i]
        end
    end
    return CeedInt(0)
end)

# libCEED Q-function for applying a mass operator
@user_qfunction(
function f_apply_mass(
        ::Nothing,
        Q::CeedInt,
        u::(:in, Q),
        qdata::(:in, Q),
        v::(:out, Q))
    for i=1:Q
       v[i] = qdata[i]*u[i]
    end
    return CeedInt(0)
end)
