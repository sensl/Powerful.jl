"""
Core interface definition for all models
"""

module PowerCore
using DocStringExtensions
using TestItems
using Logging
using StructArrays

include("core_types.jl")


export AbstractModel, AbstractModelVec, AbstractModelNumerical
export ModelMetadata
export ContiguousVariables, ContiguousInstances, LayoutStrategy

include("address_manager.jl")
export allocate_model!, get_var_addresses

include("system.jl")

include("format_traits.jl")

include("model_var.jl")

end # module