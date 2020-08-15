abstract type AbstractCeedVector end

struct CeedVectorActive <: AbstractCeedVector end
Base.getindex(::CeedVectorActive) = C.CEED_VECTOR_ACTIVE[]

struct CeedVectorNone <: AbstractCeedVector end
Base.getindex(::CeedVectorNone) = C.CEED_VECTOR_NONE[]

mutable struct CeedVector <: AbstractCeedVector
   ref::Ref{C.CeedVector}
   ceed::Ceed
end

function CeedVector(c::Ceed, len)
   ref = Ref{C.CeedVector}()
   C.CeedVectorCreate(c[], len, ref)
   obj = CeedVector(ref, c)
   finalizer(obj) do x
      # ccall(:jl_safe_printf, Cvoid, (Cstring, Cstring), "Finalizing %s.\n", repr(x))
      C.CeedVectorDestroy(x.ref)
   end
   return obj
end
Base.getindex(v::CeedVector) = v.ref[]
Base.setindex!(v::CeedVector, val) = C.CeedVectorSetValue(v[], val)

Base.ndims(::CeedVector) = 1
Base.ndims(::Type{CeedVector}) = 1
Base.axes(v::CeedVector) = (Base.OneTo(length(v)),)

function Base.copyto!(dest::CeedVector, bc::Base.Broadcast.Broadcasted)
   with_array(dest, MEM_HOST) do arr
      arr .= bc
   end
   dest
end

function Base.length(v::CeedVector)
   len = Ref{C.CeedInt}()
   C.CeedVectorGetLength(v[], len)
   return len[]
end

function with_array(f, v::CeedVector, mtype::MemType)
   arr_ref = Ref{Ptr{C.CeedScalar}}()
   C.CeedVectorGetArray(v[], mtype, arr_ref)
   arr = unsafe_wrap(Array, arr_ref[], length(v))
   local res
   try
      res = f(arr)
   finally
      C.CeedVectorRestoreArray(v[], arr_ref)
   end
   return res
end

function with_array_read(f, v::CeedVector, mtype::MemType)
   arr_ref = Ref{Ptr{C.CeedScalar}}()
   C.CeedVectorGetArrayRead(v[], mtype, arr_ref)
   arr = unsafe_wrap(Array, arr_ref[], length(v))
   local res
   try
      res = f(arr)
   finally
      C.CeedVectorRestoreArrayRead(v[], arr_ref)
   end
   return res
end