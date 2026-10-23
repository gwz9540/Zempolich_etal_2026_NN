function color = themeColor(background)

    % contrasting text and axis color for the selected theme.

    if strcmpi(background, 'k')
        color = 'w';
    else
        color = 'k';
    end
end