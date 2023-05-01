import PlutoDevMacros.FromParent: process_ast, add_package_names!, process_outside_pluto!
using MacroTools: rmlines, prewalk, postwalk

@testset "FromParent" begin
    function check_equal(ex, dict)
        ex = prewalk(rmlines, ex)
        new_ex = process_ast(deepcopy(ex), dict)
        equals =  ex == new_ex
        if !equals
            dump(ex)
            dump(new_ex)
        end
        return equals
    end 

    dict = Dict{String, Any}(
        "Expr to Remove" => [],
        "Module Path" => [],
    )
    ex = :(function asd(;params = (;)) end) 
    @test check_equal(ex, dict)

    # Return nothing
    ex = :(if x == 0
        return 
    end) 
    @test check_equal(ex, dict)


    # Test the package name extraction
    @test Set([:PackageA]) == add_package_names!(Set{Symbol}(), :(using PackageA: var1, var2))
    @test Set([:PackageA, :PackageC]) == add_package_names!(Set{Symbol}(), :(using PackageA, .PackageB, PackageC))


    @testset "Outside Pluto" begin
        rmnothing(ex::Expr) = Expr(ex.head, filter(x -> x !== :nothing && !isnothing(x), ex.args)...)
        rmnothing(x) = x
        function expr_equal(ex1, ex2)
            ex1 = prewalk(rmlines, deepcopy(ex1))
            ex1 = postwalk(rmnothing, ex1)
            ex2 = prewalk(rmlines, deepcopy(ex2))
            ex2 = postwalk(rmnothing, ex2)
            ex1 == ex2
        end

        ex = :(import .ASD: lol)
        @test deepcopy(ex) == process_outside_pluto!(ex)
        ex = :(import .ASD: *)
        @test nothing === process_outside_pluto!(ex)
        ex = :(import module: lol)
        @test nothing === process_outside_pluto!(ex)
    end
end
