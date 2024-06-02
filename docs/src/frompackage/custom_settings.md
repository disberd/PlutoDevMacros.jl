# Customize Macro Settings
The macro also allows to override default settings similar to how one skip lines in the package, using a custom `@settings` block as:
```julia
@fromparent begin
    @settings setting1 = val1 setting2 = val2
    import *
end
```
or alternatively: 
```julia
@fromparent begin
    @settings begin
        setting1 = val1
        setting2 = val2
    end
    import *
end
```

Only assignments are supported inside the `@settings` block and only primitive values can be used as `val`, i.e. anything that is parsed as an `Expr` as macro argument is not a valid `val`.

These are the supported settings:
- `SHOULD_PREPEND_LOAD_PATH::Bool`: Defaults to `false`. This specifies whether the active environment added to the `LOAD_PATH` by the macro should go to the end or to the front of the `LOAD_PATH`. In some cases it can be useful to have the custom environment at the beginning of the LOAD_PATH for the purpose of locating packages.