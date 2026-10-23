%% Basic PCA Visualization of Neural Population Dynamics (using raw trial averaged PSTHs)
%   Performs PCA on neural population activity and visualizes condition-
%   specific principal component (PC) trajectories over time.
%
%   Generates:
%       1. PC time courses on white and black backgrounds.
%       2. Variance explained by each principal component.
%       3. Three-dimensional neural trajectories for selected PCs.
%       4. Interpolated manifolds across conditions and time on white
%          and black backgrounds (as shown in Zempolich et al., 2026)
%
% INPUT DATA:
%   newPSTHsToPlot - Structure containing condition-specific neural
%                    activity matrices (neurons x time bins).
%                    For plotType = 3: Cond1, Cond2, ..., CondN.
%                    For plotType = 2: Cond1, Cond2, Cond3.
%                  - This is computed ahead of time, each condition (in
%                    this case corresponding to a movement amplitude) is
%                    saved as 'CondN' inside the struct.
%
% Dependencies:
%   MATLAB Statistics and Machine Learning Toolbox (pca).
%   The variables w1 and w2 (time vector based in your precomputed
%   PSTHs inside the newPSTHsToPlot struct) must be defined before running this script.

% Author - Grant W. Zempolich
% Created - 2024-06-10
% Last updated - 2026-10-13

clc;
close all;

%% User settings

binSize = 1;                   % Temporal bin size (ms)
xVector = (w1*1000):binSize:(w2*1000);

plotType = 1;                  % 3 = Green color gradient                             

nTotalCategories = 9;          % Number of conditions for plotType = 3
nPCsToPlot = 10;               % Number of PCs to display over time

signFlip = -1;                 % Optional sign flip for plotting

fullTitle = 'Top PCs';

% Default figure dimensions.
figureWidth = 1200;
figureHeight = 500;

%% collect neural activity across conditions

% Each condition must contain a matrix organized as neurons x time bins.
% Conditions are concatenated along the time dimension, with each
% condition occupying one consecutive block of time samples.

switch plotType

    case 3
        % Load all specified conditions for amplitude-binning analysis.
        PSTHsToUseOG = cell(1, nTotalCategories);

        for c = 1:nTotalCategories
            conditionName = sprintf('Cond%d', c);
            PSTHsToUseOG{c} = newPSTHsToPlot.(conditionName);
        end

    case 2
        % Load the three conditions used in the 3 zones analysis.
        PSTHsToUseOG = { ...
            newPSTHsToPlot.Cond1, ...
            newPSTHsToPlot.Cond2, ...
            newPSTHsToPlot.Cond3};

    otherwise
        error('plotType must be 2 or 3.');

end

nCats = numel(PSTHsToUseOG);

% Confirm that all conditions have compatible dimensions.
nNeurons = size(PSTHsToUseOG{1}, 1);
nTimeBins = size(PSTHsToUseOG{1}, 2);

for c = 1:nCats
    assert(size(PSTHsToUseOG{c}, 1) == nNeurons, ...
        'All conditions must contain the same neurons.');

    assert(size(PSTHsToUseOG{c}, 2) == nTimeBins, ...
        'All conditions must contain the same number of time bins.');
end

assert(numel(xVector) == nTimeBins, ...
    'xVector must contain one time point per time bin.');

% Concatenate conditions into a neurons x (conditions*time) matrix.
PSTHsToUse = cell2mat(PSTHsToUseOG);

%% define condition colors

