"""
    model_metadata(::Type{M}; layout::LayoutStrategy=ContiguousVariables()) where {M<:AbstractModel}

Get metadata for a model type. All models must implement this method.

# Arguments
- Model type
- layout: Optional layout strategy for address allocation

# Returns
- ModelMetadata object
"""
function model_metadata(::Type; layout::LayoutStrategy=ContiguousVariables())
    error("No metadata defined for model type $M")
end