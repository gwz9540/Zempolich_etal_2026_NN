function [alignmentScore, transform, residualsPerPC, slidingResidualsPerPC] = run_procrustes_alignment_twoManifolds(data1, data2, numPCs, dimsForProcrustes, name1, name2, plotIn3D, alignedColors, doShuffle)
% Procrustes analysis on neural psths
% Performs PCA on two neural datasets, aligns via Procrustes, and evaluates axis-specific distortion.
%
% INPUTS:
%   data1, data2        : cell arrays (1xN), each cell neurons x time_bins
%   numPCs              : number of PCs to extract (e.g. 15)
%   dimsForProcrustes   : how many top dims to use for alignment (e.g. 3-6)
%   name1, name2        : labels for plotting (optional)
%   plotIn3D            : true = 3D plot, false = 2D
%   alignedColors       : colors to use for each interpolated manifold
%   doShuffle           : true = shuffle time bins
%
% OUTPUTS:
%   alignmentScore      : scalar Procrustes residual (lower = better)
%   transform           : struct with Procrustes transformation
%   residualsPerPC      : vector of per-dimension Procrustes errors

if nargin < 3
    numPCs = 10;
end
if nargin < 4
    dimsForProcrustes = 3;
end
if nargin < 7
    plotIn3D = true;
end

numConds = numel(data1);

[data1_z, ~, ~] = zscore_neurons(data1,numConds);
[data2_z, ~, ~] = zscore_neurons(data2,numConds);

% Concatenate across conditions
allData1 = []; allData2 = [];
for cond = 1:numConds
    allData1 = [allData1, data1_z{cond}];
    allData2 = [allData2, data2_z{cond}];
end

