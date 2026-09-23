# Add methods to functions of the target package

To add a method to a function of the target package from a notebook cell,
put [`@addmethod`](@ref) before the method definition. With the `MyPkg`
package from the tutorials:

```julia
@addmethod greet(x::Int) = "number $x"
```

```julia
greet(3)
```

The second cell shows `"number 3"`. The function form also works:

```julia
@addmethod function greet(x::Int)
    return "number $x"
end
```

Without `@addmethod`, the cell `greet(x::Int) = "number $x"` defines a new
`greet` in the notebook. Pluto then shows a `Multiple definitions for greet`
error, because the `@fromparent` cell also defines `greet`.

## Know when cells run again

- The cells that call `greet` do not run again when the `@addmethod` cell
  runs. Run them yourself.
- A click on the reload button runs the `@addmethod` cell again, because the
  cell uses `greet`. The method is then part of the new module.
- If you delete the `@addmethod` cell, the method stays until the next
  reload.

## Use it in a notebook that the package includes

Outside of the notebook, `@addmethod` does not change the definition. In a
notebook that the target package includes, the definition then adds a
normal method when the package loads. The page
[Run code only inside or outside the notebook](notebook_only_code.md) shows
how a package includes a notebook.
