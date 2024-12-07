"""
Central registry for model types and their metadata
"""
struct ModelRegistry{T<:Tuple}
    models::T
end

# Empty registry with type parameter
const MODEL_REGISTRY = Ref{ModelRegistry}(ModelRegistry(()))

"""
Type-stable helper to add a model type to registry tuple
"""
function _add_model(registry::ModelRegistry{T}, ::Type{M}) where {T, M<:AbstractModel}
    # Create new tuple type with added model
    new_models = (registry.models..., M)
    ModelRegistry{typeof(new_models)}(new_models)
end

"""
Macro to register a model type. Updates MODEL_REGISTRY.
"""
macro register_model(model_type::Symbol)
    quote
        MODEL_REGISTRY[] = _add_model(MODEL_REGISTRY[], $(esc(model_type)))
    end
end

# Type-stable registry queries
"""Get all registered model types"""
get_registered_models(registry::ModelRegistry{T}) where T = registry.models

"""Get model type from registry by name"""
function get_model_type(registry::ModelRegistry{T}, name::Symbol) where T
    for M in registry.models
        if nameof(M) === name
            return M
        end
    end
    error("Model $name not found in registry")
end

export @register_model
export MODEL_REGISTRY
export get_registered_models, get_model_type


@testitem "ModelRegistry" begin
    using Powerful.PowerCore
    using Powerful.Models

    @testset "get_registered_models" begin
        @test Bus1Ph in get_registered_models(MODEL_REGISTRY[])
        @test get_model_type(MODEL_REGISTRY[], :Bus1Ph) == Bus1Ph

        struct TestModel <: AbstractModel end
        @register_model TestModel
        @test TestModel in get_registered_models(MODEL_REGISTRY[])
        @test get_model_type(MODEL_REGISTRY[], :TestModel) == TestModel
    end
end
