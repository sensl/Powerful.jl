
"""
Differential-Algebraic Equations
"""
struct DAE{Tf<:AbstractFloat}
    m::Int
    g::Vector{Tf}

end
