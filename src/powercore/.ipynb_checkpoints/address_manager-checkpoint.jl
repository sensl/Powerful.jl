

"""
Allocate addresses based on model's layout strategy
"""
function allocate_model!(
    am::AddressManager,
    model_type::Symbol,
    metadata::Type{ModelMetadata{ContiguousVariables}},
    instance_count::Int
)
    # Allocate variables contiguously
    for req in metadata.requirements
        start_idx = get!(am.next_idx, req.var_type, 1)
        range = start_idx:(start_idx + instance_count - 1)
        
        am.addresses[(req.var_type, model_type, req.name)] = range
        am.next_idx[req.var_type] = start_idx + instance_count
    end
end

"""
Separate implementation for ContiguousInstances layout
"""
function allocate_model!(
    am::AddressManager,
    model_type::Symbol,
    metadata::Type{ModelMetadata{ContiguousInstances}},
    instance_count::Int
)
    vars_per_instance = length(metadata.requirements)
    var_type = first(metadata.requirements).var_type  # Assuming same type for all vars
    
    start_idx = get!(am.next_idx, var_type, 1)
    
    # Allocate all variables for each instance together
    for i in 1:instance_count
        instance_start = start_idx + (i-1) * vars_per_instance
        
        for (var_idx, req) in enumerate(metadata.requirements)
            addr_idx = instance_start + (var_idx-1)
            am.addresses[(req.var_type, model_type, req.name)] = 
                collect(addr_idx:vars_per_instance:addr_idx + instance_count - 1)
        end
    end
    
    am.next_idx[var_type] = start_idx + instance_count * vars_per_instance
end