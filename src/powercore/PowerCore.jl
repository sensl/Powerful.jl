"""
Core interface definition for all models
"""

module PowerCore
using DocStringExtensions

include("core_types.jl")


export AbstractModel
export VarType, Algebraic, State
export VarRequirement, ModelMetadata
export ContiguousVariables, ContiguousInstances, LayoutStrategy

include("required_interfaces.jl")
export get_var_requirements, compute_residuals!

include("address_manager.jl")
export AddressManager
export allocate_model!, get_var_addresses


include("system.jl")
export SystemModel

end # module