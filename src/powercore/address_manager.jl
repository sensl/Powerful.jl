"""
Get all allocated addresses for a model instance
"""
function _get_model_addrs_dict(
    am::AddressManager,
    model_type::Symbol,
)
    if !is_model_allocated(am, model_type)
        error("Model $model_type not allocated")
    end
    
    return am.allocations[model_type]
end

"""
$(SIGNATURES)

Generate a concrete ModelAddresses struct for a given model type.

# Arguments
- `model_type::Symbol`: The type of model (e.g., :Bus, :Branch)
- `variables::NTuple{N, VarSpec}`: Variables required by the model

# Returns
- A new struct type that inherits from ModelAddresses
"""
function make_addr_struct(model_type::Symbol, variables::NTuple{N, VarSpec}) where N
    # Check if struct already exists
    struct_name = Symbol(model_type, :Addresses)
    if isdefined(@__MODULE__, struct_name)
        return
    end

    fields = [:($(Symbol("_" * String(req.name)))::Vector{UInt}) for req in variables]
    
    # Generate the struct definition
    @eval begin
        Base.@kwdef struct $(struct_name) <: ModelAddresses
            $(fields...)
        end
    end
end

"""
Create an address instance for a specific model instance
"""
function make_addr_inst(
    am::AddressManager,
    model_type::Symbol,
)
    if !is_model_allocated(am, model_type)
        error("Model $model_type not allocated")
    end
    
    # Get the generated address type
    addr_type = getfield(@__MODULE__, Symbol(model_type, :Addresses))

    var_allocations = _get_model_addrs_dict(am, model_type).var_allocations
    indices = NamedTuple(Symbol("_", k) => v for (k, v) in var_allocations)
    # Create instance with pre-computed indices
    addr_type(; indices...)
end

"""
Allocate addresses based on model's layout strategy
"""
function allocate_model!(
    am::AddressManager,
    model_type::Symbol,
    metadata::M,
    instance_count::Int
) where {M<:ModelMetadata{ContiguousVariables}}

    # Input sanity checks
    instance_count > 0 || throw(ArgumentError("instance_count must be positive"))
    
    if haskey(am.allocations, model_type)
        throw(ArgumentError("Model $model_type already has partial/complete allocation"))
    end

    var_allocations = Dict{Symbol, Vector{UInt}}()
    for req in metadata.internal_vars
        start_idx = get!(am.next_idx, req.var_type, 1)
        range = collect(start_idx:(start_idx + instance_count - 1))
        
        am.addresses[(req.var_type, model_type, req.name)] = range
        am.next_idx[req.var_type] = start_idx + instance_count
        var_allocations[req.name] = range
    end

    # Record allocation
    am.allocations[model_type] = ModelAllocation(
        model_type,
        var_allocations,
        true  # complete allocation
    )
end

"""
Separate implementation for ContiguousInstances layout
"""
function allocate_model!(
    am::AddressManager,
    model_type::Symbol,
    metadata::M,
    instance_count::Int
) where {M<:ModelMetadata{ContiguousInstances}}

    # Input sanity checks
    instance_count > 0 || throw(ArgumentError("instance_count must be positive"))
    
    if haskey(am.allocations, model_type)
        throw(ArgumentError("Model $model_type already has partial/complete allocation"))
    end

    vars_per_instance = length(metadata.internal_vars)
    
    # Initialize start indices for each variable type
    type_start_indices = Dict{VarType,Int}()
    for req in metadata.internal_vars
        type_start_indices[req.var_type] = get!(am.next_idx, req.var_type, 1)
    end
    
    var_allocations = Dict{Symbol, Vector{UInt}}()
    # Allocate all variables for each instance together
    for (var_idx, req) in enumerate(metadata.internal_vars)
        start_idx = type_start_indices[req.var_type]
        addr_idx = start_idx + var_idx - 1
        
        am.addresses[(req.var_type, model_type, req.name)] = 
            collect(addr_idx:vars_per_instance:addr_idx + (instance_count-1)*vars_per_instance)
            
        # Update next available index for this variable type
        am.next_idx[req.var_type] = start_idx + instance_count * vars_per_instance

        var_allocations[req.name] = am.addresses[(req.var_type, model_type, req.name)]
    end

    # Record allocation
    am.allocations[model_type] = ModelAllocation(
        model_type,
        var_allocations,
        true  # complete allocation
    )
end

"""
Check if model is fully allocated
"""
function is_model_allocated(am::AddressManager, model_name::Symbol)
    haskey(am.allocations, model_name) && 
        am.allocations[model_name].is_complete
end


"""
Check if specific variable is allocated
"""
function is_var_allocated(am::AddressManager, model_name::Symbol, var::Symbol)
    haskey(am.allocations, model_name) &&
        haskey(am.allocations[model_name].var_allocations, var)
end

export allocate_model!
export make_addr_struct, make_addr_inst


@testitem "Address Manager" begin
    using Powerful.Models
    using Powerful.PowerCore
    using Powerful.PowerCore: is_model_allocated, is_var_allocated

    ### === Test ContiguousVariables layout === ###
    am = AddressManager()
    allocate_model!(am, :Bus, BusMetadata{ContiguousVariables}(), 5);

    @test am.allocations[:Bus].is_complete
    @test is_model_allocated(am, :Bus)
    @test is_var_allocated(am, :Bus, :theta)
    @test is_var_allocated(am, :Bus, :v)

    make_addr_struct(:Bus, BusMetadata{ContiguousVariables}().internal_vars)
    addr = make_addr_inst(am, :Bus)
    @test all(addr._theta .== collect(UInt, 1:5))
    @test all(addr._v .== collect(UInt, 6:10))

    ### === Test ContiguousInstances layout === ###
    am = AddressManager()
    allocate_model!(am, :Bus, BusMetadata{ContiguousInstances}(), 5);

    make_addr_struct(:Bus, BusMetadata{ContiguousInstances}().internal_vars)
    addr = make_addr_inst(am, :Bus)
    @test all(addr._theta .== [1, 3, 5, 7, 9])
    @test all(addr._v .== [2, 4, 6, 8, 10])

    # Add more edge cases
    am = AddressManager()
    @test_throws ArgumentError allocate_model!(am, :Bus, BusMetadata{ContiguousVariables}(), 0)
    
    # Test reallocation attempts
    am = AddressManager()
    allocate_model!(am, :Bus, BusMetadata{ContiguousVariables}(), 5)
    @test_throws ArgumentError allocate_model!(am, :Bus, BusMetadata{ContiguousVariables}(), 3)
    
end