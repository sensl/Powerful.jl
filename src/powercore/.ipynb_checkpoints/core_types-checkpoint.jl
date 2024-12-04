### ========== Model Types ========== ###
abstract type AbstractModel end

### =========== End Model Types ========== ###

### ============================= ###
abstract type VarType end
struct Algebraic <: VarType end
struct State <: VarType end
struct Observable <: VarType end
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
    var_allocations::Dict{Symbol, UnitRange{Int}}  # var_name => range
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
Simplified variable requirement without individual layout
"""
struct VarRequirement
    name::Symbol
    var_type::VarType
end

"""
Model metadata containing variable requirements and layout strategy
"""
abstract type ModelMetadata{T<:LayoutStrategy} end
