module Models
using DocStringExtensions
using PowerFlowData
using InlineStrings
using TestItems
using StructArrays

using Powerful.PowerCore

include("soa_interface.jl")
include("model_traits.jl")
include("bus.jl")

include("model_registry.jl")

export model_metadata

end # module
