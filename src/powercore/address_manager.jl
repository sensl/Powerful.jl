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
- `metadata::ModelMetadata`: Model metadata containing variables

# Returns
- A new struct type that inherits from ModelAddresses
"""
function make_addr_struct(model_type::Symbol, metadata::ModelMetadata)
    # Check if struct already exists
    struct_name = Symbol(model_type, :Addresses)
    if isdefined(@__MODULE__, struct_name)
        return
    end

    # Create fields for all variables - both own and foreign
    fields = [:($(Symbol("_" * String(var.name)))::Vector{UInt} = []) 
             for var in metadata.vars]
    
    @eval begin
        Base.@kwdef struct $(struct_name) <: ModelAddresses
            $(fields...)
        end
    end
end


"""
Create an address instance using model metadata and allocated addresses.

# Arguments
- `am::AddressManager`: The address manager containing allocations
- `metadata::ModelMetadata`: Model metadata containing variable specifications
"""
function make_addr_inst(
    am::AddressManager,
    metadata::ModelMetadata
)
    model_name = metadata.name  # Assuming we add this to ModelMetadata
    if !is_model_allocated(am, model_name)
        error("Model $model_name not allocated")
    end
    
    # Get the generated address type
    addr_type = getfield(@__MODULE__, Symbol(model_name, :Addresses))
    
    # Get allocations for internal variables
    var_allocations = _get_model_addrs_dict(am, model_name).var_allocations
    
    # Create indices only for internal variables
    # @kwdef will use empty vectors as defaults for external variables
    indices = NamedTuple(
        Symbol("_", var.name) => var_allocations[var.name]
        for var in metadata.vars
        if var isa ModelVar{Internal}
    )
    
    # Create instance with allocated indices
    addr_type(; indices...)
end

"""
Allocate addresses based on model's layout strategy
"""
function allocate_model!(
    am::AddressManager,
    model_name::Symbol,
    metadata::ModelMetadata,
    device_count::Int
)
    if metadata.layout == ContiguousVariables()
        _alloc_contiguous_vars!(am, model_name, metadata, device_count)
    elseif metadata.layout == ContiguousInstances()
        _alloc_contiguous_instances!(am, model_name, metadata, device_count)
    else
        throw(ArgumentError("Unsupported layout strategy"))
    end

end

function _alloc_contiguous_vars!(
    am::AddressManager,
    model_name::Symbol,
    metadata::ModelMetadata,
    device_count::Int,
)
    # Input sanity checks
    device_count > 0 || throw(ArgumentError("device_count must be positive"))
    
    if haskey(am.allocations, model_name)
        throw(ArgumentError("Model $model_name already has partial/complete allocation"))
    end

    var_allocations = Dict{Symbol, Vector{UInt}}()
    for req in metadata.vars
        start_idx = get!(am.next_idx, req.var_type, 1)
        range = collect(start_idx:(start_idx + device_count - 1))
        
        am.addresses[(req.var_type, model_name, req.name)] = range
        am.next_idx[req.var_type] = start_idx + device_count
        var_allocations[req.name] = range
    end

    # Record allocation
    am.allocations[model_name] = ModelAllocation(
        model_name,
        var_allocations,
        true  # complete allocation
    )
end

"""
Separate implementation for ContiguousInstances layout
"""
function _alloc_contiguous_instances!(
    am::AddressManager,
    model_name::Symbol,
    metadata::ModelMetadata,
    device_count::Int
)

    # Input sanity checks
    device_count > 0 || throw(ArgumentError("device_count must be positive"))
    
    if haskey(am.allocations, model_name)
        throw(ArgumentError("Model $model_name already has partial/complete allocation"))
    end

    vars_per_instance = length(metadata.vars)
    
    # Initialize start indices for each variable type
    type_start_indices = Dict{VarType,Int}()
    for req in metadata.vars
        type_start_indices[req.var_type] = get!(am.next_idx, req.var_type, 1)
    end
    
    var_allocations = Dict{Symbol, Vector{UInt}}()
    # Allocate all variables for each instance together
    for (var_idx, req) in enumerate(metadata.vars)
        start_idx = type_start_indices[req.var_type]
        addr_idx = start_idx + var_idx - 1
        
        am.addresses[(req.var_type, model_name, req.name)] = 
            collect(addr_idx:vars_per_instance:addr_idx + (device_count-1)*vars_per_instance)
            
        # Update next available index for this variable type
        am.next_idx[req.var_type] = start_idx + device_count * vars_per_instance

        var_allocations[req.name] = am.addresses[(req.var_type, model_name, req.name)]
    end

    # Record allocation
    am.allocations[model_name] = ModelAllocation(
        model_name,
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
    using Powerful
    using Powerful.Models
    using Powerful.PowerCore
    using Powerful.PowerCore: is_model_allocated, is_var_allocated

    ### === Test ContiguousVariables layout === ###
    am = AddressManager()
    bus_metadata = model_metadata(Bus)
    allocate_model!(am, :Bus, bus_metadata, 5);

    @test am.allocations[:Bus].is_complete
    @test is_model_allocated(am, :Bus)
    @test is_var_allocated(am, :Bus, :theta)
    @test is_var_allocated(am, :Bus, :v)

    make_addr_struct(:Bus, bus_metadata)
    addr = make_addr_inst(am, bus_metadata)
    @test all(addr._theta .== collect(UInt, 1:5))
    @test all(addr._v .== collect(UInt, 6:10))

    ### === Test ContiguousInstances layout === ###
    am = AddressManager()
    allocate_model!(am, :Bus, model_metadata(Bus; layout=ContiguousInstances()), 5);

    make_addr_struct(:Bus, bus_metadata)
    addr = make_addr_inst(am, bus_metadata)
    @test all(addr._theta .== [1, 3, 5, 7, 9])
    @test all(addr._v .== [2, 4, 6, 8, 10])

    # Add more edge cases
    am = AddressManager()
    @test_throws ArgumentError allocate_model!(am, :Bus, bus_metadata, 0)
    
    # Test reallocation attempts
    am = AddressManager()
    allocate_model!(am, :Bus, bus_metadata, 5)
    @test_throws ArgumentError allocate_model!(am, :Bus, bus_metadata, 3)
    
end