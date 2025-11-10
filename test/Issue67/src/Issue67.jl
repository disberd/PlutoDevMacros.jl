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

    struct SubThing end

    using Issue67: MyThing

    function construct_thing(a)
        return MyThing(a)
    end

    export SubThing
end

module SubModule2
    module SubSubModule    
        using Issue67.SubModule
    end
end


end # module Issue67
