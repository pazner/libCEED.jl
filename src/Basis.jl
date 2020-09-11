abstract type AbstractBasis end

struct BasisCollocated <: AbstractBasis end
Base.getindex(::BasisCollocated) = C.CEED_BASIS_COLLOCATED[]

"""
    Basis

Wraps a CeedBasis object, representing a finite element basis.

See also: `create_tensor_h1_lagrange_basis`
"""
mutable struct Basis <: AbstractBasis
    ref::Ref{C.CeedBasis}
    function Basis(ref)
        obj = new(ref)
        finalizer(obj) do x
            # ccall(:jl_safe_printf, Cvoid, (Cstring, Cstring), "Finalizing %s.\n", repr(x))
            C.CeedBasisDestroy(x.ref)
        end
        return obj
    end
end
Base.getindex(b::Basis) = b.ref[]

@doc raw"""
    create_tensor_h1_lagrange_basis(ceed, dim, ncomp, p, q, quad_mode)

Create a tensor-product Lagrange basis.

# Arguments
- `ceed`:  A Ceed object where the CeedBasis will be created
- `dim`:   Topological dimension of element
- `ncomp`: Number of field components (1 for scalar fields)
- `p`:     Number of Gauss-Lobatto nodes in one dimension.  The
                  polynomial degree of the resulting $Q_k$ element is $k=p-1$.
- `q`:     Number of quadrature points in one dimension.
- `qmode`: Distribution of the `q` quadrature points (affects order of
                  accuracy for the quadrature)
"""
function create_tensor_h1_lagrange_basis(c::Ceed, dim, ncomp, p, q, quad_mode::QuadMode)
    ref = Ref{C.CeedBasis}()
    C.CeedBasisCreateTensorH1Lagrange(c[], dim, ncomp, p, q, quad_mode, ref)
    Basis(ref)
end
