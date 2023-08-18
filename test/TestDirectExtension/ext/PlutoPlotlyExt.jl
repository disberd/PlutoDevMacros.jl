module PlutoPlotlyExt
    using PlutoPlotly
    using TestDirectExtension

    TestDirectExtension.to_extend(p::PlutoPlot) = "Standard Extension works!"
end