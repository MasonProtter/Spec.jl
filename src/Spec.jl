module Spec

using ExprTools: splitdef, combinedef
using Test: @test
using MacroTools: postwalk
using Cassette: Cassette, overdub, prehook, @context

export @test, @validated, @pre_spec, @post_spec

@context ValidationCtx

"""
    @validated code

run `code` in a special context where validation tests are run before and/or after
each registered function is called. 

Examples:

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

*Any* function encountered during the execution context will have it's pre and/or post
validation tests run; the functions do not need to be at the 'top-level'. 

    julia> g(x) = f(x) + 1
    g (generic function with 1 method)

    julia> @validated g(Inf)
    Test Failed at REPL[17]:1
      Expression: isfinite(var"##result#254")
    ERROR: There was an error during testing


    julia> g(Inf)
    Inf

Running code within the `@validated` context *will* impose a performance penalty, but 
functions with `@pre_spec`s and/or `@post_spec`s will **not** suffer any performance
penalty outside of a `@validated` context.

    julia> using BenchmarkTools

    julia> h(x) = √x + 2 # never touches f
    h (generic function with 1 method)

    julia> @btime g(($Ref(1))[]);
      1.329 ns (0 allocations: 0 bytes)

    julia> @btime h(($Ref(1))[]);
      1.329 ns (0 allocations: 0 bytes)
"""
macro validated(ex)
    esc(:($Cassette.overdub($ValidationCtx(), () -> $ex)))
end



"""
    @pre_spec fdef

Take a function definition `fdef` and create a spec hook to be run within a 
`@validated` context before the specified function gets run.

    using Spec
    f(x) = √x + 1
    @pre_spec  f(x) = @test x >= 0

    julia> @validated f(1)
    2.0

    julia> @validated f(-1)
    Test Failed at REPL[16]:1
      Expression: x >= 0
       Evaluated: -1 >= 0
    ERROR: There was an error during testing
"""
macro pre_spec(fdef)
    d = splitdef(fdef)
    get!(d, :args, [])
    pushfirst!(d[:args], :(::typeof($(d[:name]))))
    pushfirst!(d[:args], :(::$ValidationCtx))
    d[:name] = :($Cassette.prehook)
    (esc ∘ combinedef)(d)
end

"""
    @post_spec fdef

Take a function definition `fdef` and create a spec hook to be run within a 
`@validated` context before the specified function gets run. Use `__result__` to 
directly reference the result of the function call inside the post_spec.

    using Spec
    f(x) = √x + 1
    @post_spec f(x) = @test isfinite(__result__)

    julia> f(Inf)
    Inf

    julia> @validated f(Inf)
    Test Failed at REPL[17]:1
      Expression: isfinite(var"##result#254")
    ERROR: There was an error during testing
"""
macro post_spec(fdef)
    res = gensym(:result)
    d = splitdef(fdef)
    get!(d, :args, [])
    pushfirst!(d[:args], :(::$ValidationCtx), res, :(::typeof($(d[:name]))))
    d[:name] = :($Cassette.posthook)
    d[:body] = postwalk(d[:body]) do x
        x == :(__result__) ? (res) : x
    end
    (esc ∘ combinedef)(d)
end

end # module
