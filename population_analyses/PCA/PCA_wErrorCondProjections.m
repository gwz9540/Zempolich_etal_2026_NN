%% Projecting error aligned conditions onto pre-computed neural dimension
clc;
close all;
%% Settings
% Define the reference PSTHs, projection conditions, and bootstrap analysis.

plotType = 2;                 % 2 = amplitude zones; 3 = three-condition PCA
plotColorType = 4;             % 1-6 = predefined color schemes

nAmpBins = 9;                  % Number of reference conditions for plotType 2
numPCsToPlot = 6;              % Number of PCs to calculate and display
pcToPlot = 1;                  % PC used for summary statistics
bootsStrapNum = 200;           % Number of bootstrap iterations
signInversion = -1;            % Global sign convention for reference PCs

windowToCompare = 50;          % Last X ms to compare across error conditions for summary analysis 

graphTitle = 'M2';
xVector = (w1 * 1000):binSize:(w2 * 1000);

% Error conditions to project into the reference PCA space.
projectionFields = {'Cond10', 'Cond11', 'Cond12'};

% Colors used for the three projected conditions.
conditionColors = {
    [0.6350 0.0780 0.1840]
    [0.4940 0.1840 0.5560]
    [0.4660 0.6740 0.1880]
};

% Time windows used for the summary analyses.
preWindow = 1:125;
postWindow = 201:251;

colors{1} = [0.6350 0.0780 0.1840];
colors{2} = [0.4940 0.1840 0.5560];
colors{3} = [0.4660 0.6740 0.1880];

%% Load projection conditions
% Each condition must contain neurons x time bins, with matching neuron order.

PSTHToProject = cellfun( ...
    @(field) newPSTHsToPlot.(field), ...
    projectionFields, 'UniformOutput', false);

nProjectionConditions = numel(PSTHToProject);

% Check that the projected conditions have matching dimensions.
nNeurons = size(PSTHToProject{1}, 1);
nTimeBins = size(PSTHToProject{1}, 2);

assert(numel(xVector) == nTimeBins, ...
    'xVector must contain one value per PSTH time bin.');

for c = 1:nProjectionConditions
    assert(isequal(size(PSTHToProject{c}), [nNeurons, nTimeBins]), ...
        'All projection conditions must have matching dimensions.');
end

%% Assemble the reference PSTHs
% These conditions define the PCA dimensions onto which new PSTHs are projected.

switch plotType
    case 2
        referenceFields = arrayfun( ...
            @(n) sprintf('Cond%d', n), 1:nAmpBins, ...
            'UniformOutput', false);

    case 3
        referenceFields = {'Cond10', 'Cond11', 'Cond12'};

    otherwise
        error('plotType must be 2 or 3.');
end

PSTHsToUseOG = cellfun( ...
    @(field) newPSTHsToPlot.(field), ...
    referenceFields, 'UniformOutput', false);

nCats = numel(PSTHsToUseOG);

% All conditions are concatenated along the time dimension.
PSTHsToUse = cat(2, PSTHsToUseOG{:});

assert(size(PSTHsToUse, 1) == nNeurons, ...
    'Reference and projection conditions must have matching neuron counts.');

assert(all(cellfun(@(x) size(x, 2) == nTimeBins, PSTHsToUseOG)), ...
    'Reference conditions must have matching time-bin counts.');

%% Define reference-condition colors
% Use a consistent color gradient for the reference PCA trajectories.

