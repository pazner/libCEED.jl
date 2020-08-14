mutable struct Operator
   ref::Ref{C.CeedOperator}
   ceed::Ceed
   function Operator(ref, ceed)
      obj = new(ref, ceed)
      finalizer(obj) do x
          # ccall(:jl_safe_printf, Cvoid, (Cstring, Cstring), "Finalizing %s.\n", repr(x))
          C.CeedOperatorDestroy(x.ref)
      end
      return obj
   end
end
Base.getindex(op::Operator) = op.ref[]

function Operator(c::Ceed, qf::AbstractQFunction, dqf::AbstractQFunction, dqfT::AbstractQFunction)
   ref = Ref{C.CeedOperator}()
   C.CeedOperatorCreate(c[], qf[], dqf[], dqfT[], ref)
   Operator(ref, c)
end

function set_field!(op::Operator, fieldname::AbstractString, r::AbstractElemRestriction, b::AbstractBasis, v::AbstractCeedVector)
   C.CeedOperatorSetField(op[], fieldname, r[], b[], v[])
end

function apply!(op::Operator, vin::AbstractCeedVector, vout::AbstractCeedVector, request::AbstractRequest)
   C.CeedOperatorApply(op[], vin[], vout[], request[])
end
