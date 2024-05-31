module DualDepsExt
    import Example
    import PlotlyBase
    import TestDirectExtension

    TestDirectExtension.to_extend(::Tuple{typeof(Example.hello), PlotlyBase.Plot}) = "Dual Deps Extension works!"
end