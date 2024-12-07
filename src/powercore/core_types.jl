abstract type AbstractModel end

### ============================= ###
abstract type VarOwnership end
struct OwnVar <: VarOwnership end
struct ForeignVar{Ti<:Integer, T<:AbstractVector{Ti}} <: VarOwnership
    model_name::Symbol
    var_name::Symbol
    indexer::T
end

# === Variable Traits === #
abstract type VarProperty end

struct Description <: VarProperty
    value::String
end

struct Units <: VarProperty
    value::String
end

struct Bounds <: VarProperty
    min::Float64
    max::Float64
end

# Type-safe property collection
const PropertyDict = Dict{Type{<:VarProperty}, VarProperty}

abstract type VarTrait end
struct Internal <: VarTrait end
struct External <: VarTrait end

abstract type VarType end
struct Algeb <: VarType end
struct State <: VarType end
struct Observed <: VarType end

"""
    ModelVar{T<:VarTrait, VT, SM, Props} represents a variable in a power system model

Type parameters:
- T: Variable trait (Internal/External)
- VT: Variable type (e.g., Algeb, State) or Nothing
- SM: Source model type or Nothing
- Props: Type of properties dictionary
"""
struct ModelVar{T<:VarTrait, VT<:Union{VarType, Nothing}, SM<:Union{Type, Nothing}, Props<:PropertyDict}
    name::Symbol
    var_type::VT
    source_model::SM
    source_var::Union{Symbol, Nothing}
    properties::Props
end


abstract type ResidualType end
struct PartialResidual <: ResidualType end
struct FullResidual <: ResidualType end

export VarType, Algeb, State, Observed
export VarTrait, Internal, External
export VarOwnership, OwnVar, ForeignVar
export ResidualType, PartialResidual, FullResidual
export VarProperty, Description, Units, Bounds, PropertyDict
export ModelVar
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


export AddressManager
export LayoutStrategy, ContiguousVariables, ContiguousInstances, CustomAddressing
export ModelAllocation

### ============= End Address Manager ============= ###

### ============= Model Metadata and Traits ============= ###

"""
    ModelMetadata

"""
Base.@kwdef struct ModelMetadata
    name::Symbol
    vars::Vector{ModelVar}
    output_vars::Vector{Symbol}
    layout::LayoutStrategy = ContiguousVariables()
end




export ModelMetadata

### ============= End Model Metadata and Traits ============= ###

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
