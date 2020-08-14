function gauss_quadrature(q)
   x = zeros(CeedScalar, q)
   w = zeros(CeedScalar, q)
   C.CeedGaussQuadrature(q, x, w)
   x,w
end

struct QuadratureMode{T} end
const Abscissa = QuadratureMode{:Abscissa}()
const AbscissaAndWeights = QuadratureMode{:AbscissaAndWeights}()

function lobatto_quadrature(q, ::Mode=Abscissa) where Mode
   return_weights = (Mode() != Abscissa)
   x = zeros(CeedScalar, q)
   w = (return_weights) ? zeros(CeedScalar, q) : C_NULL
   C.CeedLobattoQuadrature(q, x, w)
   return_weights ? (x,w) : x
end
