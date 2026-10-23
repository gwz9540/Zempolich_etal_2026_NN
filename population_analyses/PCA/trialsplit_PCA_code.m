%% Test-train projected PCA of Neural Population Activity
%
% Description:
%   Fits PCA independently within each cross-validation fold using
%   training data, projects held-out test data, and visualizes neural
%   trajectories, explained variance, temporal projections, and
%   inter-condition distances.
%
%   Also calculates fold-level PC1 summaries and performs an exploratory
%   paired sign-flip permutation test for a prespecified condition contrast.
%
% Required workspace variables:
%   w1, w2
%       Start and end times in seconds.
%
%   newPSTHsToPlotTrain, newPSTHsToPlotTest
%       Structures with condition names as fields. Each field contains a
%       cell array indexed by test-train fold. Each cell must be a
%       [neurons x time bins] numeric matrix.
%
% Dependencies:
%   Statistics and Machine Learning Toolbox:
%       pca, pdist, squareform, tinv
%
%   Optional:
%       brewermap (used only for plotType = 2)
%
% Authors:
%   Grant W. Zempolich
%
% Last updated:
%   2026-10-23


%% User inputs

close all;
clc;

set(groot, ...
    'defaultAxesFontName', 'Arial', ...
    'defaultAxesFontSize', 12);

masterSignFlip = 1;  % Global projection sign: +1 or -1
plotType = 3;         % Color scheme: 1-6
numPCs = 10;          % Number of principal components

% Trajectory marker settings
trajStart = 1;
trialStart = 501;
trajEnd = 1501;
markerSize = 60;
lineWidth = 3;

% Figure settings
figurePosition = [200 200 270 270];

% Condition comparison settings
conditionA = 2;
conditionB = 3;
numPermutations = 100000;
rng(1);  % Reproducibility

startTimeMs = w1 * 1000;
endTimeMs = w2 * 1000;


%% Validate inputs

assert(isstruct(newPSTHsToPlotTrain) && ...
    isstruct(newPSTHsToPlotTest), ...
    'Training and test data must be structures.');

conditions = fieldnames(newPSTHsToPlotTrain);
numConditions = numel(conditions);

assert(numConditions >= 1, ...
    'At least one condition is required.');

assert(isequal(conditions, fieldnames(newPSTHsToPlotTest)), ...
    'Training and test structures must contain matching fields.');

numFolds = numel(newPSTHsToPlotTrain.(conditions{1}));

assert(numFolds >= 1, ...
    'At least one cross-validation fold is required.');

for c = 1:numConditions
    assert(numel(newPSTHsToPlotTrain.(conditions{c})) == numFolds, ...
        'Training fold counts differ across conditions.');

    assert(numel(newPSTHsToPlotTest.(conditions{c})) == numFolds, ...
        'Test fold counts differ across conditions.');
end

example = newPSTHsToPlotTrain.(conditions{1}){1};

assert(isnumeric(example) && ismatrix(example) && ~isempty(example), ...
    'Each data cell must contain a nonempty numeric matrix.');

[numNeurons, numTimeBins] = size(example);

assert(numPCs >= 3 && ...
    numPCs <= min(numNeurons, numConditions * numTimeBins), ...
    'numPCs must be at least 3 and within the available dimensions.');

assert(conditionA >= 1 && conditionA <= numConditions && ...
    conditionB >= 1 && conditionB <= numConditions && ...
    conditionA ~= conditionB, ...
    'Condition comparison indices must identify two distinct conditions.');

for c = 1:numConditions
    for f = 1:numFolds
        trainData = newPSTHsToPlotTrain.(conditions{c}){f};
        testData = newPSTHsToPlotTest.(conditions{c}){f};

        assert(isnumeric(trainData) && ismatrix(trainData) && ...
            size(trainData, 1) == numNeurons, ...
            'Training matrices must have the same number of neurons.');

        assert(isnumeric(testData) && ismatrix(testData) && ...
            size(testData, 1) == numNeurons, ...
            'Test matrices must have the same number of neurons.');

        assert(size(trainData, 2) == numTimeBins && ...
            size(testData, 2) == numTimeBins, ...
            'All data matrices must have the same number of time bins.');
    end
