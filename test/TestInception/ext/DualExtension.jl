module DualExtension
using Example
using SimplePlutoInclude
using TestInception

@info "Loading DualExtension" Example SimplePlutoInclude

TestInception.dual_extension_loaded[] = true

end
