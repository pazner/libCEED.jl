using StaticArrays

# A structure used to pass additional data to f_build_mass
mutable struct BuildContext
    dim::CeedInt
    space_dim::CeedInt
end

function wdetJJinvJinvT(Q, J, w, qdata, D::CeedDim{dim}) where dim
    for i=1:Q
        Ji = SMatrix{dim,dim}(@view(J[i,:,:]))
        Jinv = inv(Ji)
        qdata[i,:] .= setvoigt(w[i]*det(Ji)*Jinv*Jinv')
    end
end

# libCEED Q-function for building quadrature data for a diffusion operator
@user_qfunction(
function f_build_diff(
        ctx::BuildContext, Q,
        J::(:in, Q, ctx.dim, ctx.dim), w::(:in, Q),
        qdata::(:out, Q, ctx.dim*(ctx.dim+1)÷2))
    @withdim (D=ctx.dim) wdetJJinvJinvT(Q, J, w, qdata, D)
    CeedInt(0)
end)

function dXdxdXdxTdu(Q, ug, qdata, vg, D::CeedDim{dim}) where dim
    for i=1:Q
        dXdxdXdxT = getvoigt(@view(qdata[i,:]), D)
        vg[i,:] .= dXdxdXdxT*@view(ug[i,:])
    end
end

# libCEED Q-function for applying a diff operator
@user_qfunction(
function f_apply_diff(
        ctx::BuildContext, Q,
        ug::(:in, Q, ctx.dim), qdata::(:in, Q, ctx.dim*(ctx.dim+1)÷2),
        vg::(:out, Q, ctx.dim))
    @withdim (D=ctx.dim) dXdxdXdxTdu(Q, ug, qdata, vg, D)
    CeedInt(0)
end)
