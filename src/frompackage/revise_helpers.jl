module ReviseHelpers
    const REVISE_LOADED = Ref{Bool}(false)

    is_revise_loaded() = REVISE_LOADED[]

    function add_revise_data end
end