% Use the green/purple manuscript gradient for amplitude-binning analyses and distinct
% condition colors for zones analyses.
switch plotType

    case 1
        % Gradually vary green intensity across conditions.
        conditionColors = [ ...
            linspace(0.8, 0, nCats)', ...
            linspace(1.0, 0.4, nCats)', ...
            linspace(0.8, 0, nCats)'];

    case 2
        % Gradually vary purple intensity across conditions.
        conditionColors = [linspace(1, 0.3, nCats)', ...   % Red channel from 1 to 0.3
            linspace(0.9, 0, nCats)', ...   % Green channel from 0.9 to 0
            linspace(1, 0.5, nCats)'];       % Blue channel from 1 to 0.5
    case 3 % Basic orange, magenta, cyan 3 zone color map
        conditionColors = [1 0.6 0.0980;1 0 1;0 1 1];

end

conditionLabels = arrayfun(@(c) sprintf('Condition %d', c), ...
    1:nCats, 'UniformOutput', false);

%% standardize neural activity and perform PCA

% Standardize each neuron's activity across all conditions and time bins.
% This gives each neuron comparable scale in the PCA.

dataToPCA = zscore(PSTHsToUse, 0, 2);

% Replace undefined standardized values for constant neurons with zero.
% Such neurons contain no temporal or condition-dependent variance.
dataToPCA(isnan(dataToPCA)) = 0;

% PCA expects observations x features.
% Here, observations are condition-time samples and features are neurons.
[coeff, score, ~, ~, explained] = pca(dataToPCA');

% Each row of score corresponds to one condition-time sample.
% Each column corresponds to one principal component.
nAvailablePCs = size(score, 2);
nPCsToPlot = min(nPCsToPlot, nAvailablePCs);

% Define the row indices corresponding to each condition.
windowPlot = cell(1, nCats);

for c = 1:nCats
    windowPlot{c} = (c-1)*nTimeBins + (1:nTimeBins);
end

% Identify the first time bin at or after stimulus/event onset.
[~, eventIdx] = min(abs(xVector));

%% plot PC time courses on white and black backgrounds

% Each subplot displays one PC over time.
% Each colored line represents a different condition.

plotPCGrid(score, xVector, windowPlot, conditionColors, ...
    nPCsToPlot, fullTitle, 'w', figureWidth, figureHeight);

plotPCGrid(score, xVector, windowPlot, conditionColors, ...
    nPCsToPlot, fullTitle, 'k', figureWidth, figureHeight);

%% plot variance explained

% Display the fraction of total variance explained by each PC.
figure('Name', 'Variance Explained', 'Color', 'w');

nVariancePCs = min(10, numel(explained));

scatter(1:nVariancePCs, explained(1:nVariancePCs), ...
    45, 'k', 'filled');

xlabel('Principal component');
ylabel('Variance explained (%)');
title('PCA Variance Explained');
xlim([0, nVariancePCs + 1]);
box off;

%% select PCs for 3D trajectory visualization

% Choose which principal components define the three axes of the
% neural state-space trajectory.

pcn1 = input('Which PC for the first axis? ');
pcn2 = input('Which PC for the second axis? ');
pcn3 = input('Which PC for the third axis? ');

selectedPCs = [pcn1, pcn2, pcn3];

assert(all(selectedPCs == round(selectedPCs)) && ...
       all(selectedPCs >= 1) && ...
       all(selectedPCs <= nAvailablePCs), ...
       'Selected PCs must be valid integer component indices.');

% Apply the optional sign flip to the third axis.
% PCA component signs are arbitrary; this changes visualization orientation
% without changing the underlying explained variance.
trajectoryData = score(:, selectedPCs);
trajectoryData(:, 3) = signFlip * trajectoryData(:, 3);

%% plot individual condition trajectories

% Display condition-specific trajectories in the selected three-PC space.
% Filled circles mark trajectory starts, stars mark event onset, and
% open circles mark trajectory ends.

plotTrajectory(trajectoryData, windowPlot, eventIdx, ...
    conditionColors, conditionLabels, selectedPCs, 'w');

plotTrajectory(trajectoryData, windowPlot, eventIdx, ...
    conditionColors, conditionLabels, selectedPCs, 'k');

%% interpolate a manifold across conditions and time

% Reshape the three selected PC projections into condition x time matrices.
% The interpolation connects neighboring condition trajectories to form
% a continuous surface through the neural state space.

manifoldPCs = zeros(nCats, nTimeBins, 3);

for c = 1:nCats
    idx = windowPlot{c};

    manifoldPCs(c, :, 1) = trajectoryData(idx, 1)';
    manifoldPCs(c, :, 2) = trajectoryData(idx, 2)';
    manifoldPCs(c, :, 3) = trajectoryData(idx, 3)';
end

% Create a grid of condition and time coordinates.
[conditionGrid, timeGrid] = meshgrid(1:nCats, 1:nTimeBins);

% Define a finer grid for smooth interpolation.
conditionFine = linspace(1, nCats, 100);
timeFine = linspace(1, nTimeBins, 300);

[conditionFineGrid, timeFineGrid] = ...
    meshgrid(conditionFine, timeFine);

% Interpolate each PC coordinate independently.
% 'natural' interpolation produces a smooth surface between observations.
F1 = scatteredInterpolant(conditionGrid(:), timeGrid(:), ...
    reshape(manifoldPCs(:, :, 1)', [], 1), 'natural');

F2 = scatteredInterpolant(conditionGrid(:), timeGrid(:), ...
    reshape(manifoldPCs(:, :, 2)', [], 1), 'natural');

F3 = scatteredInterpolant(conditionGrid(:), timeGrid(:), ...
    reshape(manifoldPCs(:, :, 3)', [], 1), 'natural');

% Evaluate the interpolated surface on the fine grid.
Z1 = F1(conditionFineGrid, timeFineGrid);
Z2 = F2(conditionFineGrid, timeFineGrid);
Z3 = F3(conditionFineGrid, timeFineGrid);

%% plot the interpolated manifold on white and black backgrounds

% The surface color represents condition position along the interpolation
% grid. Original condition trajectories and temporal markers are overlaid
% to preserve the relationship between the surface and the observed data.

plotManifold(Z1, Z2, Z3, conditionFineGrid, ...
    trajectoryData, windowPlot, eventIdx, conditionColors, ...
    selectedPCs, 'w');

plotManifold(Z1, Z2, Z3, conditionFineGrid, ...
    trajectoryData, windowPlot, eventIdx, conditionColors, ...
    selectedPCs, 'k');


