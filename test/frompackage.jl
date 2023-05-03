import PlutoDevMacros.FromPackage: process_outside_pluto!

@testset "FromPackage" begin
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
