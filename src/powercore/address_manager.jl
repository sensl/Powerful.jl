"""
Generates a concrete ModelAddresses type for a given model
"""
function generate_addresses_type(model_type::Symbol, requirements::NTuple{N, VarRequirement}) where N
    fields = [:($(Symbol("_" * String(req.name)))::Vector{UInt}) for req in requirements]
    
    # Generate the struct definition
    @eval begin
        Base.@kwdef struct $(Symbol(model_type, :Addresses)) <: ModelAddresses
            $(fields...)
        end
    end
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


"""
Get all allocated addresses for a model instance
"""
function get_model_instance_addresses(
    am::AddressManager,
    model_type::Symbol,
)
    if !is_model_allocated(am, model_type)
        error("Model $model_type not allocated")
    end
    
    return am.allocations[model_type]
end

"""
Create an address instance for a specific model instance
"""
function create_address_instance(
    am::AddressManager,
    model_type::Symbol,
)
    if !is_model_allocated(am, model_type)
        error("Model $model_type not allocated")
    end
    
    # Get the generated address type
    addr_type = getfield(@__MODULE__, Symbol(model_type, :Addresses))

    var_allocations = get_model_instance_addresses(am, model_type).var_allocations
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
    # Confirm model is not already allocated
    if haskey(am.allocations, model_type)
        error("Model $model_type already has partial/complete allocation")
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

    # Confirm model is not already allocated
    if haskey(am.allocations, model_type)
        error("Model $model_type already has partial/complete allocation")
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

export allocate_model!
export generate_addresses_type, create_address_instance


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

    generate_addresses_type(:Bus, BusMetadata{ContiguousVariables}().internal_vars)
    addr = create_address_instance(am, :Bus)
    @show addr._theta
    @test all(addr._theta .== collect(UInt, 1:5))
    @test all(addr._v .== collect(UInt, 6:10))

    ### === Test ContiguousInstances layout === ###
    am = AddressManager()
    allocate_model!(am, :Bus, BusMetadata{ContiguousInstances}(), 5);

    generate_addresses_type(:Bus, BusMetadata{ContiguousInstances}().internal_vars)
    addr = create_address_instance(am, :Bus)
    @show addr._theta
    @test all(addr._theta .== [1, 3, 5, 7, 9])
    @test all(addr._v .== [2, 4, 6, 8, 10])

end