# This function just makes a random alphanumeric id always starting with letter R
randid() = "R" * string(rand(UInt32); base = 62)
# This function, if appearing inside a capture log message in Pluto (not with
# println, just the @info, @warn, etc ones), will hide itself. It is mostly used
# in combination with other scripts to inject some javascript in the notebook
# without having an ugly empty log below the cell 
"""
    hide_this_log(html_content::AbstractString = "")
    hide_this_log(html::Docs.HTML)
Simple function that returns a `Docs.HTML` object which when sent to Pluto logs with e.g. `@info` (or any other loggin macro), will hide the log from view.

It is mostly intended to send some javascript to the logs for execution but avoid having an empty log box hanging around below the cell.
The output of this function contains a script which will hide the specific log that contains it, and if no other logs are present, will also hide the log container in Pluto.

The function also optionally accept some content that will be inserted just before the script for hiding the log.
The custom input can be provided as an AbstractString, or directly as an HTML object of type `Docs.HTML`, in which case it will simply extract the HTML contents as `String` from the `contents` field.
The provided content will be directly interpreted as HTML, meaning that any script will have to be surrounded by `<script>` tags.

This function is used inside PlutoDevMacros to create the `reload @fromparent` button also via logs for redundancy.

# Example
Suppose you are inside a Pluto notebook and you want to execute some custom javascript from a cell, but for some reason you don't want to have the javascript to be the final output of your cell. You can exploit logs for this (assuming you didn't disable logging for the cell in question).

The following snippet can be inserted in a cell to send a custom message on the javascript developer console while still having a non-javascript cell output.
```julia
julia_output = let
    @info PlutoDevMacros.hide_this_log(html"<script>console.log('message')</script>")
    3
end
```
Which will correctly send the message to the console even if the cell output is not the javascript script:
![hide_this_log example gif](https://github.com/disberd/PlutoDevMacros.jl/assets/12846528/8208243b-62ce-437a-ae87-97e63ca94e12)
"""
function hide_this_log(content = ""; id = randid())
    #! format: off
    this_contents = "<script id = '$id' class='hide-this-log'>
  const logs_positioner = currentScript.closest('pluto-log-dot-positioner')
  if (logs_positioner == undefined) { return }
  const logs = logs_positioner.parentElement
  const logs_container = logs.parentElement

  const style = html`<style>
    pluto-logs-container[hidden] {
      height: 0px;
      padding: 0px;
      visibility: hidden;
    }
    pluto-log-dot-positioner[hidden] {
      height: 0px;
      margin: 0px;
      visibility: hidden;
    }
    </style>`
  
  function callBack(mutationList, observer) {
    let hide_container = true
    for (const child of logs.children) {
        const should_hide = child.querySelector('script.hide-this-log') != undefined
        child.toggleAttribute('hidden', should_hide)
        hide_container = hide_container && should_hide
    }
    // We eventualy hide the container
    logs_container.toggleAttribute('hidden', hide_container)
  }

  const observer = new MutationObserver(callBack)

  observer.observe(logs, { subtree: true, attributes: true, childList: true })
  logs_positioner.toggleAttribute('hidden', true)
  invalidation.then(() => {
    console.log('invalidation of logs hider script')
    callBack()
    observer.disconnect()
  })
  return style
    </script>"
    #! format: on
    simple_html_cat(content, this_contents)
end

extract_html_content(x::AbstractString) = x
extract_html_content(html::Docs.HTML) = html.content

function simple_html_cat(args...)
    Docs.HTML() do io
        for arg in args
                content = extract_html_content(arg)
                content isa Function ?
                    content(io) :
                    print(io, content)
        end
    end
end