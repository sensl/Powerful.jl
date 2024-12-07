using Powerful.PowerCore
import Powerful.PowerCore: supports_format, from_raw

abstract type AbstractBus{Tv} <: AbstractModel end

include("bus1ph.jl")
