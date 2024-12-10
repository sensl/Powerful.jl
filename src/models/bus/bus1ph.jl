using InlineStrings

export Bus, BusVec, BusNum

Base.@kwdef mutable struct Bus{Tv} <: AbstractBus{Tv}
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

@register_model Bus

register_numerical_fields(Bus, :basekv, :vm, :va, :nvhi, :nvlo, :evhi, :evlo)

# Define Bus model variables
const BUS1PH_VARS = [
    ModelVar(
        :theta, 
        AlgebVar(),
        description="Bus voltage angle",
        units="rad",
        bounds=(-Inf, Inf)
    ),

    ModelVar(
        :v, 
        AlgebVar(),
        description="Bus voltage magnitude",
        units="pu",
        bounds=(0.0, 2.0)
    )
]

const BUS1PH_OUTPUT_VARS = [:theta, :v]

# Define residual variables similar to model variables
const BUS1PH_RESIDUALS = [
    ModelResidual(
        :p_balance,
        AlgebRes(),
        SharedRes();
        description="Active power balance equation",
    ),
    ModelResidual(
        :q_balance, 
        AlgebRes(),
        SharedRes();
        description="Reactive power balance equation",
    )
]

"""
Get metadata for a model type Bus
"""
function model_metadata(::Type{Bus}; layout::LayoutStrategy=ContiguousVariables())
    ModelMetadata(
        name = :Bus,
        vars = BUS1PH_VARS,
        output_vars = BUS1PH_OUTPUT_VARS,
        residuals = BUS1PH_RESIDUALS,
        layout = layout
    )
end


### === Format Support === ###

supports_format(::Type{Bus}, ::Type{PSSE}) = FormatSupport{PSSE}()

function parse_model(model::Type{Bus}, raw, ::FormatSupport{PSSE})
    buses = raw.buses
    mod = parentmodule(model)

    # Note: one must use `nameof` to get the symbol for the type name
    #   Otherwise, `model` will be the fully qualified name, and this will fail
    vec_type = getfield(mod, Symbol(nameof(model), "Vec"))

    return vec_type(;
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

    case = PowerFlowData.parse_network(
        joinpath(pkgdir(Powerful), "cases", "ieee14.raw")
    )

    bus = parse_model(Bus, case)
    # @test bus isa BusVec

    # struct_array = to_struct_array(bus)
    # @test struct_array isa StructArray
end
