
@testset FromParent begin
    dict = something
    ex = :(function asd(;params = (;)) end) 
    @test process_ast(deepcopy(ex), dict)[1] == ex
    ex = :(if x == 0
        return 
    end) 
    @test process_ast(deepcopy(ex), dict)[1] == ex
end