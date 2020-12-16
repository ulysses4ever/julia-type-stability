# Compute type stability 
# (instead of printing it, as in @code_arntype@
# Inspired by julia/stdlib/InteractiveUtils/src/codeview.jl 
module Stability

using Core: MethodInstance
using MethodAnalysis: visit

export is_stable_call, is_stable_instance, all_mis_of_module

# turn on debug info:
# julia> ENV["JULIA_DEBUG"] = Main
# turn off:
# juila> ENV["JULIA_DEBUG"] = nothing

# Follows `warntype_type_printer` in the above mentioned file
is_stable_type(@nospecialize(ty)) = begin
    if ty isa Type && (!Base.isdispatchelem(ty) || ty == Core.Box)
        if ty isa Union && Base.is_expected_union(ty)
            true # this is a "mild" problem, so we round up to "stable"
        else
            false
        end
    else
        true
    end
    # Note 1: Core.Box is a type of a heap-allocated value
    # Note 2: isdispatchelem is roughly eqviv. to
    #         isleaftype (from Julia pre-1.0)
    # Note 3: expected union is a trivial union (e.g. 
    #         Union{Int,Missing}; those are deemed "probably
    #         harmless"
end

# f: function name
# t: tuple of argument types
function is_stable_call(@nospecialize(f), @nospecialize(t))
    ct = code_typed(f, t, optimize=false)
    ct1 = ct[1] # we ought to have just one method body, I think
    src = ct1[1] # that's code; [2] is return type, I think
    slottypes = src.slottypes

    # the following check is taken verbatim from code_warntype
    if !isa(slottypes, Vector{Any})
        return true # I don't know when we get here,
                    # over-approx. as stable
    end

    result = true
    
    slotnames = Base.sourceinfo_slotnames(src)
    for i = 1:length(slottypes)
        stable = is_stable_type(slottypes[i])
        @debug "is_stable_call slot:" slotnames[i] slottypes[i] stable
        result = result && stable
    end
    result
end

#
# MethodInstance-based interface (thanks to MethodAnalysis.jl)
#

is_stable_instance(mi :: MethodInstance) =
    is_stable_call(getfield(mi.def.module, mi.def.name), mi.specTypes.types[2:end])

all_mis_of_module(modl :: Module) = begin
    mis = []

    visit(modl) do item
       isa(item, MethodInstance) && push!(mis, item)
       true   # walk through everything
    end
    mis
end

end # module

