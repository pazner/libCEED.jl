# A structure used to pass additional data to f_build_mass
mutable struct BuildContext
    dim::CeedInt
    space_dim::CeedInt
end

function wdetJ(Q, J, w, qdata, D)
    for i=1:Q
        qdata[i] = w[i]*det(@view(J[i,:,:]), D)
    end
end

@user_qfunction(
function f_build_mass(
        ctx::BuildContext,
        Q,
        J::(:in, Q, ctx.dim, ctx.dim),
        w::(:in, Q),
        qdata::(:out, Q))
    wdetJ(Q, J, w, qdata, CeedDim(ctx.dim))
    return CeedInt(0)
end)

# libCEED Q-function for applying a mass operator
@user_qfunction(
function f_apply_mass(::Nothing, Q::CeedInt, u::(:in, Q), qdata::(:in, Q), v::(:out, Q))
    for i=1:Q
        v[i] = qdata[i]*u[i]
    end
    return CeedInt(0)
end)
