export allocate_model!
export make_addr_struct, make_addr_inst
export retrieve_addresses
export get_key, get_key_name

function get_key(model_vec::AbstractModel)
    # Get parent model type by removing "Vec" suffix
    type_name = string(Base.typename(typeof(model_vec)).name)
    model_type = Symbol(type_name[1:end-3])

    model = getproperty(parentmodule(typeof(model_vec)), model_type)

    key_name = get_key_name(model)
    _get_indexer_values(model_vec, key_name)
end

function _get_indexer_values(model_vec::T, key_name) where T <: AbstractModel
    if key_name isa Symbol
        return getproperty(model_vec, key_name)

    elseif key_name isa Vector{Symbol}
        values = [getproperty(model_vec, ii) for ii in key_name]
        return [Tuple(row) for row in zip(values...)]
    else
        error("Invalid key name for model type $model_vec: $key_name")
    end
end

function get_key_name(::Type{M}) where M
    throw(ArgumentError("No unique index name defined for model type $M"))
end

const ADDRESSABLE_TYPES = [AlgebVar, AlgebRes, StateVar, StateRes, ObservedVar]

# Constructor with default empty dictionaries
function ModelAllocation(model_name::Symbol)

    by_type = Dict{AddressableType, Dict{Symbol,Vector{UInt}}}()

    # Initialize empty dictionaries for each addressable type
    for type in ADDRESSABLE_TYPES
        by_type[type()] = Dict{Symbol,Vector{UInt}}()
    end

    ModelAllocation(model_name, by_type, false)
end


"""
Constructor for ModelRetrievedAddresses
"""
function ModelRetrievedAddresses(model_name::Symbol)
    by_type = Dict{AddressableType, Dict{Symbol,Vector{UInt}}}()
    for type in ADDRESSABLE_TYPES
        by_type[type()] = Dict{Symbol,Vector{UInt}}()
    end
    ModelRetrievedAddresses(model_name, by_type)
