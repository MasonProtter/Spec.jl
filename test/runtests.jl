using Spec, Test

function myreverse end

@pre_spec function myreverse(x)
    # Test that our input has the right methods defined on it to be 'reversed'.
    @assert hasmethod(similar,   Tuple{typeof(x)})
    @assert hasmethod(eachindex, Tuple{typeof(x)})
    @assert hasmethod(getindex,  Tuple{typeof(x), Int})
end

@post_spec function myreverse(x::T) where {T}
    @assert __result__ isa T
    for i in eachindex(x, __result__)
        @assert x[i] == __result__[end-i+1]
    end
    @assert myreverse(__result__) == x
end

function myreverse(x)
    out = similar(x)
    for i ∈ eachindex(x, out)
        out[end-i+1] = x[i]
    end
    out
end

@test_throws MethodError myreverse("hi")
@test_throws AssertionError @validated myreverse("hi")

f(x) = x + 1
@post_spec f(x) = @assert isfinite(__result__)

@test isnan(f(NaN))
@test_throws AssertionError @validated f(NaN)
