
"""
    ModelVar(name::Symbol, var_type::VarType; kwargs...)

Constructor for internal variables
"""
function ModelVar(
    name::Symbol,
    var_type::VT;
    description::String = "",
    units::String = "",
    bounds::Union{Nothing, Tuple{Float64, Float64}} = nothing
) where {VT<:VarType}
    props = PropertyDict()
    
    # Add properties if provided
    !isempty(description) && (props[Description] = Description(description))
    !isempty(units) && (props[Units] = Units(units))
    !isnothing(bounds) && (props[Bounds] = Bounds(bounds[1], bounds[2]))
    
    ModelVar{Internal, VT, Nothing, PropertyDict}(
        name,
        var_type,
        nothing,
        nothing,
        props
    )
end

"""
    ModelVar(name::Symbol, source_model::Type, source_var::Symbol; kwargs...)

Constructor for external variables
"""
function ModelVar(
    name::Symbol,
    source_model::Type,
    source_var::Symbol;
    description::String = "",
    units::String = ""
)
    props = PropertyDict()
    
    # Add properties if provided
    !isempty(description) && (props[Description] = Description(description))
    !isempty(units) && (props[Units] = Units(units))
    
    ModelVar{External, Nothing, typeof(source_model), PropertyDict}(
        name,
        nothing,
        source_model,
        source_var,
        props
    )
end

# === Helper Functions === #
is_internal(::ModelVar{Internal, VT, SM, P}) where {VT, SM, P} = true
is_internal(::ModelVar{External, VT, SM, P}) where {VT, SM, P} = false
is_external(v::ModelVar) = !is_internal(v)

# Property access helpers
function get_property(var::ModelVar, ::Type{T}) where {T<:VarProperty}
    get(var.properties, T, nothing)
end

function get_description(var::ModelVar)::Union{String, Nothing}
    desc = get_property(var, Description)
    isnothing(desc) ? nothing : desc.value
end

function get_units(var::ModelVar)::Union{String, Nothing}
    units = get_property(var, Units)
    isnothing(units) ? nothing : units.value
end

function get_bounds(var::ModelVar)::Union{Tuple{Float64, Float64}, Nothing}
    bounds = get_property(var, Bounds)
    isnothing(bounds) ? nothing : (bounds.min, bounds.max)
end

# Helper functions for metadata
function internal_vars(metadata::ModelMetadata)
    filter(is_internal, metadata.vars)
end

function external_vars(metadata::ModelMetadata)
    filter(is_external, metadata.vars)
end