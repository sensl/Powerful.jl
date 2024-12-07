export @vectorize_model

"""
Macro to vectorize a model struct.

Generates two structs:
- `Vec` containing all fields of the model, vectorized
- `VecPu` containing only numerical fields of the model, vectorized
"""
macro vectorize_model(def)
    # Extract struct information
    struct_info = _parse_struct(def)
    
    # Generate the vectorized structs
    vec_struct = _make_vector_struct_expr(struct_info, :full, "Vec")
    numerical_struct = _make_vector_struct_expr(struct_info, :numerical, "Numerical", false)
    
    return esc(quote 
        Base.@kwdef $def
        Base.@kwdef $vec_struct
        Base.@kwdef $numerical_struct
    end)
end

function _parse_struct(def)
    @assert def.head == :struct "Expected a struct definition"
    
    # Extract name, type parameters, where constraints, and supertype
    struct_def = def.args[2]
    struct_name, type_params, where_constraints, supertype = if struct_def isa Expr
        if struct_def.head == :where
            base = struct_def.args[1]
            constraints = struct_def.args[2:end]
            if base.head == :<:
                _parse_type_with_super(base.args[1], base.args[2], constraints)
            else
                _parse_type(base, :Any, constraints)
            end
        elseif struct_def.head == :<:
            _parse_type_with_super(struct_def.args[1], struct_def.args[2], [])
        else
            _parse_type(struct_def, :Any, [])
        end
    else
        struct_def, [], [], :Any
    end
    
    fields = filter(f -> f isa Expr && f.head == :(::), def.args[3].args)
    
    return (
        name = struct_name,
        type_params = type_params,
        where_constraints = where_constraints,
        supertype = supertype,
        is_mutable = def.args[1],
        fields = fields
    )
end

function _parse_type(base, supertype, constraints)
    if base isa Expr && base.head == :curly
        base.args[1], base.args[2:end], constraints, supertype
    else
        base, [], constraints, supertype
    end
end

function _parse_type_with_super(base, supertype, constraints)
    if base isa Expr && base.head == :curly
        base.args[1], base.args[2:end], constraints, supertype
    else
        base, [], constraints, supertype
    end
end

"""
Make a vector struct expression from a parsed struct definition.

This function has the ability to filter fields based on the kind of vector
struct being made, either `:full` or `:numerical`.

For the numerical version, only these concrete non-numerical types are filtered.
Parametric types that cannot be determined at compile time are retained.

TODO: This function may be an overkill if the per-unit struct retains all the
fields. In that case, this function could be simplified.
"""
function _make_vector_struct_expr(info, kind::Symbol, suffix::String, vectorize::Bool=true,
    supertype::DataType=AbstractModel)
    @assert kind in (:full, :numerical)
    
    struct_name = Symbol(info.name, suffix)
    
    # Handle fields, keeping parameterized types in numerical version
    fields = map(info.fields) do field
        field_name = field.args[1]
        field_type = field.args[2]
        
        # For numerical version, we rely on where constraints instead of runtime checks
        if kind == :numerical && field_type isa Symbol && !(field_type in info.type_params)
            # Only filter concrete types we can check at compile time
            try
                if !(eval(field_type) <: Number)
                    return nothing
                end
            catch
                # If we can't evaluate the type, skip it
                return nothing
            end
        end

        final_type = vectorize ? :(Vector{$field_type}) : field_type
        :($(field_name)::$final_type)
    end
    
    fields = filter(!isnothing, fields)
    
    # Construct type expression with parameters and where constraints
    type_expr = if !isempty(info.type_params)
        type_with_params = Expr(:curly, struct_name, info.type_params...)
        if !isempty(info.where_constraints)
            Expr(:where, :($type_with_params <: $(info.supertype)), info.where_constraints...)
        else
            :($type_with_params <: $(info.supertype))
        end
    else
        :($struct_name <: $(info.supertype))
    end
    
    Expr(:struct, info.is_mutable, type_expr, Expr(:block, fields...))
end

