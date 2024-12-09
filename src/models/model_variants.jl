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
    @show parentmodule(T)
    return Core.eval(parentmodule(T), quote
        Base.@kwdef $struct_expr
    end)
end

function generate_vector_type(::Type{T}) where T
    struct_name = Symbol(nameof(T), "Vec")
    fields = fieldnames(T)
    
    # Get field information from the original type definition
    type_def = Base.unwrap_unionall(T)
    field_types = type_def.types
    
    # Create vectorized field expressions
    # TODO: bug here: Union and InlineStrings are not handled correctly
    field_exprs = [:($(fields[i])::Vector{$(Symbol(field_types[i]))}) for i in eachindex(fields)]
    
    # Get type parameters and supertype
    type_params = if T isa UnionAll
        [T.var.name]
    else
        T.parameters
    end
    
    # Extract the supertype
    supertype_expr = if T isa UnionAll
        super = supertype(Base.unwrap_unionall(T))
        if super !== Any
            super  # Return the supertype directly
        else
            nothing
        end
    else
        super = supertype(T)
        if super !== Any
            super  # Return the supertype directly
        else
            nothing
        end
    end
    
    # Construct the type expression with parameters
    param_expr = if !isempty(type_params)
        if supertype_expr === nothing
            Expr(:curly, struct_name, type_params...)
        else
            # Create the proper type constraint expression
            Expr(:(<:), 
                Expr(:curly, struct_name, type_params...),
                Expr(:curly, nameof(supertype_expr), type_params...)
            )
        end
    else
        supertype_expr === nothing ? struct_name : Expr(:(<:), struct_name, supertype_expr)
    end
    

    # Generate struct definition
    struct_expr = Expr(:struct, true,
        param_expr,
        Expr(:block, field_exprs...)
    )

    # Evaluate in the same module as the original type
    return Core.eval(parentmodule(T), quote
        using InlineStrings
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