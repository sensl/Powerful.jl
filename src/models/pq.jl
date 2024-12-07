using Powerful.PowerCore
import Powerful.PowerCore: supports_format, parse_model

abstract type AbstractLoad{Tv} <: AbstractModel end

@vectorize_model mutable struct PQ{Tv} <: AbstractLoad{Tv}
    i::Int32
    id::String3
    status::Bool
    area::Int16
    zone::Int16
    pl::Tv
    ql::Tv
    ip::Tv
    iq::Tv
    yp::Tv
    yq::Tv
    owner::Int16
    scale::Union{Bool,Missing}
    intrpt::Union{Bool,Missing}
end

const PQ_VARS = [
    ModelVar(
        :theta,
        Algeb(),
        Bus1Ph,
        :theta,
        description="Active power injection",
        units="pu",
    ),
    ModelVar(
        :v,
        Algeb(),
        Bus1Ph,
        :v,
        description="Voltage magnitude", 
        units="pu",
    ),

]

const PQ_OUTPUT_VARS = [:p, :q]

"""
Get metadata for PQ load model
"""
function model_metadata(::Type{PQ}; layout::LayoutStrategy=ContiguousVariables())
    ModelMetadata(
        name = :PQ,
        vars = PQ_VARS,
        output_vars = PQ_OUTPUT_VARS,
        layout = layout
    )
end
