const SHOULD_PREPEND_LOAD_PATH = Ref(false)

function get_setting(dict, name)
    custom_settings = get(dict, "Custom Settings", nothing)
    f() = get_setting(name)
    isnothing(custom_settings) ? f() : get(f, custom_settings, name)
end
function get_setting(name::Symbol)
    name === :SHOULD_PREPEND_LOAD_PATH && return SHOULD_PREPEND_LOAD_PATH[]
    error("The setting $name is not a valid setting")
end