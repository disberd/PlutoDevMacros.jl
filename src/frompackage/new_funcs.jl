
#### New approach stuff ####

# Macro
macro lolol(target::Symbol, ex::Expr)
    isdefined(__module__, target) || error("The symbol $target is not defined in the caller module")
    # @info "$(__module__)"
    caller = String(__source__.file)
    _, cell_id = _cell_data(caller)
    path = Core.eval(__module__, target)
    p = FromPackageController(path, __module__)
    load_module!(p)
    args = extract_input_args(ex)
    for (i, arg) in enumerate(args)
        arg isa Expr || continue
        args[i] = process_input_expr(p, arg)
    end
	text = "Reload @lolol"
	out = quote
		try
			$(args...)
			# We add the reload button as last expression so it's sent to the cell output
			$html_reload_button($cell_id; text = $text)
		catch e
			# We also send the reload button as an @info log, so that we can use the cell output to format the error nicely
			@info $html_reload_button($cell_id; text = $text)
			rethrow()
		end
	end
end