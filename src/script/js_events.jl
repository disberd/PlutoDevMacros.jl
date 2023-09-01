## Automatic Event Listeners - HTLScript ##

_events_listeners_preamble = HTLScript(@htl("""
<script>
	/* #### BEGINNING OF PART AUTOMATICALLY ADDED BY HTLSCRIPT #### */
	// Array where all the event listeners are stored
	const _events_listeners_ = []

	// Function that can be called to add events listeners within the script
	function addScriptEventListeners(element, listeners) {
		if (listeners.constructor != Object) {error('Only objects with keys as event names and values as listener functions are supported')}
		_events_listeners_.push({element, listeners})
	}
	/* #### END OF PART AUTOMATICALLY ADDED BY HTLSCRIPT #### */
</script>
"""));

_events_listeners_postamble = HTLScript(;
body = @htl("""
<script>
	/* #### BEGINNING OF PART AUTOMATICALLY ADDED BY HTLSCRIPT #### */
	// Assign the various events listeners defined within the script
	for (const item of _events_listeners_) {
		const { element, listeners } = item
		for (const [name, func] of _.entries(listeners)) {
  			element.addEventListener(name, func)
		}
	}
	/* #### END OF PART AUTOMATICALLY ADDED BY HTLSCRIPT #### */
</script>
"""),
invalidation = @htl("""
<script>	
		/* #### BEGINNING OF PART AUTOMATICALLY ADDED BY HTLSCRIPT #### */
		// Remove the events listeners during invalidation
		for (const item of _events_listeners_) {
			const { element, listeners } = item
			for (const [name, func] of _.entries(listeners)) {
	  			element.removeEventListener(name, func)
			}
		}
		/* #### END OF PART AUTOMATICALLY ADDED BY HTLSCRIPT #### */
</script>
"""))