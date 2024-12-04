using PowerFlowData

struct BusInput{
    Ti1<:Integer,Ti2<:Integer,Ti3<:Integer,
    Ts<:AbstractString,
    Tf<:AbstractFloat,
}

    i::Vector{Ti1}
    name::Vector{Ts}
    basekv::Vector{Tf}
    ide::Vector{Ti2}
    area::Vector{Ti3}
    zone::Vector{Ti3}
    vm::Vector{Tf}
    va::Vector{Tf}
    nvhi::Vector{Tf}
    nvlo::Vector{Tf}
    evhi::Vector{Tf}
    evlo::Vector{Tf}
end

"""
    BusInput(buses::PowerFlowData.Buses33)

Construct a `BusInput` from a `PowerFlowData.Buses33` struct.
"""
function BusInput(buses::PowerFlowData.Buses33)
    return BusInput(
        buses.i,
        buses.name,
        buses.basekv,
        buses.ide,
        buses.area,
        buses.zone,
        buses.vm,
        buses.va,
        buses.nvhi,
        buses.nvlo,
        buses.evhi,
        buses.evlo,
    )
end



"""
This is a struct for holding the internal data used for computation.
"""
struct BusInternal

end


"""
    get_online_status(bus_input::BusInput)

Return an array of the online status of the buses, with `1` being online and `0`
being offline.
"""
function get_online_status(bus_input::BusInput)
    return bus_input.ide .!= 4
end

"""
    get_online_count(bus::Bus)

Return the number of online buses.
"""
function get_online_count(bus_input::BusInput)
    return get_online_status(bus_input) |> sum
end

struct BusVars{Tf<:AbstractFloat}
    ## Here, we can mix internal and external variables. Both of them will need to be updated
    ##   from the global array.
    ## Any scenarios where the internal variables need to be treated differently?

    va::Vector{Tf}
    vm::Vector{Tf}
end

struct VarAttributes{Tv<:VarType}
    private::Bool
    type::Tv
end


struct BusVarsAttributes
    va::VarAttributes{State}
    vm::VarAttributes{Algebraic}
end

struct BusResiduals{Tf<:AbstractFloat}
    va_rhs::Vector{Tf}
    vm_rhs::Vector{Tf}
end

struct ResidualAttributes{Tr<:ResidualType}
    private::Bool
    type::Tr
end


function copy_full_residuals_to_dae!(dae::DAE, bus_residuals::BusResiduals, )

end


function add_partial_residuals_to_dae!(dae::DAE, bus_residuals::BusResiduals)

end



## What's needed from the bus model to indicate its characteristics?

## Bus needs to tell the address allocator how many differential and algebraic variables are needed

## Bus needs to tell the address allocator how many residual equations are needed

## Bus needs to indicate the type of residual: partial or full

## Bus needs to tell the address allocator which residual equations are needed


## Should the address management be taken out of the models?

struct BusVarAddress{Ti<:Integer}
    va::Vector{Ti}
    vm::Vector{Ti}
end

struct BusResidualAddress{Ti<:Integer}
    va_rhs::Vector{Ti}
    vm_rhs::Vector{Ti}
end


"""
$(SIGNATURES)

Set the initial guess for the bus variables.
"""
function set_initial_guess(
    bus_vars::BusVars,
    bus_input::BusInput,
    bus_internal::BusInternal
)

    filter_online = get_online_status(bus_input)

    bus_vars.va .= bus_input.va[filter_online]
    bus_vars.vm .= bus_input.vm[filter_online]

end