end


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
    
    # Create indices only for internal variables
    # @kwdef will use empty vectors as defaults for external variables
    indices = NamedTuple(
        Symbol("_", var.name) => am.addresses[(var.address_type, model_name, var.name)]
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
    # Input sanity checks
    device_count > 0 || return
    
    if haskey(am.allocations, model_name)
        throw(ArgumentError("Model $model_name already has partial/complete allocation"))
    end

    if metadata.layout == ContiguousVariables()
        _alloc_contiguous_vars!(am, model_name, metadata.vars, device_count)
        _alloc_contiguous_vars!(am, model_name, metadata.residuals, device_count)
    elseif metadata.layout == ContiguousInstances()
        _alloc_contiguous_instances!(am, model_name, metadata.vars, device_count)
        _alloc_contiguous_instances!(am, model_name, metadata.residuals, device_count)
    else
        throw(ArgumentError("Unsupported layout strategy"))
    end

    am.allocations[model_name].is_complete = true

end

function _alloc_contiguous_vars!(
    am::AddressManager,
    model_name::Symbol,
    allocable::Vector{T},
    device_count::Int,
) where T

    if haskey(am.allocations, model_name)
        by_type = am.allocations[model_name].by_type
    else
        am.allocations[model_name] = ModelAllocation(model_name)
        by_type = am.allocations[model_name].by_type
    end

    # filter out external vars using `is_internal`
    internal_vars = filter(is_internal, allocable)

    for var in internal_vars
        start_idx = get!(am.next_idx, var.address_type, 1)
        range = collect(start_idx:(start_idx + device_count - 1))
        
        am.addresses[(var.address_type, model_name, var.name)] = range
        am.next_idx[var.address_type] = start_idx + device_count
        by_type[var.address_type][var.name] = range
    end

end

"""
Separate implementation for ContiguousInstances layout
"""
function _alloc_contiguous_instances!(
    am::AddressManager,
    model_name::Symbol,
    allocable::Vector{T},
    device_count::Int
) where T

    # filter out external vars using `is_internal`
    internal_vars = filter(is_internal, allocable)

    vars_per_instance = length(internal_vars)
    
    # Initialize start indices for each variable type
    type_start_indices = Dict{AddressableType,Int}()
    for var in internal_vars
        type_start_indices[var.address_type] = get!(am.next_idx, var.address_type, 1)
    end

    if haskey(am.allocations, model_name)
        by_type = am.allocations[model_name].by_type
    else
        am.allocations[model_name] = ModelAllocation(model_name)
        by_type = am.allocations[model_name].by_type
    end
    
    # Allocate all variables for each instance together
    for (var_idx, var) in enumerate(internal_vars)
        start_idx = type_start_indices[var.address_type]
        addr_idx = start_idx + var_idx - 1
        
        am.addresses[(var.address_type, model_name, var.name)] = 
            collect(addr_idx:vars_per_instance:addr_idx + (device_count-1)*vars_per_instance)
            
        # Update next available index for this variable type
        am.next_idx[var.address_type] = start_idx + device_count * vars_per_instance

        by_type[var.address_type][var.name] = 
            am.addresses[(var.address_type, model_name, var.name)]
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
    if haskey(am.allocations, model_name)
        for (_, vars) in am.allocations[model_name].by_type
            if haskey(vars, var)
                return true
            end
        end
    end
    return false
end

"""
Retrieve addresses for external variables and equations for a model
"""
function retrieve_addresses(
    am::AddressManager,
    metadata::ModelMetadata,
    models::NamedTuple
)

    model_name = metadata.name

    retrieved = ModelRetrievedAddresses(model_name)

    for var::ModelVar in metadata.vars
        if is_external(var)
            (; name, address_type,source_model, source_var, indexer) = var

            # get the value of the indexer from the current model
            model_vec = models[model_name]
            local_keys = _get_indexer_values(model_vec, indexer)

            # get all the keys from the source model
            src_keys = get_key(models[source_model])

            # get the 1-based index of the source model key in the source model
            src_indices = findall(x->x in local_keys, src_keys)

            # find the allocation of the source variable
            src_addrs = am.addresses[(address_type, source_model, source_var)]

            # retrieve address
            retrieved.by_type[address_type][name] = src_addrs[src_indices]

        end
    end

    am.retrieved[model_name] = retrieved

    nothing
end


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

    # Test reallocation attempts
    am = AddressManager()
    allocate_model!(am, :Bus, bus_metadata, 5)
    @test_throws ArgumentError allocate_model!(am, :Bus, bus_metadata, 3)
    
end

@testitem "Helper functions in AddressManager" begin
    using Powerful
    using Powerful.Models
    using Powerful.PowerCore
    using PowerFlowData
    using Powerful.PowerCore: _get_indexer_values

    # Load test case
    case = PowerFlowData.parse_network(
        joinpath(pkgdir(Powerful), "cases", "ieee14.raw")
    )

    am = AddressManager();
    ALL_MODELS = MODEL_REGISTRY[].models
    
    models = load_system(case, ALL_MODELS);

    sys = SystemModel(am, models)

    # Test get_key for different model types
    # Bus should have 14 buses
    bus_keys = get_key(sys.models[:Bus])
    @test length(bus_keys) == 14
    @test bus_keys[1] == 1  # IEEE14 starts with bus 1

    # PQ loads
    pq_keys = get_key(sys.models[:PQ])
    @test !isempty(pq_keys)
    @test (2, "1") in pq_keys

    bus_indices_pq = _get_indexer_values(sys.models[:PQ], :i)
    @test all(x -> x in bus_keys, bus_indices_pq)

    # Test error cases
    @test_throws ArgumentError get_key_name(Any)  # Invalid model type
    @test_throws ErrorException _get_indexer_values(sys.models[:Bus], :nonexistent_field)
end


@testitem "Address retrieval for PQ model" begin
    using Powerful
    using Powerful.Models
    using Powerful.PowerCore
    using PowerFlowData
    using Powerful.PowerCore: AlgebVar, StateVar, StateRes, AlgebRes, ObservedVar

    # Load test case
    case = PowerFlowData.parse_network(
        joinpath(pkgdir(Powerful), "cases", "ieee14.raw")
    )

    am = AddressManager()
    ALL_MODELS = MODEL_REGISTRY[].models
    
    models = load_system(case, ALL_MODELS)
    sys = SystemModel(am, models)

    @show ALL_MODELS
    for m in ALL_MODELS
        sym = Base.typename(m).name
        allocate_model!(
            am,
            sym, 
            model_metadata(m), 
            length(sys.models[sym]),
        )
    end

    retrieve_addresses(
        sys.address_manager,
        model_metadata(PQ),
        sys.models
    )

    # Test retrieved addresses structure
    @test haskey(am.retrieved, :PQ)
    
    # Check all addressable types exist
    retrieved_pq = am.retrieved[:PQ].by_type
    @test all(haskey(retrieved_pq, type()) for type in 
        [AlgebVar, StateVar, StateRes, AlgebRes, ObservedVar])

    # PQ should have retrieved bus voltage addresses
    alg_vars = retrieved_pq[AlgebVar()]
    @test haskey(alg_vars, :v)
    @test !isempty(alg_vars[:v])
    
    # The number of retrieved voltage addresses should match number of PQ loads
    pq_count = length(get_key(models[:PQ]))
    @test length(alg_vars[:v]) == pq_count

    # Addresses should be valid (non-zero) UInt values
    @test all(addr > 0 for addr in alg_vars[:v])
    
    # Other types should be empty as PQ only retrieves voltage
    @test isempty(retrieved_pq[StateVar()])
    @test isempty(retrieved_pq[StateRes()])
    @test isempty(retrieved_pq[AlgebRes()])
    @test isempty(retrieved_pq[ObservedVar()])
end