module Settings
    const SETTINGS_DEFAULTS = Dict{Symbol,Any}()
    const SETTINGS_SYNONYMS = Dict{Symbol,Set{Symbol}}()

    # Add and remove
    function add_setting(name::Symbol, default, synonyms=(name,))
        @nospecialize
        SETTINGS_DEFAULTS[name] = default
        set = Set{Symbol}(synonyms)
        push!(set, name)
        SETTINGS_SYNONYMS[name] = set
        return nothing
    end
    function remove_setting(name::Symbol)
        if name in keys(SETTINGS_DEFAULTS)
            delete!(SETTINGS_DEFAULTS, name)
            delete!(SETTINGS_SYNONYMS, name)
        else
            @warn "The name `$name` is not associated to any valid setting. Nothing was removed."
        end
    end

    function custom_error_msg(name) 
        msg = "The name `$name` is not associated to any valid setting. Here are the valid settings and their allowed synonyms:\n"
        for (k, v) in SETTINGS_SYNONYMS
            msg *= "$k: ("
            first = true
            for n in v
                if first
                    msg *= "$n"
                    first = false
                else
                    msg *= ", $n"
                end
            end
            msg *= ")\n"
        end
        return msg
    end

    function setting_name(name)
        for (k, v) in SETTINGS_SYNONYMS
            name in v && return k
        end
        msg = custom_error_msg(name)
        error(msg)
    end

    function get_setting(dict, name)
        custom_settings = get(dict, "Custom Settings", nothing)
        f() = get_setting(name)
        isnothing(custom_settings) ? f() : get(f, custom_settings, name)
    end
    function get_setting(name::Symbol)
        get(SETTINGS_DEFAULTS, name) do
            msg = custom_error_msg(name)
            error(msg)
        end
    end

    function __init__()
        add_setting(:SHOULD_PREPEND_LOAD_PATH, false, (:should_prepend_load_path, :prepend, :prepend_load_path))
    end
end