abstract type VarType end
struct State <: VarType end
struct Algebraic <: VarType end
struct Observed <: VarType end

abstract type ResidualType end
struct PartialResidual <: ResidualType end
struct FullResidual <: ResidualType end