end

assert(all(cellfun(@(x) all(isfinite(x(:))), ...
    [cellfun(@(s) s, {}, 'UniformOutput', false)])), ...
    '');

% Use the evenly spaced time-axis assumption from the original script.
timeVec = linspace(startTimeMs, endTimeMs, numTimeBins);


%% Define condition colors

switch plotType
    case 1
        baseColors = [1 0.6 0.0980; 1 0 1; 0 1 1];

        assert(numConditions <= size(baseColors, 1), ...
            'Color scheme 1 supports at most three conditions.');

        colors = baseColors(1:numConditions, :);

    case 2
        % Requires brewermap.
        colors = flipud(brewermap(numConditions, 'RdYlBu'));

    case 3
        % Green gradient.
        colors = [linspace(0.8, 0, numConditions)', ...
                  linspace(1.0, 0.4, numConditions)', ...
                  linspace(0.8, 0, numConditions)'];

    case 4
        % Purple gradient.
        colors = [linspace(1.0, 0.3, numConditions)', ...
                  linspace(0.9, 0.0, numConditions)', ...
                  linspace(1.0, 0.5, numConditions)'];

    case 5
        % Magenta gradient.
        colors = [linspace(1.0, 0.3, numConditions)', ...
                  linspace(0.8, 0.0, numConditions)', ...
                  linspace(1.0, 0.3, numConditions)'];

    case 6
        % Light-to-dark green gradient.
        startColor = [0.95 0.98 0.93];
        endColor = [0.466 0.674 0.188];

        colors = [linspace(startColor(1), endColor(1), numConditions)', ...
                  linspace(startColor(2), endColor(2), numConditions)', ...
                  linspace(startColor(3), endColor(3), numConditions)'];

    otherwise
        error('plotType must be an integer from 1 to 6.');
end


%% PCA and test-set projection

% allProjFolds{condition, fold}: [time bins x PCs]
% explainedAll(fold, PC): variance explained in percent
% allProjFoldMeans(condition, fold): mean PC1 projection over time

allProjFolds = cell(numConditions, numFolds);
allProjFoldMeans = nan(numConditions, numFolds);

% FIX: Store only the requested number of components.
explainedAll = nan(numFolds, numPCs);

referenceCoefficients = [];

for f = 1:numFolds

    trainByCondition = cell(numConditions, 1);
    testByCondition = cell(numConditions, 1);

    for c = 1:numConditions
        trainByCondition{c} = ...
            newPSTHsToPlotTrain.(conditions{c}){f};

        testByCondition{c} = ...
            newPSTHsToPlotTest.(conditions{c}){f};
    end

    % Concatenate training data across conditions.
    trainStack = cat(2, trainByCondition{:});

    % Estimate normalization parameters from training data only.
    muTrain = mean(trainStack, 2);
    sigmaTrain = std(trainStack, 0, 2);
    sigmaTrain(sigmaTrain == 0) = 1;

    % Apply the same normalization to training and test data.
    trainZ = cellfun(@(x) (x - muTrain) ./ sigmaTrain, ...
        trainByCondition, 'UniformOutput', false);

    testZ = cellfun(@(x) (x - muTrain) ./ sigmaTrain, ...
        testByCondition, 'UniformOutput', false);

    % PCA observations are rows; neurons are columns.
    trainConcat = cat(2, trainZ{:});

    [coefficients, ~, ~, ~, explained] = ...
        pca(trainConcat', 'NumComponents', numPCs);

    assert(size(coefficients, 2) == numPCs, ...
        'PCA returned fewer components than requested.');

    explainedAll(f, :) = explained(1:numPCs)';

    if f == 1
        referenceCoefficients = coefficients;
    end

    % Project each held-out condition.
    for c = 1:numConditions

        projection = testZ{c}' * coefficients;

        % Align component signs with the first fold.
        for pc = 1:numPCs
            alignment = dot(coefficients(:, pc), ...
                referenceCoefficients(:, pc));

            if alignment < 0
                projection(:, pc) = -projection(:, pc);
            end
        end

        projection = masterSignFlip * projection;

        allProjFolds{c, f} = projection;

        allProjFoldMeans(c, f) = ...
            mean(projection(:, 1), 'omitnan');
    end
end


%% Determine common projection length

minLengthAll = inf;

for c = 1:numConditions
    for f = 1:numFolds
        minLengthAll = min(minLengthAll, ...
            size(allProjFolds{c, f}, 1));
    end
end

assert(isfinite(minLengthAll) && minLengthAll >= 1, ...
    'No valid projection time bins were found.');

minLengthAll = floor(minLengthAll);
timeVecTrunc = timeVec(1:minLengthAll);

assert(trajStart <= minLengthAll && ...
    trialStart <= minLengthAll && trajEnd <= minLengthAll, ...
    'Trajectory marker indices exceed the common projection length.');


%% Plot fold-averaged 3D neural trajectories

figure('Name', 'Neural trajectories', ...
    'Color', 'w', 'Position', figurePosition);

hold on;

for c = 1:numConditions

    foldTrajectories = nan(minLengthAll, 3, numFolds);

    for f = 1:numFolds
        foldTrajectories(:, :, f) = ...
            allProjFolds{c, f}(1:minLengthAll, 1:3);
    end

    meanTrajectory = mean(foldTrajectories, 3, 'omitnan');

    plot3(meanTrajectory(:, 1), meanTrajectory(:, 2), ...
        meanTrajectory(:, 3), ...
        'LineWidth', lineWidth, 'Color', colors(c, :));

    scatter3(meanTrajectory(trajStart, 1), ...
        meanTrajectory(trajStart, 2), meanTrajectory(trajStart, 3), ...
        markerSize, colors(c, :), 'filled');

    scatter3(meanTrajectory(trialStart, 1), ...
        meanTrajectory(trialStart, 2), meanTrajectory(trialStart, 3), ...
        160, colors(c, :), '*', 'LineWidth', 1.5);

    scatter3(meanTrajectory(trajEnd, 1), ...
        meanTrajectory(trajEnd, 2), meanTrajectory(trajEnd, 3), ...
        markerSize, colors(c, :));
end

xlabel('PC1');
ylabel('PC2');
zlabel('PC3');

set(gca, 'XTickLabel', [], 'YTickLabel', [], ...
    'ZTickLabel', [], 'LineWidth', 1);

grid on;
view(3);
axis tight;


%% Scree plot: variance explained across folds

meanExplained = mean(explainedAll, 1, 'omitnan');
nExplained = sum(~isnan(explainedAll), 1);

semExplained = std(explainedAll, 0, 1, 'omitnan') ./ ...
    sqrt(nExplained);

figure('Name', 'Cross-validated scree plot', ...
    'Color', 'w', 'Position', [500 500 350 250]);

bar(1:numPCs, meanExplained, ...
    'FaceColor', [0.2 0.5 0.8]);

hold on;

errorbar(1:numPCs, meanExplained, semExplained, ...
    'k.', 'LineWidth', 1);

xlabel('Principal component');
ylabel('Variance explained (%)');
title('Variance explained across folds');
xlim([0.5 numPCs + 0.5]);


%% PC time courses with 95% confidence intervals

% These intervals describe uncertainty across fold-level estimates.
% They are not guaranteed to have nominal coverage if folds are dependent.

figure('Name', 'PC time courses', ...
    'Color', 'w', 'Position', [100 100 1000 500]);

tiledlayout(2, ceil(numPCs / 2), ...
    'Padding', 'compact', 'TileSpacing', 'compact');

for pc = 1:numPCs

    nexttile;
    hold on;

    for c = 1:numConditions

        foldData = nan(minLengthAll, numFolds);

        for f = 1:numFolds
            foldData(:, f) = ...
                allProjFolds{c, f}(1:minLengthAll, pc);
        end

        nValid = sum(~isnan(foldData), 2);
        meanPC = mean(foldData, 2, 'omitnan');
        sdPC = std(foldData, 0, 2, 'omitnan');

        semPC = sdPC ./ sqrt(nValid);

        % Student's t critical value at each time point.
        tCritical = nan(minLengthAll, 1);
        validN = nValid >= 2;

        tCritical(validN) = tinv(0.975, nValid(validN) - 1);

        ciLower = meanPC - tCritical .* semPC;
        ciUpper = meanPC + tCritical .* semPC;

        % Shaded pointwise 95% intervals.
        fill([timeVecTrunc, fliplr(timeVecTrunc)], ...
            [ciUpper', fliplr(ciLower')], colors(c, :), ...
            'FaceAlpha', 0.2, 'EdgeColor', 'none');

        plot(timeVecTrunc, meanPC, ...
            'Color', colors(c, :), 'LineWidth', 1);
    end

    title(sprintf('PC %d', pc));
    xlabel('Time (ms)');
    ylabel('Projection');
    xlim([timeVecTrunc(1), timeVecTrunc(end)]);
    yline(0, '--');
end


%% Inter-condition distance matrix in PC1-PC3 space

centroids = nan(numConditions, 3);

for c = 1:numConditions

    foldTrajectories = nan(minLengthAll, 3, numFolds);

    for f = 1:numFolds
        foldTrajectories(:, :, f) = ...
            allProjFolds{c, f}(1:minLengthAll, 1:3);
    end

    meanTrajectory = mean(foldTrajectories, 3, 'omitnan');

    centroids(c, :) = mean(meanTrajectory, 1, 'omitnan');
end

distanceMatrix = squareform(pdist(centroids));

figure('Name', 'Inter-condition distances', ...
    'Color', 'w', 'Position', [500 500 350 300]);

imagesc(distanceMatrix);
axis square;
colorbar;
colormap(gca, parula);

xticks(1:numConditions);
yticks(1:numConditions);
xticklabels(conditions);
yticklabels(conditions);
xtickangle(45);

title('Centroid distance in PC1-PC3 space');


%% Mean PC1 projection by condition with 95% intervals

meanPC1 = mean(allProjFoldMeans, 2, 'omitnan');
sdPC1 = std(allProjFoldMeans, 0, 2, 'omitnan');
nPC1 = sum(~isnan(allProjFoldMeans), 2);

semPC1 = sdPC1 ./ sqrt(nPC1);

tCriticalPC1 = nan(numConditions, 1);
validPC1 = nPC1 >= 2;

tCriticalPC1(validPC1) = ...
    tinv(0.975, nPC1(validPC1) - 1);

ciLowerPC1 = meanPC1 - tCriticalPC1 .* semPC1;
ciUpperPC1 = meanPC1 + tCriticalPC1 .* semPC1;

figure('Name', 'Mean PC1 by condition', ...
    'Color', 'w', 'Position', [500 500 500 300]);

hold on;

for c = 1:numConditions

    bar(c, meanPC1(c), ...
        'FaceColor', colors(c, :), 'EdgeColor', 'none');

    if validPC1(c)
        errorbar(c, meanPC1(c), ...
            meanPC1(c) - ciLowerPC1(c), ...
            ciUpperPC1(c) - meanPC1(c), ...
            'k.', 'LineWidth', 1);
    end

    scatter(c, meanPC1(c), 25, colors(c, :), 'filled');
end

yline(0, '--');
xticks(1:numConditions);
xticklabels(conditions);
xtickangle(45);
ylabel('Mean PC1 projection');
xlim([0.5 numConditions + 0.5]);


%% linear trend across conditions

% Only interpret this regression if condition order represents a
% scientifically justified ordered predictor.

if numConditions >= 3

    conditionIndex = (1:numConditions)';
    valid = ~isnan(meanPC1);

    if sum(valid) >= 3

        trendModel = fitlm(conditionIndex(valid), meanPC1(valid));

        fprintf('\nExploratory condition trend:\n');
        fprintf('R-squared = %.4f\n', ...
            trendModel.Rsquared.Ordinary);

        fprintf('Slope = %.4f\n', ...
            trendModel.Coefficients.Estimate(2));

        fprintf('p-value = %.4g\n', ...
            trendModel.Coefficients.pValue(2));
    end
end

figure('Color','w','Position',[500 500 400 210]);

subplot(1,2,2);
hold on;

% Existing bar plot
makeBarPlot(data,colorsBarPlot,1,0.2,6,0,0);

ylim([-10 10]);
yticks([-10 0 10]);
xlim([0.5 nCats+0.5]);
xticks(1:numConditions);
yline(0,'--');

% Calculate mean for each condition
zonesMeans = cellfun(@(x) mean(x,'omitnan'), data);
xVals = (1:nCats)';

% Plot condition means
for c = 1:nCats
    scatter(xVals(c), zonesMeans(c), 30, ...
        colorsBarPlot{c}, 'filled');
end

% Linear regression across condition means
mdl = fitlm(xVals, zonesMeans(:));

% Plot trend line
xFit = linspace(1,nCats,100)';
yFit = predict(mdl,xFit);

plot(xFit,yFit,'k--','LineWidth',1.5);

% Regression statistics
R2 = mdl.Rsquared.Ordinary;
pSlope = mdl.Coefficients.pValue(2);

title(sprintf('R^2 = %.3f, p = %.3g',R2,pSlope), ...
    'FontSize',8);

%% Paired fold-level PC1 comparison with permutation p-value

% Compare each condition's time-averaged PC1 projection within the same
% fold. Time bins are not treated as independent replicates.

summaryA = allProjFoldMeans(conditionA, :)';
summaryB = allProjFoldMeans(conditionB, :)';

% Retain folds valid for both conditions.
valid = ~isnan(summaryA) & ~isnan(summaryB);

summaryA = summaryA(valid);
summaryB = summaryB(valid);

differences = summaryA - summaryB;
nPairs = numel(differences);

assert(nPairs >= 2, ...
    'At least two valid paired folds are required.');

% Observed mean difference.
observedDifference = mean(differences);
sdDifference = std(differences, 0);
seDifference = sdDifference / sqrt(nPairs);

% Conventional paired Student's t confidence interval.
tCritical = tinv(0.975, nPairs - 1);

ciLower = observedDifference - tCritical * seDifference;
ciUpper = observedDifference + tCritical * seDifference;

% Two-sided sign-flip permutation test.
observedStatistic = abs(observedDifference);

% Report stats
fprintf('\nPaired PC1 condition comparison\n');
fprintf('Condition A: %s\n', conditions{conditionA});
fprintf('Condition B: %s\n', conditions{conditionB});
fprintf('Valid paired folds: %d\n', nPairs);
fprintf('Mean difference (A - B): %.6f\n', observedDifference);
fprintf('95%% paired t CI: [%.6f, %.6f]\n', ciLower, ciUpper);

% Visualize fold-level paired summaries.
figure('Name', 'Paired PC1 condition comparison', ...
    'Color', 'w', 'Position', [500 500 400 300]);

hold on;

for k = 1:nPairs
    plot([1 2], [summaryA(k) summaryB(k)], ...
        '-o', 'Color', [0.65 0.65 0.65], ...
        'MarkerFaceColor', [0.65 0.65 0.65]);
end

scatter(ones(nPairs, 1), summaryA, 45, ...
    colors(conditionA, :), 'filled');

scatter(2 * ones(nPairs, 1), summaryB, 45, ...
    colors(conditionB, :), 'filled');

xlim([0.5 2.5]);
xticks([1 2]);
xticklabels({conditions{conditionA}, conditions{conditionB}});
ylabel('Mean PC1 projection');

title(sprintf('Paired comparison, permutation p = %.4g', ...
    pPermutation));

grid on;
