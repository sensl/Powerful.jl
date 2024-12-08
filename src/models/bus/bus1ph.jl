export Bus1Ph, Bus1PhVec, Bus1PhNumerical

@vectorize_model mutable struct Bus1Ph{Tv} <: AbstractBus{Tv}
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

@register_model Bus1Ph

const BUS1PH_VARS = [
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

const BUS1PH_OUTPUT_VARS = [:theta, :v]

"""
Get metadata for a model type Bus1Ph
"""
function model_metadata(::Type{Bus1Ph}; layout::LayoutStrategy=ContiguousVariables())
    ModelMetadata(
        name = :Bus1Ph,
        vars = BUS1PH_VARS,
        output_vars = BUS1PH_OUTPUT_VARS,
        layout = layout
    )
end


### === Format Support === ###

supports_format(::Type{Bus1Ph}, ::Type{PSSE}) = FormatSupport{PSSE}()

function parse_model(model::Type{Bus1Ph}, raw, ::FormatSupport{PSSE})
    buses = raw.buses
    mod = parentmodule(model)

    # Note: one must use `nameof` to get the symbol for the type name
    #   Otherwise, `model` will be the fully qualified name, and this will fail
    vec_type = getfield(mod, Symbol(nameof(model), "Vec"))

    return vec_type(
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


@testitem "Bus1Ph" begin
    using PowerFlowData
    using Powerful
    using Powerful.Models
    using Powerful.PowerCore
    using StructArrays

    case = PowerFlowData.parse_network(
        joinpath(pkgdir(Powerful), "cases", "ieee14.raw")
    )

    bus1ph = parse_model(Bus1Ph, case)
    # @test bus1ph isa Bus1PhVec

    # struct_array = to_struct_array(bus1ph)
    # @test struct_array isa StructArray
end
