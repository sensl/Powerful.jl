module Models
using DocStringExtensions
using PowerFlowData
using InlineStrings
using TestItems
using StructArrays
using PrecompileTools

using Powerful.PowerCore

include("soa_interface.jl")
include("model_traits.jl")
include("model_registry.jl")
include("model_variants.jl")

include("bus/bus.jl")
include("pq.jl")


# @setup_workload begin
#     # Replace both the execution and precompilation blocks with:

#     @compile_workload begin
#     end
# end
        for model in MODEL_REGISTRY[].models
            generate_numerical_type(model)
            generate_vector_type(model)
        end

end # module