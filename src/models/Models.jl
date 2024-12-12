module Models
using DocStringExtensions
using PowerFlowData
using InlineStrings
using TestItems
using StructArrays
using PrecompileTools

using Powerful.PowerCore
import Powerful.PowerCore: get_key_name

include("soa_interface.jl")
include("model_traits.jl")
include("model_registry.jl")
include("model_variants.jl")
include("model_access.jl")


include("bus/bus.jl")
include("pq.jl")


@setup_workload begin
    @compile_workload begin
        for model in MODEL_REGISTRY[].models
            generate_numerical_type(model)
            generate_vector_type(model)
        end
    end
end

end # module