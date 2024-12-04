import Base: iterate, length

"""
Helper functions to work with components
"""
function component_types(sys::SystemModel)
    # Get the concrete type of each component
    map(typeof, sys.components)
end

# Helper type with explicit tuple type
struct ComponentIterator{T<:Tuple, S<:SystemModel{T}}
    system::S
    n::Int  # Current iteration number
end

Base.length(sys::SystemModel) = length(sys.components)

# Type-stable iteration
function Base.iterate(iter::ComponentIterator{T, S}) where {T, S}
    # Now compiler knows exact tuple type T
    if iter.n > fieldcount(T)  # More precise than length check
        return nothing
    end
    
    # Compiler can now determine exact type of T.parameters[iter.n]
    return (iter.system.components[iter.n], 
            ComponentIterator{T, S}(iter.system, iter.n + 1))
end

# Make SystemModel iterable using our type-stable iterator
Base.iterate(sys::SystemModel{T}) where {T} = 
    iterate(ComponentIterator{T, typeof(sys)}(sys, 1))


# This is the corrected method
Base.iterate(sys::SystemModel{T}, state::ComponentIterator{T,S}) where {T,S} = 
    iterate(state)
