module Issue67

struct MyThing
    a::Int
end

get_a(t::MyThing) = t.a

function do_stuff(t::MyThing)
    a = get_a(t)
    return a * rand()
end

module SubModule

    using ..Issue67: MyThing

    function construct_thing(a)
        return MyThing(a)
    end

end

end # module Issue67
