using StaticArrays

# A structure used to pass additional data to f_build_mass
mutable struct BuildContext
    dim::CeedInt
    space_dim::CeedInt
end

# libCEED Q-function for building quadrature data for a diffusion operator
@user_qfunction(
function f_build_diff(
        ctx::BuildContext, Q,
        J::(:in, Q, ctx.dim^2), w::(:in, Q),
        qdata::(:out, Q, ctx.dim*(ctx.dim+1)÷2))
    # At every quadrature point, compute w/det(J).adj(J).adj(J)^T and store
    # the symmetric part of the result.
    if ctx.dim == 1
        for i=1:Q
            qdata[i] = w[i]/J[i]
        end
    elseif ctx.dim == 2
        for i=1:Q
            J11 = J[i,1]
            J21 = J[i,2]
            J12 = J[i,3]
            J22 = J[i,4]
            qw = w[i]/(J11*J22 - J21*J12)
            qdata[i,1] =  qw*(J12*J12 + J22*J22)
            qdata[i,2] =  qw*(J11*J11 + J21*J21)
            qdata[i,3] = -qw*(J11*J12 + J21*J22)
        end
    elseif ctx.dim == 3
        for i=1:Q
            # Compute the adjoint
            A = @SMatrix [
                    J[i,(j+1)%3+3*((k+1)%3)+1]*J[i,(j+2)%3+3*((k+2)%3)+1] -
                    J[i,(j+1)%3+3*((k+2)%3)+1]*J[i,(j+2)%3+3*((k+1)%3)+1]
                    for j=0:2, k=0:2]
            # Compute quadrature weight / det(J)
            qw = w[i]/(J[i,1]*A[1,1] + J[i,2]*A[2,2] + J[i,3]*A[3,3])
            # Compute geometric factors
            # Stored in Voigt convention
            # 0 5 4
            # 5 1 3
            # 4 3 2
            qdata[i,1] = qw*(A[1,1]*A[1,1] + A[2,1]*A[2,1] + A[3,1]*A[3,1])
            qdata[i,2] = qw*(A[1,2]*A[1,2] + A[2,2]*A[2,2] + A[3,2]*A[3,2])
            qdata[i,3] = qw*(A[1,3]*A[1,3] + A[2,3]*A[2,3] + A[3,3]*A[3,3])
            qdata[i,4] = qw*(A[1,2]*A[1,3] + A[2,2]*A[2,3] + A[3,2]*A[3,3])
            qdata[i,5] = qw*(A[1,1]*A[1,3] + A[2,1]*A[2,3] + A[3,1]*A[3,3])
            qdata[i,6] = qw*(A[1,1]*A[1,2] + A[2,1]*A[2,2] + A[3,1]*A[3,2])
        end
    end
    CeedInt(0)
end
)

# libCEED Q-function for applying a diff operator
@user_qfunction(
function f_apply_diff(
        ctx::BuildContext, Q,
        ug::(:in, Q, ctx.dim), qdata::(:in, Q, ctx.dim*(ctx.dim+1)÷2),
        vg::(:out, Q, ctx.dim))
    if ctx.dim == 1
        for i=1:Q
            vg[i] = ug[i]*qdata[i]
        end
    elseif ctx.dim == 2
        for i=1:Q
            # Read spatial derivatives of u
            du = @SVector [ug[i,1], ug[i,2]]
            # Read qdata (dXdxdXdxT symmetric matrix)
            dXdxdXdxT = @SMatrix [qdata[i,1] qdata[i,3] ; qdata[i,3] qdata[i,2]]
            for j=1:2
                vg[i,j] = du[1]*dXdxdXdxT[j,1] + du[2]*dXdxdXdxT[j,2]
            end
        end
    elseif ctx.dim == 3
        for i=1:Q
            # Read spatial derivatives of u
            du = @SVector [ug[i,1], ug[i,2], ug[i,3]]
            # Read qdata (dXdxdXdxT symmetric matrix)
            dXdxdXdxT = @SMatrix [
                qdata[i,1]    qdata[i,6]    qdata[i,5]
                qdata[i,6]    qdata[i,2]    qdata[i,4]
                qdata[i,5]    qdata[i,4]    qdata[i,3]
            ]
            # j = direction of vg
            for j=1:3
                vg[i,j] = (du[1] * dXdxdXdxT[j,1] +
                           du[2] * dXdxdXdxT[j,2] +
                           du[3] * dXdxdXdxT[j,3])
            end
        end
    end
    CeedInt(0)
end
)
