
"""
Internal numerical parameter.
"""
struct NumParam{T}
    v::T
    vin::T
end

@traitimpl HasV{NumParam}
