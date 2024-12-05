abstract type AbstractModel end

### ============================= ###
abstract type VarType end
struct Algebraic <: VarType end
struct State <: VarType end
struct Observed <: VarType end

abstract type VarOwnership end
struct OwnVar <: VarOwnership end
struct ForeignVar{Ti<:Integer, T<:AbstractVector{Ti}} <: VarOwnership
    model_name::Symbol
    var_name::Symbol
    indexer::T
end

abstract type ResidualType end
struct PartialResidual <: ResidualType end
struct FullResidual <: ResidualType end

export VarType, Algebraic, State, Observed
export VarOwnership, OwnVar, ForeignVar
export ResidualType, PartialResidual, FullResidual
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
struct VarSpec
    name::Symbol
    var_type::VarType
    var_boundary::VarOwnership
end

"""
Model metadata containing variable requirements and layout strategy
"""
abstract type ModelMetadata{T<:LayoutStrategy} end

export AddressManager
export LayoutStrategy, ContiguousVariables, ContiguousInstances, CustomAddressing
export ModelAllocation, VarSpec, ModelMetadata

### ============= End Address Manager ============= ###

### ============= System Types ============= ###

struct SystemModel{T<:Tuple}
    address_manager::AddressManager
    models::T

    # Inner constructor to validate component types
    function SystemModel(am::AddressManager, components::Tuple)
        # Ensure all elements are vectors of AbstractModel subtypes
        all(V -> V <: AbstractModel, typeof.(components)) || 
            error("All components must be AbstractModel subtypes")
        new{typeof(components)}(am, components)
    end
end

export SystemModel

### ========================================= ###


### ============= Data Format Types ============= ###

abstract type DataFormat end
struct PSSE <: DataFormat end
struct MATPOWER <: DataFormat end

export DataFormat, PSSE

### ========================================= ###
