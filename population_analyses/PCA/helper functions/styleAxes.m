function styleAxes(ax, background)

    % apply consistent axis formatting for white and black figures.
    ax.Color = background;
    ax.XColor = themeColor(background);
    ax.YColor = themeColor(background);
    ax.ZColor = themeColor(background);
    ax.GridColor = themeColor(background);
    ax.GridAlpha = 0.2;
    ax.LineWidth = 1;
    ax.FontSize = 10;

    box(ax, 'on');
end