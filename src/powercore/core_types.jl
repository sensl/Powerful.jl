abstract type AbstractModel end

### ============================= ###
abstract type VarOwnership end
struct OwnVar <: VarOwnership end
struct ForeignVar{Ti<:Integer,T<:AbstractVector{Ti}} <: VarOwnership
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
const PropertyDict = Dict{Type{<:VarProperty},VarProperty}

abstract type VarTrait end
struct Internal <: VarTrait end
struct External <: VarTrait end

abstract type AddressableType end
abstract type AddressableVar <: AddressableType end
abstract type AddressableRes <: AddressableType end

struct AlgebVar <: AddressableVar end
struct StateVar <: AddressableVar end
struct ObservedVar <: AddressableVar end
struct AlgebRes <: AddressableRes end
struct StateRes <: AddressableRes end

"""
    ModelVar{T<:VarTrait, VT, SM, Props} represents a variable in a power system model

Type parameters:
- T: Variable trait (Internal/External)
- VT: Variable type (e.g., Algeb, State) or Nothing
- SM: Source model type or Nothing
- Props: Type of properties dictionary
"""
struct ModelVar{
    T<:VarTrait,
    AT<:AddressableVar,
    SM<:Union{Symbol,Nothing},
    Props<:PropertyDict
}
    name::Symbol
    address_type::AT
    source_model::SM
    source_var::Union{Symbol,Nothing}
    properties::Props
end

abstract type ResAccess end
struct SharedRes <: ResAccess end
struct PrivateRes <: ResAccess end

struct ModelResidual{
    T<:VarTrait,
    AT<:AddressableRes,
    RA<:ResAccess,
    SM<:Union{Symbol,Nothing},
    SR<:Union{Symbol,Nothing},
    IN<:Union{Symbol,Nothing}
}
    name::Symbol
    address_type::AT
    access::RA
    source_model::SM
    source_residual::SR
    indexer::IN
    description::String
end

export AddressableType, AddressableVar, AddressableRes
export AlgebVar, StateVar, ObservedVar
export AlgebRes, StateRes
export VarTrait, Internal, External
export VarOwnership, OwnVar, ForeignVar
export VarProperty, Description, Units, Bounds, PropertyDict
export ModelVar

export ResTrait, PartialRes, FullRes, SharedRes
export ModelResidual
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
mutable struct ModelAllocation
    model_name::Symbol
    # maps addressable type => variable name => range
    by_type::Dict{AddressableType,Dict{Symbol,Vector{UInt}}}
    is_complete::Bool  # true if all required variables are allocated
end

"""
Enhanced address manager with explicit allocation tracking
"""
Base.@kwdef struct AddressManager
    addresses::Dict{Tuple{AddressableType,Symbol,Symbol},Vector{UInt}} = Dict()
    next_idx::Dict{AddressableType,Int} = Dict()

    # Allocation tracking
    allocations::Dict{Symbol,ModelAllocation} = Dict()
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
    residuals::Vector{ModelResidual}
    layout::LayoutStrategy = ContiguousVariables()
end

# Bus/Node model types
abstract type NodeTrait end
struct ACNode <: NodeTrait end
struct DCNode <: NodeTrait end

# Load model types
abstract type AbstractLoad{Tv} <: AbstractModel end

export ModelMetadata
export NodeTrait, ACNode, DCNode
export AbstractLoad

### ============= End Model Metadata and Traits ============= ###

### ============= System Types ============= ###

mutable struct SystemModel{T<:NamedTuple}
    address_manager::AddressManager
    models::T
    # TODO: Boundary buses/dc nodes?

    # Inner constructor to validate component types
    function SystemModel(am::AddressManager, components::NamedTuple)
        # Ensure all elements are vectors of AbstractModel subtypes
        all(V -> V <: AbstractModel, typeof.(values(components))) ||
            error("All components must be vectors of AbstractModel subtypes")
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