switch plotColorType
    case 1
        cmp1 = [1 0.6 0.0980; 1 0 1; 0 1 1];

    case 2
        cmp1 = flipud(brewermap(nCats, 'RdYlBu'));

    case 3
        cmp1 = [linspace(0.8, 0, nCats)', ...
                linspace(1, 0.4, nCats)', ...
                linspace(0.8, 0, nCats)'];

    case 4
        cmp1 = [linspace(1, 0.3, nCats)', ...
                linspace(0.9, 0, nCats)', ...
                linspace(1, 0.5, nCats)'];

    case 5
        cmp1 = [linspace(1, 0.3, nCats)', ...
                linspace(0.8, 0, nCats)', ...
                linspace(1, 0.3, nCats)'];

    case 6
        startColor = [0.95 0.98 0.93];
        endColor = [0.466 0.674 0.188];

        cmp1 = [linspace(startColor(1), endColor(1), nCats)', ...
                linspace(startColor(2), endColor(2), nCats)', ...
                linspace(startColor(3), endColor(3), nCats)'];

    otherwise
        error('plotColorType must be between 1 and 6.');
end

%% Compute the reference PCA space
% Standardize each neuron's activity across the concatenated reference PSTHs.
% PCA is performed across neurons, treating time bins as observations.

dataToPCA = PSTHsToUse;
dataToPCA(any(isnan(dataToPCA), 2), :) = 0;

[mu, sigma] = deal(mean(dataToPCA, 2), std(dataToPCA, 0, 2));
sigma(~isfinite(sigma) | sigma == 0) = 1;

newDataToPCA = (dataToPCA - mu) ./ sigma;

% Identify the time bins belonging to each reference condition.
windowPlot = cell(1, nCats);
for c = 1:nCats
    windowPlot{c} = (c - 1) * nTimeBins + (1:nTimeBins);
end

% Coefficients define the reference PCA axes in neuron space.
[coeff, ~] = pca(newDataToPCA');
MasterU = signInversion * coeff;

assert(size(MasterU, 2) >= numPCsToPlot, ...
    'Not enough PCs are available for the requested plots.');

% Reference PC1 projection used to align bootstrap PC signs.
projection1 = newDataToPCA' * MasterU(:, pcToPlot);

%% Plot the reference PCA trajectories
% Each subplot shows one PC across the reference conditions.

figure(2)
set(gcf, 'Color', 'w', 'Position', [300 300 1200 350]);
sgtitle(graphTitle)

for pc = 1:numPCsToPlot
    projection = newDataToPCA' * MasterU(:, pc);

    subplot(2, 6, pc)
    hold on

    for c = 1:nCats
        plot(xVector, projection(windowPlot{c}), ...
            'Color', cmp1(c, :), 'LineWidth', 1);
    end

    xline(0, '--');
    xlim([xVector(1) xVector(end)]);
    xlabel('Time (ms)');
    ylabel(sprintf('PC #%d', pc));
end

%% Project the original conditions onto the reference PCA axes
% Use the reference means and standard deviations to normalize new PSTHs.
% The reference PCA axes remain fixed for these original projections.

PSTHToProjNormalized = cell(1, nProjectionConditions);

for c = 1:nProjectionConditions
    PSTHToProjNormalized{c} = ...
        (PSTHToProject{c} - mu) ./ sigma;
end

originalProjection = cell(numPCsToPlot, nProjectionConditions);

for pc = 1:numPCsToPlot
    for c = 1:nProjectionConditions
        originalProjection{pc, c} = ...
            PSTHToProjNormalized{c}' * MasterU(:, pc);
    end
end

%% Bootstrap the PCA and projection analysis
% Resample neurons with replacement on each iteration.
% Recalculate the PCA using the resampled reference PSTHs.
% Align the bootstrap PCA sign to the reference PC1 projection.
% Normalize and project the three target conditions using the
% bootstrap-specific means, standard deviations, and PCA axes.

projectionVectors = cell(numPCsToPlot, nCats, bootsStrapNum);

projectionError1 = cell(numPCsToPlot, bootsStrapNum);
projectionError2 = cell(numPCsToPlot, bootsStrapNum);
projectionError3 = cell(numPCsToPlot, bootsStrapNum);

cosine_angleBase = nan(numPCsToPlot, bootsStrapNum);
cosine_anglePost = nan(numPCsToPlot, bootsStrapNum);

for boots = 1:bootsStrapNum

    fprintf('Bootstrap %d of %d\n', boots, bootsStrapNum);

    % Sample neurons with replacement.
    neuronsToUse = randsample(nNeurons, nNeurons, true);

    % Resample each reference condition using the same neuron indices.
    bootReference = cellfun( ...
        @(x) x(neuronsToUse, :), PSTHsToUseOG, ...
        'UniformOutput', false);

    bootReferenceData = cat(2, bootReference{:});
    bootReferenceData(any(isnan(bootReferenceData), 2), :) = 0;

    % Standardize the bootstrap reference data.
    muBoot = mean(bootReferenceData, 2);
    sigmaBoot = std(bootReferenceData, 0, 2);
    sigmaBoot(~isfinite(sigmaBoot) | sigmaBoot == 0) = 1;

    bootData = (bootReferenceData - muBoot) ./ sigmaBoot;

    % Recalculate PCA using the bootstrap sample.
    [U, ~, ~] = svd(bootData, 'econ');

    % Match the bootstrap PC1 sign to the reference PC1.
    bootPC1 = bootData' * U(:, pcToPlot);
    referencePC1 = projection1(windowPlot{1});

    alignmentDir = dot(referencePC1, bootPC1(windowPlot{1})) / ...
        (norm(referencePC1) * norm(bootPC1(windowPlot{1})));

    signFlip = 1;
    if alignmentDir < 0
        signFlip = -1;
    end

    % Store the bootstrap reference trajectories.
    for pc = 1:numPCsToPlot
        projection = bootData' * U(:, pc);

        for c = 1:nCats
            projectionVectors{pc, c, boots} = ...
                signFlip * projection(windowPlot{c});
        end
    end

    % Resample the three conditions being projected.
    bootTargets = cellfun( ...
        @(x) x(neuronsToUse, :), PSTHToProject, ...
        'UniformOutput', false);

    % Normalize target PSTHs using this bootstrap sample's parameters.
    for c = 1:nProjectionConditions
        bootTargets{c} = (bootTargets{c} - muBoot) ./ sigmaBoot;
    end

    % Project each target condition onto the bootstrap PCA axes.
    for pc = 1:numPCsToPlot

        projectionError1{pc, boots} = ...
            signFlip * (bootTargets{1}' * U(:, pc));

        projectionError2{pc, boots} = ...
            signFlip * (bootTargets{2}' * U(:, pc));

        projectionError3{pc, boots} = ...
            signFlip * (bootTargets{3}' * U(:, pc));

        % Cosine similarity between conditions 1 and 2.
        % These windows are retained from the original analysis.
        vec1 = projectionError1{pc, boots};
        vec2 = projectionError2{pc, boots};

        if numel(vec1) >= max([preWindow postWindow])
            v1 = vec1(preWindow);
            v2 = vec2(preWindow);

            if norm(v1) > 0 && norm(v2) > 0
                cosine_angleBase(pc, boots) = ...
                    dot(v1, v2) / (norm(v1) * norm(v2));
            end

            v1 = vec1(postWindow);
            v2 = vec2(postWindow);

            if norm(v1) > 0 && norm(v2) > 0
                cosine_anglePost(pc, boots) = ...
                    dot(v1, v2) / (norm(v1) * norm(v2));
            end
        end
    end
end

%% Compare the last X ms of activity across all three conditions
% Extract the final X ms of each bootstrapped projection.
% Each bootstrap iteration contributes one mean value per condition.
% Compare all three conditions using pairwise rank-sum tests.
data1 = cell2mat(projectionError1(pcToPlot,:));
data1 = data1';
data2 = cell2mat(projectionError2(pcToPlot,:));
data2 = data2';
data3 = cell2mat(projectionError3(pcToPlot,:));
data3 = data3';

% Determine the time bins corresponding to the final X ms.
lastXms = xVector >= (xVector(end) - windowToCompare) & xVector <= xVector(end);

% Calculate the mean projection over the final 25 ms for each bootstrap.
% Rows = bootstrap iterations; columns = conditions.
lastXms = [
    mean(data1(:, lastXms), 2, 'omitnan'), ...
    mean(data2(:, lastXms), 2, 'omitnan'), ...
    mean(data3(:, lastXms), 2, 'omitnan')
];

% Remove bootstrap iterations with invalid values in any condition so
% that all pairwise comparisons use the same set of bootstrap iterations.
lastXms = lastXms(all(isfinite(lastXms), 2), :);

conditionLabels = {'Condition 1', 'Condition 2', 'Condition 3'};

% Display the mean and standard deviation of the bootstrap distributions.
for c = 1:3
    fprintf('%s: mean = %.4f, SD = %.4f, n = %d\n', ...
        conditionLabels{c}, ...
        mean(lastXms(:, c)), ...
        std(lastXms(:, c)), ...
        size(lastXms, 1));
end

%% Pairwise rank-sum tests
% Test all three condition pairs using two-sided Wilcoxon rank-sum tests.
% Apply a Bonferroni correction for the three pairwise comparisons.

conditionPairs = [1 2; 1 3; 2 3];
nComparisons = size(conditionPairs, 1);
pValues = nan(nComparisons, 1);

for k = 1:nComparisons

    condition1 = conditionPairs(k, 1);
    condition2 = conditionPairs(k, 2);

    pValues(k) = ranksum( ...
        lastXms(:, condition1), ...
        lastXms(:, condition2));

    fprintf('%s vs. %s: p = %.5f', ...
        conditionLabels{condition1}, ...
        conditionLabels{condition2}, ...
        pValues(k));

    % Bonferroni-adjusted significance threshold.
    if pValues(k) < 0.05 / nComparisons
        fprintf(' (significant after Bonferroni correction)\n');
    else
        fprintf(' (not significant after Bonferroni correction)\n');
    end
end

%% Plot bootstrapped projection trajectories
% Plot the mean projection and 95% confidence intervals for all three
% conditions in a standalone figure.

figure('Color', 'w', 'Position', [300 300 1200 350]);
hold on

% Plot the bootstrap mean trajectories with 95% confidence intervals.
plotSEM(data1, colors{1}, 1, xVector, 'c95', 1);
plotSEM(data2, colors{2}, 1, xVector, 'c95', 1);
plotSEM(data3, colors{3}, 1, xVector, 'c95', 1);

% Format the axes.
xline(0, '--');
xlim([xVector(1) xVector(end)]);
ylabel(sprintf('PC #%d', pcToPlot));
xlabel('Time (ms)');
set(gca, 'TickDir', 'out');

% Add a legend for the three error conditions.
legend({'Condition 1', 'Condition 2', 'Condition 3'}, ...
    'Location', 'best');

box off