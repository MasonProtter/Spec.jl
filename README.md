# Spec.jl

Spec.jl is an *experimental* package trying to incorportate ideas from [Clojure's spec](https://clojure.org/guides/spec). 
The idea in Spec.jl is that we define `@pre_spec` and/or `@post_spec` functions which are run before and/or after a given 
function when in a validation context. If that word-salad didn't make sense, perhaps this code will:
```julia
using Spec
f(x) = √x + 1
@pre_spec  f(x) = @test x >= 0
@post_spec f(x) = @test isfinite(__result__)

julia> @validated f(1)
2.0

julia> @validated f(-1)
Test Failed at REPL[16]:1
  Expression: x >= 0
    Evaluated: -1 >= 0
ERROR: There was an error during testing

julia> @validated f(Inf)
Test Failed at REPL[17]:1
  Expression: isfinite(var"##result#254")
ERROR: There was an error during testing

julia> f(Inf)
Inf
```
The intent is to use this is a way of defining tests alongside functions and be able to specify contexts where
the tests are run automatically on the function inputs and/or outputs.

*Any* function encountered during the execution context will have it's pre and/or post
validation tests run; the functions do not need to be at the 'top-level'. 

```julia
julia> g(x) = f(x) + 1
g (generic function with 1 method)

julia> @validated g(Inf)
Test Failed at REPL[17]:1
  Expression: isfinite(var"##result#254")
ERROR: There was an error during testing

julia> g(Inf)
Inf
```

### Won't automatically testing all my code make it slow?
Running code within the `@validated` context *will* impose a performance penalty, but 
functions with `@pre_spec`s and/or `@post_spec`s will **not** suffer any performance
penalty outside of a `@validated` context.

```julia
julia> using BenchmarkTools

julia> h(x) = √x + 2 # never touches f
h (generic function with 1 method)

julia> @btime g(($Ref(1))[]);
  1.329 ns (0 allocations: 0 bytes)

julia> @btime h(($Ref(1))[]);
  1.329 ns (0 allocations: 0 bytes)
```

## Using Spec.jl in unit-testing

You don't have to use the `Test.@test` macro (re-exported by Spec.jl) in your pre/post specifications, you're free to use
things like `@assert` or even `println` statements if you prefer, but one benefit of using `@test` is that it naturally
interfaces with Julia's standard unit-testing infrastructure.

Consider the following (not very good) implementation of a `reverse` function:

```julia
using Spec

function myreverse end

@pre_spec function myreverse(x)
	# Test that our input has the right methods defined on it to be 'reversed'.
    @test hasmethod(similar, Tuple{typeof(x)})
    @test hasmethod(eachindex, Tuple{typeof(x)})
    @test hasmethod(getindex, Tuple{typeof(x), Int})
end

@post_spec function myreverse(x::T) where {T}
    @test __result__ isa T
    for i in eachindex(x, __result__)
        @test x[i] == __result__[end-i+1]
    end
    @test myreverse(__result__) == x
end

function myreverse(x)
    out = similar(x)
    @inbounds for i ∈ eachindex(x, out)
        out[end-i+1] = x[i]
    end
    out
end
```

Now, our unit-tests are already written and we merely have to provide inputs:
```julia
julia> using Test: @testset

julia> @testset "myreverse(::Vector{Float64})" begin
           @validated myreverse(rand(10))
       end
Test Summary:                | Pass  Total
myreverse(::Vector{Float64}) |   15     15
Test.DefaultTestSet("myreverse(::Vector{Float64})", Any[], 15, false)
```
So far so good. What about String inputs?
```julia
julia> @testset "myreverse(::String)" begin
           @validated myreverse("hello")
       end
myreverse(::String): Test Failed at REPL[3]:4
  Expression: hasmethod(similar, Tuple{typeof(x)})
Stacktrace:
  [...]
myreverse(::String): Error During Test at REPL[8]:1
  Got exception outside of a @test
  MethodError: no method matching similar(::String)
  Closest candidates are:
    similar(!Matched::BenchmarkGroup) at /home/mason/.julia/packages/BenchmarkTools/eCEpo/src/groups.jl:24
    similar(!Matched::JuliaInterpreter.Compiled, !Matched::Any) at /home/mason/.julia/packages/JuliaInterpreter/RmxVj/src/types.jl:7
    similar(!Matched::ZMQ.Message, !Matched::Type{T}, !Matched::Tuple{Vararg{Int64,N}} where N) where T at /home/mason/.julia/packages/ZMQ/R3wSD/src/message.jl:93
    ...
  Stacktrace:
    [...]
  
Test Summary:       | Pass  Fail  Error  Total
myreverse(::String) |    2     1      1      4
ERROR: Some tests did not pass: 2 passed, 1 failed, 1 errored, 0 broken.
```
Good catch!
