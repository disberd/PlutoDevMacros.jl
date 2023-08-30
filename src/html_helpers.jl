using .Script

# This function, if appearing inside a capture log message in Pluto (not with
# println, just the @info, @warn, etc ones), will hide itself. It is mostly used
# in combination with other scripts to inject some javascript in the notebook
# without having an ugly empty log below the cell 
function hide_this_log()
	body = HTLScriptPart("""
	const logs_positioner = currentScript.closest('pluto-log-dot-positioner')
	if (logs_positioner == undefined) {return}
	const logs = logs_positioner.parentElement
	const logs_container = logs.parentElement

	const observer = new MutationObserver((mutationList, observer) => {
		for (const child of logs.children) {
			if (!child.hasAttribute('hidden')) {
				logs.style.display = "block"
				logs_container.style.display = "block"
				return
			}
		}
		// If we reach here all the children are hidden, so we hide the container as well		
		logs.style.display = "none"
		logs_container.style.display = "none"
	})

	observer.observe(logs, {subtree: true, attributes: true, childList: true})
	logs_positioner.toggleAttribute('hidden',true)
	""")
	invalidation = HTLScriptPart("""
		console.log('invalidation')
		observer.disconnect()
	""")
	return HTLScript(body, invalidation)
end
