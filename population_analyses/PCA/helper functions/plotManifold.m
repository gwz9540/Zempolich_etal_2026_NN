function plotManifold(Z1, Z2, Z3, conditionGrid, trajectoryData, windowPlot, eventIdx, colors, selectedPCs, background)

    % Plot an interpolated manifold in the selected three-PC space.
    % Surface color indicates the interpolated condition coordinate.
    % Original condition trajectories and temporal landmarks are overlaid.

    fig = figure('Color', background, ...
        'Name', ['Neural Manifold - ' background]);

    ax = axes(fig);
    hold(ax, 'on');

    % Draw the interpolated manifold.
    surf(ax, Z1, Z2, Z3, conditionGrid, ...
        'EdgeColor', 'none', 'FaceAlpha', 0.35);

    colormap(ax, colors);
    clim(ax, [1, size(colors, 1)]);

    % Overlay the original trajectories and their temporal landmarks.
    for c = 1:numel(windowPlot)
        idx = windowPlot{c};
        currentData = trajectoryData(idx, :);
        color = colors(c, :);

        plot3(ax, currentData(:, 1), currentData(:, 2), ...
            currentData(:, 3), 'Color', color, 'LineWidth', 2);

        % Start, event onset, and end markers.
        markerIndices = [1, eventIdx, numel(idx)];
        markerSymbols = {'o', '*', 'o'};

        for m = 1:numel(markerIndices)
            k = markerIndices(m);

            scatter3(ax, currentData(k, 1), currentData(k, 2), ...
                currentData(k, 3), 55, color, markerSymbols{m}, ...
                'LineWidth', 1.3);
        end
    end

    xlabel(ax, sprintf('PC %d', selectedPCs(1)));
    ylabel(ax, sprintf('PC %d', selectedPCs(2)));
    zlabel(ax, sprintf('PC %d', selectedPCs(3)));

    styleAxes(ax, background);
    grid(ax, 'on');
    view(ax, 3);

    ax.XTickLabel = [];
    ax.YTickLabel = [];
    ax.ZTickLabel = [];

    title(ax, 'Interpolated Neural Manifold', ...
        'Color', themeColor(background));

    lighting(ax, 'gouraud');
    camlight(ax, 'headlight');
end
