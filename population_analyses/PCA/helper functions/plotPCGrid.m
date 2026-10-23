function plotPCGrid(score, xVector, windowPlot, colors, nPCs, plotTitle, background, figWidth, figHeight)

    % Plot PC time courses, with one subplot per component.
    % White and black themes use the same data and condition colors.

    fig = figure('Color', background, ...
        'Name', ['PC Time Courses - ' background], ...
        'Position', [100, 100, figWidth, figHeight]);

    tiledlayout(fig, 2, 5, 'TileSpacing', 'compact', ...
        'Padding', 'compact');

    for pc = 1:nPCs
        ax = nexttile;
        hold(ax, 'on');

        for c = 1:numel(windowPlot)
            idx = windowPlot{c};

            plot(ax, xVector, score(idx, pc), ...
                'Color', colors(c, :), 'LineWidth', 1.3);
        end

        xline(ax, 0, '--', 'Color', themeColor(background), ...
            'HandleVisibility', 'off');

        title(ax, sprintf('PC %d', pc), ...
            'Color', themeColor(background));

        xlabel(ax, 'Time (ms)');
        ylabel(ax, 'Projection');

        styleAxes(ax, background);
        xlim(ax, [xVector(1), xVector(end)]);
    end

    sgtitle(fig, plotTitle, 'Color', themeColor(background));
end