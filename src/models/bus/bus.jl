using Powerful.PowerCore
import Powerful.PowerCore: supports_format, parse_model

abstract type AbstractBus{Tv} <: AbstractModel end

include("bus1ph.jl")
