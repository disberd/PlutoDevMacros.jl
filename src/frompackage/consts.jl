const IS_DEV = first(fullname(@__MODULE__)) === :Main
const TEMP_MODULE_NAME = Symbol(:_FrompPackage_TempModule_, IS_DEV ? "DEV_" : "")
const EMPTY_PIPE = Pipe()
const STDLIBS_DATA = Dict{String,Base.UUID}()
for (uuid, (name, _)) in Pkg.Types.stdlibs()
    STDLIBS_DATA[name] = uuid
end
const PREV_CONTROLLER_NAME = Symbol(:_Previous_Controller_, IS_DEV ? "DEV_" : "")

const CURRENT_FROMPACKAGE_CONTROLLER = Ref{FromPackageController}()