using PowerFlowData
using Powerful.PowerCore: from_raw, PSSE, supports_format


"""
Load raw data for specified model types
"""
function load_system(raw_data::PowerFlowData.Network, model_types::Vector{DataType})
    return Dict(T => from_raw(T, raw_data) for T in model_types)
end

export load_system, from_raw