module MyPkg

export Point, greet, distance, shout

struct Point
    x::Float64
    y::Float64
    z::Float64
end

greet(name) = "Hi, $(name)!"

distance(p::Point) = sqrt(p.x^2 + p.y^2 + p.z^2)

# The methods of this function come from the MyPkgExampleExt extension.
function shout end

end # module MyPkg
