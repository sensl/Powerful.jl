"""
Trait system for data format conversions
"""

# Trait types
struct FormatSupport{F} end
struct NoFormatSupport end

"""
    supports_format(::Type{M}, format::Type{F}) where {M,F}

Returns the format support trait for a given model type and format.
Default implementation returns NoFormatSupport.
"""
supports_format(::Type, ::Type) = NoFormatSupport()

"""
    from_raw(::Type{M}, data, trait)

Convert raw data to model instance based on trait dispatch.
Must be implemented for specific model types and formats.
"""
function from_raw end

# Default fallback with informative error
function from_raw(::Type{M}, data, ::NoFormatSupport) where M
    throw(ArgumentError(
        "No conversion implemented for model type $M. " *
        "Please implement `supports_format` and `from_raw` for this type."
    ))
end

"""
Check if a model type supports conversion from a format
"""
is_format_supported(::Type{M}, ::Type{F}) where {M,F} = !(supports_format(M, F) isa NoFormatSupport)

"""
Helper to validate raw data before conversion
"""
function validate_raw(::Type{M}, data, format::Type{F}) where {M,F}
    if !is_format_supported(M, format)
        throw(ArgumentError("Model type $M does not support conversion from format $F"))
    end
    # TODO: Additional validation logic...
end

export FormatSupport
export supports_format, from_raw, is_format_supported, validate_raw