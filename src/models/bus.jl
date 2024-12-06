using Powerful.PowerCore
import Powerful.PowerCore: supports_format, from_raw

@vectorize_model mutable struct Bus{Tv} <: AbstractModel
    i::Int32
    name::String15
    basekv::Tv
    ide::Int8
    area::Int16
    zone::Int16
    owner::Int16
    vm::Tv
    va::Tv
    nvhi::Tv
    nvlo::Tv
    evhi::Tv
    evlo::Tv
end

export Bus, BusVec, BusNumerical

const BUS_VARS = [
    ModelVar(:theta, Algeb(),
        description="Bus voltage angle",
        units="rad",
        bounds=(-Inf, Inf)
    ),
    ModelVar(:v, Algeb(),
        description="Bus voltage magnitude",
        units="pu",
        bounds=(0.0, 2.0)
    )
]

const BUS_OUTPUT_VARS = [:theta, :v]

"""
Get metadata for a model type Bus
"""
function model_metadata(::Type{Bus}; layout::LayoutStrategy=ContiguousVariables())
    ModelMetadata(
        name = :Bus,
        vars = BUS_VARS,
        output_vars = BUS_OUTPUT_VARS,
        layout = layout
    )
end

### === Format Support === ###

supports_format(::Type{Bus}, ::Type{PSSE}) = FormatSupport{PSSE}()

function from_raw(::Type{Bus}, raw, ::FormatSupport{PSSE})
    buses = raw.buses
    return BusVec(
        i = buses.i,
        name = buses.name,
        basekv = buses.basekv,
        ide = buses.ide,
        area = buses.area,
        zone = buses.zone,
        owner = buses.owner,
        vm = buses.vm,
        va = buses.va,
        nvhi = buses.nvhi,
        nvlo = buses.nvlo,
        evhi = buses.evhi,
        evlo = buses.evlo,
    )
end


@testitem "Bus" begin
    using PowerFlowData
    using Powerful
    using Powerful.Models
    using Powerful.PowerCore
    using StructArrays

    case = PowerFlowData.parse_network(joinpath(@__DIR__, "..", "..", "cases", "ieee14.raw"))
    bus = load_model(Bus, case)
    @test bus isa BusVec

    struct_array = to_struct_array(bus)
    @test struct_array isa StructArray
end
