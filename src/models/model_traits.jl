import Base: length
export model_metadata

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


"""
    length(model::AbstractModel)

Returns the number of devices represented by this model by checking the length of 
any of its data fields. All fields in a model must have equal lengths.
"""
function length(model::AbstractModel)
    fields = fieldnames(typeof(model))
    isempty(fields) && return 0
    return length(getfield(model, first(fields)))
end
