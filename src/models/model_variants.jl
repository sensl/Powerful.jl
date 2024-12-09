# Global registry to store numerical fields for each type
const _NUMERICAL_FIELDS_REGISTRY = Dict{Symbol, Vector{Symbol}}()

"""
$(SIGNATURES)

Register numerical fields for a model type
"""
function register_numerical_fields(::Type{T}, fields::Symbol...) where T
    _NUMERICAL_FIELDS_REGISTRY[nameof(T)] = collect(fields)
end

"""
$(SIGNATURES)

Helper function to extract and validate type information
"""
function _extract_type_info(::Type{T}) where T
    fields = fieldnames(T)
    field_types = Base.unwrap_unionall(T).types
    is_mutable = ismutable(T)
    return fields, field_types, is_mutable
end

"""
$(SIGNATURES)

Generate numerical variant of a type using registered fields
"""
function generate_numerical_type(::Type{T}) where T
    model_name = nameof(T)
    numerical_fields = get(_NUMERICAL_FIELDS_REGISTRY, model_name, Symbol[])
    isempty(numerical_fields) && error("No numerical fields registered for $model_name")
    
    # Get field information from the original type definition
    fields, field_types, is_mutable = _extract_type_info(T)

    # Filter fields that are numerical
    num_idx = [i for i in eachindex(fields) if fields[i] in numerical_fields]
    fields_filtered = [fields[i] for i in num_idx]
    field_types_filtered = [field_types[i] for i in num_idx]

    field_exprs = _find_field_exprs(fields_filtered, field_types_filtered)
    param_expr = _find_param_expr(T; suffix = :Num)

    # Generate struct definition
    struct_expr = Expr(:struct, is_mutable,
        param_expr,
        Expr(:block, field_exprs...)
    )
    
    # Evaluate the new type
    return Core.eval(parentmodule(T), quote
        Base.@kwdef $struct_expr
    end)
end

"""
$(SIGNATURES)

Generate vectorized variant of a type
"""
function generate_vector_type(::Type{T}) where T

    # Get field information from the original type definition
    fields, field_types, is_mutable = _extract_type_info(T)
    
    field_exprs = _find_field_exprs(fields, field_types)
    param_expr = _find_param_expr(T; suffix = :Vec)

    # Generate struct definition
    struct_expr = Expr(:struct, is_mutable,
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
$(SIGNATURES)

Helper function for finding the field expressions for a type
"""
function _find_field_exprs(fields, field_types)
    # Create vectorized field expressions
    field_exprs = [
        begin
            field_type = field_types[i]
            type_expr = if field_type isa Union
                # Handle Union types using Base.uniontypes
                union_types = map(t -> Symbol(split(string(t), ".")[end]), Base.uniontypes(field_type))
                Expr(:curly, :Union, union_types...)
            else
                # Handle simple types, stripping module qualification
                Symbol(split(string(field_type), ".")[end])
            end
            :($(fields[i])::Vector{$type_expr})
        end for i in eachindex(fields)
    ]
end

"""
$(SIGNATURES)

Helper function for finding the supertype information for a type
"""
function _find_param_expr(::Type{T}; suffix::Symbol) where T
    struct_name = Symbol(nameof(T), suffix)

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

    return param_expr
end

"""
$(SIGNATURES)

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