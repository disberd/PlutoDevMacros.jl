module TestUsingNames

using Base64

export top_level_func
top_level_func() = 1
clash_name = 5

module Test1
    using Example
    include("test1.jl")
end

module Test2
    using ..Test1, Base64
    include("test2.jl")
end

module Test3
    using ..TestUsingNames
    include("test3.jl")
end

include("../test_notebook1.jl")
include("../test_notebook2.jl")

end # module TestUsingNames
