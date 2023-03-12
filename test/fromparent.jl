import PlutoDevMacros.FromParent: process_ast, add_package_names!
using MacroTools: rmlines, prewalk

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
    @test Set([:PackageA, PackageC]) == add_package_names!(Set{Symbol}(), :(using PackageA, .PackageB, PackageC))
end