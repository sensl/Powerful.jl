using PowerFlowData
using Powerful.PowerCore: parse_model, PSSE, supports_format


"""
Load raw data for specified model types
"""
function load_system(raw_data::PowerFlowData.Network, model_types::Vector{DataType})
    return Dict(T => parse_model(T, raw_data) for T in model_types)
end

export load_system, parse_model