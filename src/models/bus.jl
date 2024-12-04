using Powerful.PowerCore

struct Bus <: PowerCore.AbstractModel
    id::Int
end

const BUS_REQUIREMENTS = (
    VarRequirement(:theta, Algebraic()),
    VarRequirement(:v, Algebraic()),
)

const BUS_OUTPUT_VARS = (:theta, :v)

struct BusMetadata{T<:LayoutStrategy} <: ModelMetadata{T}
    internal_vars::NTuple{2, VarRequirement}
    # no external vars
    output_vars::NTuple{2, Symbol}
end

function BusMetadata{T}() where T <: LayoutStrategy
    return BusMetadata{T}(BUS_REQUIREMENTS, BUS_OUTPUT_VARS)
end

# Will error if not implemented
function get_var_requirements(::Type{Bus})
    return BUS_REQUIREMENTS
end

# Will error if not implemented
function compute_residuals!(
    bus::Bus,
    addresses::AddressManager,
    x::AbstractVector,
    residuals::AbstractVector
)
    # Implementation...
end

export Bus, BusMetadata
# export get_var_requirements, compute_residuals!