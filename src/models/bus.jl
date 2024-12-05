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

const BUS_VAR_SPECS = (
    VarSpec(:theta, Algebraic(), OwnVar()),
    VarSpec(:v, Algebraic(), OwnVar()),
)

const BUS_OUTPUT_VARS = (:theta, :v)

struct BusMetadata{T, Nv, No} <: ModelMetadata{T}
    var_specs::NTuple{Nv, VarSpec}
    output_vars::NTuple{No, Symbol}
end

function BusMetadata{T}() where T <: LayoutStrategy
    return BusMetadata{T, length(BUS_VAR_SPECS), length(BUS_OUTPUT_VARS)}(BUS_VAR_SPECS, BUS_OUTPUT_VARS)
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


### === Export Section === ###
export Bus, BusMetadata

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
