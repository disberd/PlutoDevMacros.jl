module MyPkgExampleExt

using MyPkg
using Example

MyPkg.shout(name) = uppercase(Example.hello(name)) * "!"

end # module MyPkgExampleExt
