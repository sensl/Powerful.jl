
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
    var_type::VT,
    source_model::T,
    source_var::Symbol;
    description::String = "",
    units::String = ""
) where {T<:Type{<:AbstractModel}, VT<:VarType}
    props = PropertyDict()
    
    # Add properties if provided
    !isempty(description) && (props[Description] = Description(description))
    !isempty(units) && (props[Units] = Units(units))
    
    ModelVar{External, VT, T, PropertyDict}(
        name,
        var_type,
        source_model,
        source_var,
        props
    )
end


"""
Constructor for internal residual equations
"""
function ModelResidual(
    name::Symbol,
    residual_type::RT;
    description::String = ""
) where {RT<:ResidualType}
    ModelResidual{Internal, RT, Nothing, Nothing, Nothing}(
        name,
        residual_type,
        nothing,
        nothing,
        nothing,
        description
    )
end

"""
Constructor for external residual equations
"""
function ModelResidual(
    name::Symbol,
    residual_type::RT,
    source_model::SM,
    source_residual::SR;
    indexer::IN,
    description::String = ""
) where {SM<:Type{<:AbstractModel}, RT<:ResidualType, SR, IN}
    ModelResidual{External, RT, SM, SR, IN}(
        name,
        residual_type,
        source_model,
        source_residual,
        indexer,
        description
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