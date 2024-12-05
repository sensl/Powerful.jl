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

export Bus, BusVec, BusVecPu

const BUS_VAR_SPECS = (
    VarSpec(:theta, Algebraic()),
    VarSpec(:v, Algebraic()),
)

const BUS_OUTPUT_VARS = (:theta, :v)

struct BusMetadata{T<:LayoutStrategy} <: ModelMetadata{T}
    internal_vars::NTuple{2, VarSpec}
    # no external vars
    output_vars::NTuple{2, Symbol}
end

function BusMetadata{T}() where T <: LayoutStrategy
    return BusMetadata{T}(BUS_VAR_SPECS, BUS_OUTPUT_VARS)
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