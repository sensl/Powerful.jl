abstract type AbstractModel end

### ============================= ###
abstract type VarType end
struct Algebraic <: VarType end
struct State <: VarType end
### ============================= ###

### ========== Address Manager ========== ###

"""
Abstract type for model-specific addresses
Generated based on model requirements
"""
abstract type ModelAddresses end


"""
Tracks allocation status for a specific model type
"""
struct ModelAllocation
    model_name::Symbol
    var_allocations::Dict{Symbol, Vector{UInt}}  # var_name => range
    is_complete::Bool  # true if all required variables are allocated
end

"""
Enhanced address manager with explicit allocation tracking
"""
Base.@kwdef struct AddressManager
    addresses::Dict{Tuple{VarType, Symbol, Symbol}, Vector{UInt}} = Dict()
    next_idx::Dict{VarType, Int} = Dict()

    # Allocation tracking
    allocations::Dict{Symbol, ModelAllocation} = Dict()
end

"""
Base types for layout strategy and metadata
"""
abstract type LayoutStrategy end
struct ContiguousVariables <: LayoutStrategy end
struct ContiguousInstances <: LayoutStrategy end
struct CustomAddressing <: LayoutStrategy end

"""
Simplified variable requirement
"""
struct VarRequirement
    name::Symbol
    var_type::VarType
end

"""
Model metadata containing variable requirements and layout strategy
"""
abstract type ModelMetadata{T<:LayoutStrategy} end

export AddressManager, LayoutStrategy, ContiguousVariables, ContiguousInstances, CustomAddressing, ModelAllocation, VarRequirement, ModelMetadata

### ============= End Address Manager ============= ###

### ============= System Types ============= ###

struct SystemModel{T<:Tuple}
    address_manager::AddressManager
    components::T

    # Inner constructor to validate component types
    function SystemModel(am::AddressManager, components::Tuple)
        # Ensure all elements are vectors of AbstractModel subtypes
        all(V -> V <: AbstractModel, typeof.(components)) || 
            error("All components must be AbstractModel subtypes")
        new{typeof(components)}(am, components)
    end
end

export SystemModel
# export iterate

### ========================================= ###