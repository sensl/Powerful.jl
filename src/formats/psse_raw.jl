using PowerFlowData
using Powerful.PowerCore: from_raw, PSSE, supports_format

"""
Load components for any model type that supports the format
"""
function load_model(::Type{M}, raw_data, ::Type{F}=PSSE) where {M,F}
    # Check format support
    trait = supports_format(M, F)

    # Convert components
    return from_raw(M, raw_data, trait)
end

"""
Load raw data for specified model types
"""
function load_system(raw_data::PowerFlowData.Network, model_types::Vector{DataType})
    return Dict(T => load_model(T, raw_data) for T in model_types)
end

export load_model, load_system, from_raw