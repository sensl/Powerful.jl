"""
$(SIGNATURES)

Required interface that all models must implement
"""
function get_var_requirements(::Type{<:AbstractModel})
    throw(error("get_var_requirements must be implemented for concrete model types"))
end

function compute_residuals!(
    model::AbstractModel,
    addresses::AddressManager,
    x::AbstractVector,
    residuals::AbstractVector
)
    throw(error("compute_residuals! must be implemented for $(typeof(model))"))
end

# Optional: Add function to verify implementation at compile time
function verify_model_implementation(::Type{T}) where {T<:AbstractModel}
    # Check if methods are implemented
    hasmethod(get_var_requirements, (Type{T},)) || 
        error("$(T) must implement get_var_requirements")
    hasmethod(compute_residuals!, (T, AddressManager, AbstractVector, AbstractVector)) || 
        error("$(T) must implement compute_residuals!")
end
