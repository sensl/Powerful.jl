# Global registry to store numerical fields for each type
const _NUMERICAL_FIELDS_REGISTRY = Dict{Symbol, Vector{Symbol}}()

"""
Register numerical fields for a model type
"""
function register_numerical_fields(::Type{T}, fields::Symbol...) where T
    _NUMERICAL_FIELDS_REGISTRY[nameof(T)] = collect(fields)
end

"""
Generate numerical variant of a type using registered fields
"""
function generate_numerical_type(::Type{T}) where T
    model_name = nameof(T)
    numerical_fields = get(_NUMERICAL_FIELDS_REGISTRY, model_name, Symbol[])
    isempty(numerical_fields) && error("No numerical fields registered for $model_name")
    
    # Create name for numerical struct
    struct_name = Symbol(model_name, "Num")
    
    # Get field information from the original type definition
    type_def = Base.unwrap_unionall(T)
    fields = fieldnames(T)
    field_types = type_def.types
    
    # Filter numerical fields and preserve their types
    field_indices = findall(f -> f in numerical_fields, collect(fields))
    field_exprs = [:($(fields[i])::$(field_types[i])) for i in field_indices]
    
    # Get type parameters
    type_params = if T isa UnionAll
        [T.var.name]  # e.g., :Tv from Bus{Tv}
    else
        T.parameters
    end
    
    param_expr = if !isempty(type_params)
        Expr(:curly, struct_name, type_params...)
    else
        struct_name
    end
    
    # Generate struct definition
    struct_expr = Expr(:struct, true,
        param_expr,
        Expr(:block, field_exprs...)
    )
    
    # Evaluate the new type
    return Core.eval(parentmodule(T), quote
        Base.@kwdef $struct_expr
    end)
end

"""
Create vectorized version of any struct
"""
function generate_vector_type(::Type{T}) where T
    struct_name = Symbol(nameof(T), "Vec")
    fields = fieldnames(T)
    
    # Get field information from the original type definition
    type_def = Base.unwrap_unionall(T)
    field_types = type_def.types
    
    # Create vectorized field expressions
    field_exprs = [:($(fields[i])::Vector{$(field_types[i])}) for i in 1:length(fields)]
    
    # Get type parameters
    type_params = if T isa UnionAll
        [T.var.name]  # e.g., :Tv from Bus{Tv}
    else
        T.parameters
    end
    
    param_expr = if !isempty(type_params)
        Expr(:curly, struct_name, type_params...)
    else
        struct_name
    end
    
    # Generate struct definition
    struct_expr = Expr(:struct, true,
        param_expr,
        Expr(:block, field_exprs...)
    )
    
    @show struct_expr
    # Evaluate in the same module as the original type
    return Core.eval(parentmodule(T), quote
        Base.@kwdef $struct_expr
    end)
end

"""
Generate all variants (Numerical and Vectorized) for registered models
"""
function generate_model_variants(models::Vector{DataType})
    variants = Dict{Symbol, Dict{Symbol, DataType}}()
    
    for model in models
        model_name = nameof(model)
        
        # Generate numerical variant if fields are registered
        if haskey(_NUMERICAL_FIELDS_REGISTRY, model_name)
            num_type = generate_numerical_type(model)
            vec_type = generate_vector_type(model)
            num_vec_type = generate_vector_type(num_type)
            
            variants[model_name] = Dict(
                :original => model,
                :numerical => num_type,
                :vector => vec_type,
                :numerical_vector => num_vec_type
            )
        end
    end
    
    return variants
end