abstract type AbstractRequest end

struct RequestImmediate <: AbstractRequest end
Base.getindex(::RequestImmediate) = C.CEED_REQUEST_IMMEDIATE[]

struct RequestOrdered <: AbstractRequest end
Base.getindex(::RequestOrdered) = C.CEED_REQUEST_ORDERED[]