%  PCA 
[coeff1, ~, ~, ~, ~] = pca(allData1', 'NumComponents', numPCs);
[coeff2, ~, ~, ~, ~] = pca(allData2', 'NumComponents', numPCs);

latent1 = cell(1,numConds);
latent2 = cell(1,numConds);
for cond = 1:numConds
    latent1{cond} = coeff1' * data1_z{cond};
    latent2{cond} = coeff2' * data2_z{cond};
end

% Optional Shuffle Control
%doShuffle = true;  % Set to true to enable shuffling

if doShuffle
    rng('shuffle');  % For randomness (optional- set fixed seed for reproducibility)
    for cond = 1:numConds
        % Shuffle time bins (columns) independently in each projection
        perm1 = randperm(size(latent1{cond}, 2));
        perm2 = randperm(size(latent2{cond}, 2));
        
        latent1{cond} = latent1{cond}(:, perm1);
        latent2{cond} = latent2{cond}(:, perm2);
    end
end

% Combine into full latent trajectories
X = []; Y = [];
for cond = 1:numConds
    X = [X, latent1{cond}];
    Y = [Y, latent2{cond}];
end

X_t = X';  % timepoints x dims
Y_t = Y';

%  Procrustes alignment on top dims 
[alignmentScore, Z_aligned, transform] = procrustes(X_t(:,1:dimsForProcrustes), Y_t(:,1:dimsForProcrustes));

% Apply same transform to full Y space 
% Project Y_t (numPCs) through Procrustes transform (which affects only dimsForProcrustes)
Y_aligned_full = Y_t;
Y_aligned_full(:,1:dimsForProcrustes) = Z_aligned;

% Compute residuals per PC (across full space) 
%residualsPerPC = sqrt(mean((Y_aligned_full - X_t).^2, 1));

residual_idxs = [];

for cond = 1:numConds
    % Compute the start index for this condition in the full 4503xD matrix
    cond_start_idx = (cond - 1) * 1501;

    time_within_cond = 1:1501;

    % Convert to indices in concatenated matrix
    residual_idxs = [residual_idxs, cond_start_idx + time_within_cond];
end

% Use only the selected indices to compute residuals per PC
residualsPerPC = sqrt(mean((Y_aligned_full(residual_idxs,:) - X_t(residual_idxs,:)).^2, 1));
%% Sliding window residuals per PC

windowSize = 50;
numTimepoints = 1501;
numWindows = numTimepoints - windowSize + 1;

slidingResidualsPerPC = zeros(numWindows, numPCs);

for win = 1:numWindows
    window_idxs = [];  % Collect indices across all conditions for this window

    for cond = 1:numConds
        cond_start_idx = (cond - 1) * numTimepoints;
        time_window = win:(win + windowSize - 1);
        window_idxs = [window_idxs, cond_start_idx + time_window];
    end

    % Compute residuals for this window
    window_residuals = sqrt(mean((Y_aligned_full(window_idxs,:) - X_t(window_idxs,:)).^2, 1));

    slidingResidualsPerPC(win, :) = window_residuals;
end
 
% Optional: Replace the original residualsPerPC with average over all windows
% residualsPerPC = mean(slidingResidualsPerPC, 1); 

%  Summary stats
fprintf('\nProcrustes residual alignment score (dims 1:%d): %.4f\n', dimsForProcrustes, alignmentScore);
fprintf('Mean correlation (dims 1:%d) across conditions: ', dimsForProcrustes);

% Optional per-condition correlation
corrs = zeros(numConds,1);
for cond = 1:numConds
    time_idx = (cond-1)*size(latent1{cond},2) + (1:size(latent1{cond},2));
    Xc = X_t(time_idx,1:dimsForProcrustes);
    Zc = Z_aligned(time_idx,1:dimsForProcrustes);
    corrs(cond) = corr(Xc(:), Zc(:));
end
fprintf('%.4f ± %.4f\n', mean(corrs), std(corrs));

% Report residuals
%fprintf('\nResidual Procrustes error per PC (1 to %d):\n', numPCs);
%disp(residualsPerPC');

fprintf('Norm of residuals in PC1–2: %.4f\n', norm(residualsPerPC(1:2)));
if numPCs >= 3
    fprintf('Residual in PC3: %.4f\n', residualsPerPC(3));
end
fprintf('Total residual norm (all PCs): %.4f\n', norm(residualsPerPC));

% Plotting

color1 = [linspace(0.8, 0.1, numConds)', linspace(1.0, 0.4, numConds)', linspace(0.8, 0.1, numConds)'];
color2 = [linspace(1.0, 0.4, numConds)', linspace(0.9, 0.1, numConds)', linspace(1.0, 0.5, numConds)'];

trialStart = 501;
trajEnd = 1501;
trajStart = 1;
markerSize = 60;
lineW = 3;

figure; hold on;
x0=200;
y0=200;
width=270;
height=270;
set(gcf,'position',[x0,y0,width,height])
set(gcf,'color','w');
axis tight;

for cond = 1:numConds
    time_idx = (cond-1)*size(latent1{cond},2) + (1:size(latent1{cond},2));
    traj1 = -X_t(time_idx,1:dimsForProcrustes);
    traj2 = -Z_aligned(time_idx,1:dimsForProcrustes);

    if dimsForProcrustes >= 3
        % 3D Plot
        plot3(traj1(:,1), traj1(:,2), traj1(:,3), '-', 'Color', color1(cond,:), 'LineWidth', lineW);
        scatter3(traj1(trialStart,1), traj1(trialStart,2), traj1(trialStart,3), 160, color1(cond,:), 'Marker', '*','LineWidth',1.5)
        scatter3(traj1(trajEnd,1), traj1(trajEnd,2), traj1(trajEnd,3), markerSize, color1(cond,:))
        scatter3(traj1(trajStart,1), traj1(trajStart,2), traj1(trajStart,3), markerSize, color1(cond,:), 'filled')

        plot3(traj2(:,1), traj2(:,2), traj2(:,3), '-', 'Color', color2(cond,:), 'LineWidth', lineW);
        scatter3(traj2(trialStart,1), traj2(trialStart,2), traj2(trialStart,3), 160, color2(cond,:), 'Marker', '*','LineWidth',1.5)
        scatter3(traj2(trajEnd,1), traj2(trajEnd,2), traj2(trajEnd,3), markerSize, color2(cond,:))
        scatter3(traj2(trajStart,1), traj2(trajStart,2), traj2(trajStart,3), markerSize, color2(cond,:), 'filled')
    else
        % 2D Plot
        plot(traj1(:,1), traj1(:,2), '-', 'Color', color1(cond,:), 'LineWidth', lineW);
        scatter(traj1(trialStart,1), traj1(trialStart,2), markerSize, color1(cond,:), 'Marker', '*')
        scatter(traj1(trajEnd,1), traj1(trajEnd,2), markerSize, color1(cond,:))
        scatter(traj1(trajStart,1), traj1(trajStart,2), markerSize, color1(cond,:), 'filled')

        plot(traj2(:,1), traj2(:,2), '-', 'Color', color2(cond,:), 'LineWidth', 3);
        scatter(traj2(trialStart,1), traj2(trialStart,2), markerSize, color2(cond,:), 'Marker', '*')
        scatter(traj2(trajEnd,1), traj2(trajEnd,2), markerSize, color2(cond,:))
        scatter(traj2(trajStart,1), traj2(trajStart,2), markerSize, color2(cond,:), 'filled')
    end
end

xlabel('PC1'); ylabel('PC2');
if dimsForProcrustes >= 3
    zlabel('PC3'); view(3);
else
    view(2);
end
view(3);
set(gca, 'XTickLabel', []);
set(gca, 'YTickLabel', []);
set(gca, 'ZTickLabel', []);
set(gca, 'LineWidth', 1);
%title(sprintf('(top %d PCs): %.4f', dimsForProcrustes, alignmentScore));
grid on;
hold off;


% plot on black background with white axis labels

trialStart = 501;
trajEnd    = 1501;
trajStart  = 1;

markerSize = 60;
lineW      = 3;

% FIGURE
figure;

x0 = 200;
y0 = 200;

width  = 270;
height = 270;

set(gcf, ...
    'Position',[x0 y0 width height], ...
    'Color','k', ...
    'Renderer','opengl');

ax = gca;

hold(ax,'on');

ax.Color = 'k';

ax.XColor = 'w';
ax.YColor = 'w';
ax.ZColor = 'w';

ax.LineWidth = 1;
ax.FontSize = 10;

box(ax,'off');

grid(ax,'on');

ax.GridColor = [0.7 0.7 0.7];
ax.GridAlpha = 0.20;


% plot trajs

for cond = 1:numConds

    time_idx = ...
        (cond-1)*size(latent1{cond},2) + ...
        (1:size(latent1{cond},2));

    traj1 = -X_t(time_idx,1:dimsForProcrustes);
    traj2 = -Z_aligned(time_idx,1:dimsForProcrustes);


    if dimsForProcrustes >= 3

        % traj 1

        plot3(ax, ...
            traj1(:,1), ...
            traj1(:,2), ...
            traj1(:,3), ...
            '-', ...
            'Color',color1(cond,:), ...
            'LineWidth',lineW);

        % Trial-start star
        scatter3(ax, ...
            traj1(trialStart,1), ...
            traj1(trialStart,2), ...
            traj1(trialStart,3), ...
            160, ...
            color1(cond,:), ...
            'Marker','*', ...
            'LineWidth',1.5);

        % End marker
        scatter3(ax, ...
            traj1(trajEnd,1), ...
            traj1(trajEnd,2), ...
            traj1(trajEnd,3), ...
            markerSize, ...
            color1(cond,:), ...
            'filled');

        % Start marker
        scatter3(ax, ...
            traj1(trajStart,1), ...
            traj1(trajStart,2), ...
            traj1(trajStart,3), ...
            markerSize, ...
            color1(cond,:), ...
            'filled');


        % traj 2

        plot3(ax, ...
            traj2(:,1), ...
            traj2(:,2), ...
            traj2(:,3), ...
            '-', ...
            'Color',color2(cond,:), ...
            'LineWidth',lineW);

        scatter3(ax, ...
            traj2(trialStart,1), ...
            traj2(trialStart,2), ...
            traj2(trialStart,3), ...
            160, ...
            color2(cond,:), ...
            'Marker','*', ...
            'LineWidth',1.5);

        scatter3(ax, ...
            traj2(trajEnd,1), ...
            traj2(trajEnd,2), ...
            traj2(trajEnd,3), ...
            markerSize, ...
            color2(cond,:), ...
            'filled');

        scatter3(ax, ...
            traj2(trajStart,1), ...
            traj2(trajStart,2), ...
            traj2(trajStart,3), ...
            markerSize, ...
            color2(cond,:), ...
            'filled');

    else

        % traj 1

        plot(ax, ...
            traj1(:,1), ...
            traj1(:,2), ...
            '-', ...
            'Color',color1(cond,:), ...
            'LineWidth',lineW);

        scatter(ax, ...
            traj1(trialStart,1), ...
            traj1(trialStart,2), ...
            markerSize, ...
            color1(cond,:), ...
            'Marker','*');

        scatter(ax, ...
            traj1(trajEnd,1), ...
            traj1(trajEnd,2), ...
            markerSize, ...
            color1(cond,:), ...
            'filled');

        scatter(ax, ...
            traj1(trajStart,1), ...
            traj1(trajStart,2), ...
            markerSize, ...
            color1(cond,:), ...
            'filled');


        % traj 2

        plot(ax, ...
            traj2(:,1), ...
            traj2(:,2), ...
            '-', ...
            'Color',color2(cond,:), ...
            'LineWidth',lineW);

        scatter(ax, ...
            traj2(trialStart,1), ...
            traj2(trialStart,2), ...
            markerSize, ...
            color2(cond,:), ...
            'Marker','*');

        scatter(ax, ...
            traj2(trajEnd,1), ...
            traj2(trajEnd,2), ...
            markerSize, ...
            color2(cond,:), ...
            'filled');

        scatter(ax, ...
            traj2(trajStart,1), ...
            traj2(trajStart,2), ...
            markerSize, ...
            color2(cond,:), ...
            'filled');

    end

end


xlabel(ax,'PC1','Color','w');
ylabel(ax,'PC2','Color','w');

if dimsForProcrustes >= 3
    zlabel(ax,'PC3','Color','w');
end


set(ax, ...
    'XTickLabel',[], ...
    'YTickLabel',[], ...
    'ZTickLabel',[]);


view(ax,3);

drawnow;

hold(ax,'off');

% parameters
time_points1 = size(latent1{1}, 2);
time_points2 = size(latent2{1}, 2);
dims = dimsForProcrustes;

% prepare first manifold
Z1_reshaped = zeros(numConds, time_points1, dims);
for cond = 1:numConds
    idx = (cond-1)*time_points1 + (1:time_points1);
    Z1_reshaped(cond, :, :) = -X_t(idx, 1:dims);  % Negate as before
end

% Grids for interpolation (manifold 1)
[cond_grid1, time_grid1] = meshgrid(1:numConds, 1:time_points1);
cond_fine = linspace(1, numConds, 100);
time_fine1 = linspace(1, time_points1, 300);
[cond_fine_grid1, time_fine_grid1] = meshgrid(cond_fine, time_fine1);

dim1_1 = squeeze(Z1_reshaped(:, :, 1))'; % time x cond
dim2_1 = squeeze(Z1_reshaped(:, :, 2))';
dim3_1 = squeeze(Z1_reshaped(:, :, 3))';

F1_1 = scatteredInterpolant(cond_grid1(:), time_grid1(:), dim1_1(:), 'natural');
F2_1 = scatteredInterpolant(cond_grid1(:), time_grid1(:), dim2_1(:), 'natural');
F3_1 = scatteredInterpolant(cond_grid1(:), time_grid1(:), dim3_1(:), 'natural');

Z1_1 = F1_1(cond_fine_grid1, time_fine_grid1);
Z2_1 = F2_1(cond_fine_grid1, time_fine_grid1);
Z3_1 = F3_1(cond_fine_grid1, time_fine_grid1);

% prepare second manifold
Z2_reshaped = zeros(numConds, time_points2, dims);
for cond = 1:numConds
    idx = (cond-1)*time_points2 + (1:time_points2);
    Z2_reshaped(cond, :, :) = -Z_aligned(idx, 1:dims);  % Negate as before
end

% Grids for interpolation (manifold 2)
[cond_grid2, time_grid2] = meshgrid(1:numConds, 1:time_points2);
time_fine2 = linspace(1, time_points2, 300);
[cond_fine_grid2, time_fine_grid2] = meshgrid(cond_fine, time_fine2);

dim1_2 = squeeze(Z2_reshaped(:, :, 1))'; % time x cond
dim2_2 = squeeze(Z2_reshaped(:, :, 2))';
dim3_2 = squeeze(Z2_reshaped(:, :, 3))';

F1_2 = scatteredInterpolant(cond_grid2(:), time_grid2(:), dim1_2(:), 'natural');
F2_2 = scatteredInterpolant(cond_grid2(:), time_grid2(:), dim2_2(:), 'natural');
F3_2 = scatteredInterpolant(cond_grid2(:), time_grid2(:), dim3_2(:), 'natural');

Z1_2 = F1_2(cond_fine_grid2, time_fine_grid2);
Z2_2 = F2_2(cond_fine_grid2, time_fine_grid2);
Z3_2 = F3_2(cond_fine_grid2, time_fine_grid2);

% plot both manifolds on same axes

figure; hold on;
x0=600;
y0=200;
width=270;
height=270;
set(gcf,'position',[x0,y0,width,height])
set(gcf,'color','w');

% Plot first manifold surface (green colormap)
h1 = surf(Z1_1, Z2_1, Z3_1, cond_fine_grid1, ...
          'EdgeColor', 'none', 'FaceAlpha', 0.2);

%colormap(gca, flipud(color1));  % green colormap
caxis([1 numConds]);
% camlight left;
% camlight right;
% camlight infinite;
lighting gouraud;
material shiny;

% Plot second manifold surface (purple colormap)
h2 = surf(Z1_2, Z2_2, Z3_2, cond_fine_grid2, ...
          'EdgeColor', 'none', 'FaceAlpha', 0.2);

%colormap(gca, flipud(color2));  % purple colormap
% camlight left;
% camlight right;
% camlight infinite;
lighting gouraud;
material shiny;

set(h1, 'FaceColor', alignedColors{1}, 'CData', []);
set(h2, 'FaceColor', alignedColors{2}, 'CData', []);

xlabel('PC1');
ylabel('PC2');
zlabel('PC3');
view(3); grid on;
%title(sprintf('(top %d PCs): %.4f', dimsForProcrustes, alignmentScore));
set(gca, 'XTickLabel', []);
set(gca, 'YTickLabel', []);
set(gca, 'ZTickLabel', []);
set(gca, 'LineWidth', 1);
set(gca, 'FontSize', 10);

% Green (Manifold 1) top and bottom edges (along time axis)
lWidth = 3;
greenColor = alignedColors{1};
% Top ring (first time point)
plot3(Z1_1(:,1), Z2_1(:,1), Z3_1(:,1), '-', 'Color', greenColor, 'LineWidth', lWidth);
% Bottom ring (last time point)
plot3(Z1_1(:,end), Z2_1(:,end), Z3_1(:,end), '-', 'Color', greenColor, 'LineWidth', lWidth);

% Purple (Manifold 2)
purpleColor = alignedColors{2};
% Top ring
plot3(Z1_2(:,1), Z2_2(:,1), Z3_2(:,1), '-', 'Color', purpleColor, 'LineWidth', lWidth);
% Bottom ring
plot3(Z1_2(:,end), Z2_2(:,end), Z3_2(:,end), '-', 'Color', purpleColor, 'LineWidth', lWidth);
%legend(name1,name2)

hold off;

% plot aligned 3D manifolds on black

figure;

x0 = 600;
y0 = 200;
width = 270;
height = 270;

set(gcf, ...
    'Position',[x0 y0 width height], ...
    'Color','k');

ax = gca;
hold(ax,'on');


greenColor  = alignedColors{1};
purpleColor = alignedColors{2};

h1 = surf(ax, ...
    Z1_1, Z2_1, Z3_1, ...
    'EdgeColor','none', ...
    'FaceColor',greenColor, ...
    'FaceAlpha',0.5);


h2 = surf(ax, ...
    Z1_2, Z2_2, Z3_2, ...
    'EdgeColor','none', ...
    'FaceColor',purpleColor, ...
    'FaceAlpha',0.5);

ax.Color = 'k';

ax.XColor = 'w';
ax.YColor = 'w';
ax.ZColor = 'w';

ax.LineWidth = 1;
ax.FontSize = 10;

box(ax,'off');

grid(ax,'on');

ax.GridColor = [0.7 0.7 0.7];
ax.GridAlpha = 0.20;

xlabel(ax,'PC1','Color','w');
ylabel(ax,'PC2','Color','w');
zlabel(ax,'PC3','Color','w');

set(ax, ...
    'XTickLabel',[], ...
    'YTickLabel',[], ...
    'ZTickLabel',[]);

lWidth = 3;

plot3(ax, ...
    Z1_1(:,1), ...
    Z2_1(:,1), ...
    Z3_1(:,1), ...
    '-', ...
    'Color',greenColor, ...
    'LineWidth',lWidth);

plot3(ax, ...
    Z1_1(:,end), ...
    Z2_1(:,end), ...
    Z3_1(:,end), ...
    '-', ...
    'Color',greenColor, ...
    'LineWidth',lWidth);

plot3(ax, ...
    Z1_2(:,1), ...
    Z2_2(:,1), ...
    Z3_2(:,1), ...
    '-', ...
    'Color',purpleColor, ...
    'LineWidth',lWidth);

plot3(ax, ...
    Z1_2(:,end), ...
    Z2_2(:,end), ...
    Z3_2(:,end), ...
    '-', ...
    'Color',purpleColor, ...
    'LineWidth',lWidth);

view(ax,3);

drawnow;

hold(ax,'off');


end
