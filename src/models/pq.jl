using Powerful.PowerCore
import Powerful.PowerCore: supports_format, parse_model

export PQ, PQVec, PQNumerical

mutable struct PQ{Tv} <: AbstractLoad{Tv}
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

@register_model PQ

register_numerical_fields(PQ, :pl, :ql, :ip, :iq, :yp, :yq)

const PQ_VARS = [
    ModelVar(
        :theta,
        Algeb(),
        Bus,
        :theta,
        description="Active power injection",
        units="pu",
    ),
    ModelVar(
        :v,
        Algeb(),
        Bus,
        :v,
        description="Voltage magnitude", 
        units="pu",
    ),

]

const PQ_OUTPUT_VARS = []

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

### === Model Format Adapters ===

supports_format(::Type{PQ}, ::Type{PSSE}) = FormatSupport{PSSE}()

function parse_model(model::Type{PQ}, raw, ::FormatSupport{PSSE})
    loads = raw.loads
    mod = parentmodule(model)
    vec_type = getfield(mod, Symbol(nameof(model), "Vec"))

    return vec_type(
        i = loads.i,
        id = loads.id,
        status = loads.status,
        area = loads.area,
        zone = loads.zone,
        pl = loads.pl,
        ql = loads.ql,
        ip = loads.ip,
        iq = loads.iq,
        yp = loads.yp,
        yq = loads.yq,
        owner = loads.owner,
        scale = loads.scale,
        intrpt = loads.intrpt,
    )
end


### === Begin Tests === ###

@testitem "PQ" begin
    using PowerFlowData
    using Powerful
    using Powerful.Models
    using Powerful.PowerCore

    case = PowerFlowData.parse_network(
        joinpath(pkgdir(Powerful), "cases", "ieee14.raw")
    )

    pq = parse_model(PQ, case)
    @test pq isa PQVec
end
