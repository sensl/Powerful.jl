"""
Test trait implementation.
"""

using Test
using SimpleTraits

using Powerful: NumParam
using Powerful: HasV

@testset "test traits" begin

@test istrait(HasV{NumParam{Float64}})

end