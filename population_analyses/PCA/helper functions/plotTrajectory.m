function plotTrajectory(data, windowPlot, eventIdx, colors, labels, selectedPCs, background)

    % Plot 3D PC trajectories for each condition.
    % A filled circle marks the first time point, a star marks event onset,
    % and an open circle marks the final time point.

    fig = figure('Color', background, ...
        'Name', ['3D Trajectories - ' background]);

    ax = axes(fig);
    hold(ax, 'on');

    markerSize = 65;
    lineWidth = 2;

    for c = 1:numel(windowPlot)
        idx = windowPlot{c};
        currentData = data(idx, :);
        color = colors(c, :);

        plot3(ax, currentData(:, 1), currentData(:, 2), ...
            currentData(:, 3), 'Color', color, ...
            'LineWidth', lineWidth);

        % Mark trajectory start.
        scatter3(ax, currentData(1, 1), currentData(1, 2), ...
            currentData(1, 3), markerSize, color, 'filled');

        % Mark event onset.
        scatter3(ax, currentData(eventIdx, 1), ...
            currentData(eventIdx, 2), currentData(eventIdx, 3), ...
            markerSize, color, '*', 'LineWidth', 1.5);

        % Mark trajectory end.
        scatter3(ax, currentData(end, 1), currentData(end, 2), ...
            currentData(end, 3), markerSize, color, 'o', ...
            'LineWidth', 1.5);
    end

    xlabel(ax, sprintf('PC %d', selectedPCs(1)));
    ylabel(ax, sprintf('PC %d', selectedPCs(2)));
    zlabel(ax, sprintf('PC %d', selectedPCs(3)));

    styleAxes(ax, background);
    grid(ax, 'on');
    view(ax, 140, 35);

    % Hide tick labels for a cleaner state-space visualization.
    ax.XTickLabel = [];
    ax.YTickLabel = [];
    ax.ZTickLabel = [];

    % Keep legend optional to avoid cluttering the 3D trajectory.
    % legend(ax, labels, 'Location', 'eastoutside');

    title(ax, 'Neural Population Trajectories', ...
        'Color', themeColor(background));
end
