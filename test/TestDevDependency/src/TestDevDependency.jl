module TestDevDependency

greet() = print("Hello World!")

struct TestType end
test_type_error(t::TestType, ::Bool) = true

end # module TestDevDependency
