module PlotlyBaseExt
    using PlotlyBase
    using TestDirectExtension
    using TestDirectExtension.PlotlyExtensionsHelper

    TestDirectExtension.to_extend(p::Plot) = "Standard Extension works!"
    TestDirectExtension.plot_this() = plotly_plot(rand(10,4))
end