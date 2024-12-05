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
export VarSpec, ModelMetadata
export ContiguousVariables, ContiguousInstances, LayoutStrategy

include("address_manager.jl")
export AddressManager
export allocate_model!, get_var_addresses

include("system.jl")

include("vectorizer.jl")

include("format_traits.jl")

end # module