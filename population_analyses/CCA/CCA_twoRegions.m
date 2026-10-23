%% CCA - shared Subspace Analysis Between Two Brain Regions
% Regions:
%   A = AC
%   B = M2
%
% Expected data:
%   PSTHsToUseOG_ACFULLNEW and PSTHsToUseOG_M2FULLNEW are cell arrays
%   containing PSTHs that can be concatenated into neuron x time data.
%   Replace with new data as needed.
%
% Analysis:
%   1. Load and organize PSTHs.
%   2. Z-score each neuron's activity across time.
%   3. Perform PCA separately for each region.
%   4. Estimate delays between PCA projections.
%   5. Perform CCA on the PCA projections.
%   6. Leave-one-condition-out cross-validated prediction.
%   7. Plot shared trajectories and latent dynamics.
%   8. Examine PCA/CCA alignment and inter-region PC similarity.

clear;
clc;
close all;

%% SETTINGS AND DATA

%dataDir = 'Z:\Users\Grant\CCA_Analysis'; % user specific directory 

%load(fullfile(dataDir, 'PSTHsToUseOG_ACFULLNEW.mat')); % comment out and replace with data
%load(fullfile(dataDir, 'PSTHsToUseOG_M2FULLNEW.mat')); % comment out and replace with data

% Dimensions
T = 1501;                 % Time samples per condition
C = 9;                    % Number of conditions
nCats = C;

xVector = -500:1000;      % Time axis in ms
dimToPlot = 1;             % CCA dimension used in overlaid time-course plot

% PCA dimensions, precalculated 
nPCsAC = 15;
nPCsM2 = 17;

% Number of shared dimensions to analyze and plot
d = 4;

% Delay analysis
numComponentsToCheck = 2;
maxLag = 200;              % Maximum lag in samples
Fs = 1000;                 % Samples per second for 1-ms bins

% Alignment analysis
numPCsToTest = 10;

% Plot settings
lineW = 2;
markerSize = 35;
fontName = 'Arial';
fontSize = 8;

%% pre-organize data
% Convert the cell arrays to matrices.
% Expected orientation: neurons x (time samples * conditions).
PSTHsToUseOG_ACNew = cell2mat(PSTHsToUseOG_ACFULLNEW);
PSTHsToUseOG_M2New = cell2mat(PSTHsToUseOG_M2FULLNEW);

% Check expected dimensions.
assert(size(PSTHsToUseOG_ACNew, 2) == T*C, ...
    'AC data must have T*C columns.');

assert(size(PSTHsToUseOG_M2New, 2) == T*C, ...
    'M2 data must have T*C columns.');

% Z-score each neuron's activity across time.
% Constant neurons can produce NaNs; handle those explicitly.
[X_A, mu_A, sig_A] = zscore(PSTHsToUseOG_ACNew, 0, 2);
[X_B, mu_B, sig_B] = zscore(PSTHsToUseOG_M2New, 0, 2);

X_A(~isfinite(X_A)) = 0;
X_B(~isfinite(X_B)) = 0;

% PCA expects observations x variables.
% Here, observations are time samples and variables are neurons.
X_A = X_A';
X_B = X_B';

%% PCA pre-processing

nPCsAC = min(nPCsAC, min(size(X_A))-1);
nPCsM2 = min(nPCsM2, min(size(X_B))-1);

[coeff_A, score_A, latent_A, ~, explained_A] = ...
    pca(X_A, 'NumComponents', nPCsAC);

[coeff_B, score_B, latent_B, ~, explained_B] = ...
    pca(X_B, 'NumComponents', nPCsM2);

fprintf('AC variance explained by retained PCs: %.2f%%\n', ...
    sum(explained_A));

fprintf('M2 variance explained by retained PCs: %.2f%%\n', ...
    sum(explained_B));

%% ESTIMATE DELAYS BETWEEN RAW PCA PROJECTIONS
%
% Positive lag means B is delayed relative to A under the
% xcorr(ts_B, ts_A, ...) convention used here.
%
% These are descriptive lag estimates, not causal estimates.

delayMatrixPCA = nan(C, numComponentsToCheck);

for c = 1:C

    idx = (c-1)*T + (1:T);

    for dim = 1:numComponentsToCheck

        ts_A = score_A(idx, dim);
        ts_B = score_B(idx, dim);

        % Remove each signal's mean.
        ts_A = ts_A - mean(ts_A);
        ts_B = ts_B - mean(ts_B);

        % Skip constant or invalid signals.
        if std(ts_A) == 0 || std(ts_B) == 0 || ...
                any(~isfinite(ts_A)) || any(~isfinite(ts_B))
            continue;
        end

        [xc, lags] = xcorr(ts_B, ts_A, maxLag, 'coeff');

        % Select the lag with the largest positive correlation.
        [~, maxIdx] = max(xc);

        delayMatrixPCA(c, dim) = lags(maxIdx) / Fs * 1000;

    end
end

avgDelayPerComponentPCA = mean(delayMatrixPCA, 1, 'omitnan');
avgDelayAllPCA = mean(delayMatrixPCA(:), 'omitnan');
stdDelayAllPCA = std(delayMatrixPCA(:), 0, 'omitnan');

nValidDelays = sum(isfinite(delayMatrixPCA(:)));
semDelayAllPCA = stdDelayAllPCA / sqrt(max(nValidDelays, 1));

fprintf('\nRaw PCA delay estimates:\n');
fprintf('Mean delay per component (ms):\n');
disp(avgDelayPerComponentPCA);

fprintf('Overall mean delay: %.2f ms\n', avgDelayAllPCA);
fprintf('Overall SD: %.2f ms\n', stdDelayAllPCA);
fprintf('Overall SEM: %.2f ms\n', semDelayAllPCA);

% Optional delay heatmap.
figure('Color', 'w');
imagesc(delayMatrixPCA);
axis tight;
colorbar;
xlabel('PCA component');
ylabel('Condition');
title('Delay between AC and M2 PCA projections (ms)');
set(gca, 'XTick', 1:numComponentsToCheck);

%% Main CCA
%
% This full-data CCA is used for descriptive visualization.
% Prediction below fits a separate PCA/CCA model
% within each training fold.

[A_cca, B_cca, r, U, V] = canoncorr(score_A, score_B);

d = min([d, size(U,2), size(V,2)]);

shared_A = U(:,1:d);
shared_B = V(:,1:d);

fprintf('\nCanonical correlations:\n');
disp(r(1:min(d, numel(r)))');

%% Predict region A from B
% Leave-one-outout cross-validation.
% PCA and CCA are refitted within each fold to avoid data leakage.
%
% Assumes:
%   X_A, X_B: [neurons x time samples]
%   T: time samples per condition
%   C: number of conditions
%   nPCsAC, nPCsM2: requested PCA dimensions
%   d: requested number of canonical dimensions

% Organize sample indices by condition.
X_A = X_A';
X_B = X_B';

assert(size(X_A,2) == T*C && size(X_B,2) == T*C, ...
    'X_A and X_B must contain T*C time samples.');

idx_all = reshape(1:(T*C), T, C);

pred_r2 = nan(C,1);
corr_cv = nan(C,1);

for c = 1:C

    fprintf('Cross-validation fold %d/%d\n', c, C);

    % Hold out one complete condition.
    test_idx = idx_all(:,c);
    train_conditions = setdiff(1:C,c);
    train_idx = idx_all(:,train_conditions);
    train_idx = train_idx(:);
    test_idx = test_idx(:);
    
    % Extract samples (observations x neurons)
    A_train_raw = X_A(:,train_idx)';
    B_train_raw = X_B(:,train_idx)';
    A_test_raw  = X_A(:,test_idx)';
    B_test_raw  = X_B(:,test_idx)';

    % Fit PCA using training data only.
    nPCA_A = min([nPCsAC, size(A_train_raw,1)-1, ...
        size(A_train_raw,2)]);
    nPCA_B = min([nPCsM2, size(B_train_raw,1)-1, ...
        size(B_train_raw,2)]);

    [coeffA,~,~,~,~,muA] = pca(A_train_raw, ...
        'NumComponents',nPCA_A);
    [coeffB,~,~,~,~,muB] = pca(B_train_raw, ...
        'NumComponents',nPCA_B);

    % Project training and held-out samples into their own PCA spaces.
    scoreA_train = (A_train_raw-muA)*coeffA;
    scoreB_train = (B_train_raw-muB)*coeffB;

    scoreA_test = (A_test_raw-muA)*coeffA;
    scoreB_test = (B_test_raw-muB)*coeffB;

    % Fit CCA on training samples only.
    [A_cv,B_cv,r_cv] = canoncorr(scoreA_train,scoreB_train);

    % Use only canonical dimensions available in this fold.
    d_cv = min([d, size(A_cv,2), size(B_cv,2)]);

    if d_cv < 1
        warning('Fold %d has no valid canonical dimensions.',c);
        continue;
    end

    % Explicit dimension checks prevent matrix multiplication errors
    assert(size(scoreA_train,2) == size(A_cv,1), ...
        'Region A PCA scores do not match CCA coefficient rows.');
    assert(size(scoreB_train,2) == size(B_cv,1), ...
        'Region B PCA scores do not match CCA coefficient rows.');

    % Canonical projections
    U_train = scoreA_train * A_cv(:,1:d_cv);
    V_train = scoreB_train * B_cv(:,1:d_cv);

    U_test = scoreA_test * A_cv(:,1:d_cv);
    V_test = scoreB_test * B_cv(:,1:d_cv);

    % Fit linear mapping from Region A to Region B using training data
    beta = [ones(size(U_train,1),1), U_train] \ V_train;

    % Predict held-out Region B canonical projections.
    V_pred = [ones(size(U_test,1),1), U_test] * beta;

    % Compute held-out R-squared per canonical dimension
    ss_res = sum((V_test-V_pred).^2,1);
    ss_tot = sum((V_test-mean(V_test,1)).^2,1);

    valid_dims = ss_tot > eps;

    if any(valid_dims)
        r2_dims = 1 - ss_res(valid_dims)./ss_tot(valid_dims);
        pred_r2(c) = mean(r2_dims);
    end

    % Correlation between predicted and actual held-out projections
    pred_flat = V_pred(:);
    true_flat = V_test(:);

    if std(pred_flat) > 0 && std(true_flat) > 0
        corr_cv(c) = corr(pred_flat,true_flat);
    end
end

fprintf('\nMean leave-one-condition-out R^2: %.3f\n', ...
    mean(pred_r2,'omitnan'));

fprintf('Mean held-out prediction correlation: %.3f\n', ...
    mean(corr_cv,'omitnan'));

disp(table((1:C)',pred_r2,corr_cv, ...
    'VariableNames',{'Condition','Predicted_R2','PredictionCorrelation'}));

% Green gradient for region A.
startColorA = [0.80 1.00 0.80];
endColorA   = [0.00 0.40 0.00];

colors1 = [ ...
    linspace(startColorA(1), endColorA(1), C)', ...
    linspace(startColorA(2), endColorA(2), C)', ...
    linspace(startColorA(3), endColorA(3), C)' ];

% Purple gradient for region B.
startColorB = [1.00 0.80 1.00];
endColorB   = [0.40 0.10 0.60];

colors2 = [ ...
    linspace(startColorB(1), endColorB(1), C)', ...
    linspace(startColorB(2), endColorB(2), C)', ...
    linspace(startColorB(3), endColorB(3), C)' ];

% Mixed colors for combined trajectories.
colorsMaster = (colors1 + colors2) / 2;

%% plot shared-CCA subspace trajs
% These trajectories use the full-data CCA model

figure('Color', 'w', 'Position', [200 200 450 400]);
hold on;

for c = 1:C

    idx = (c-1)*T + (1:T);

    trajA = shared_A(idx,:);
    trajB = shared_B(idx,:);
    trajMean = (trajA + trajB) / 2;

    % Plot AC and M2 separately.
    plot3(trajA(:,1), trajA(:,2), trajA(:,3), ...
        '-', 'Color', colors1(c,:), 'LineWidth', lineW);

    plot3(trajB(:,1), trajB(:,2), trajB(:,3), ...
        '-.', 'Color', colors2(c,:), 'LineWidth', lineW);

    % Mark start, middle, and end of each trajectory.
    trialStart = 1;
    trialMid = min(501, T);
    trialEnd = T;

    scatter3(trajA(trialStart,1), trajA(trialStart,2), ...
        trajA(trialStart,3), markerSize, colors1(c,:), 'filled');

    scatter3(trajA(trialMid,1), trajA(trialMid,2), ...
        trajA(trialMid,3), 100, colors1(c,:), '*', 'LineWidth', 1.5);

    scatter3(trajA(trialEnd,1), trajA(trialEnd,2), ...
        trajA(trialEnd,3), markerSize, colors1(c,:));

    scatter3(trajB(trialStart,1), trajB(trialStart,2), ...
        trajB(trialStart,3), markerSize, colors2(c,:), 'filled');

    scatter3(trajB(trialMid,1), trajB(trialMid,2), ...
        trajB(trialMid,3), 100, colors2(c,:), '*', 'LineWidth', 1.5);

    scatter3(trajB(trialEnd,1), trajB(trialEnd,2), ...
        trajB(trialEnd,3), markerSize, colors2(c,:));

end

xlabel('CCA dimension 1');
ylabel('CCA dimension 2');
zlabel('CCA dimension 3');
title('Shared-subspace trajectories');
view(3);
grid on;
box off;

%% plot latents by condition 
figure('Color', 'w', 'Position', [200 200 1400 220]);

for c = 1:C

    idx = (c-1)*T + (1:T);

    subplot(1,C,c);

    plot(xVector, shared_A(idx,dimToPlot), ...
        '-', 'Color', colors1(c,:), 'LineWidth', lineW);
    hold on;

    plot(xVector, shared_B(idx,dimToPlot), ...
        '-.', 'Color', colors2(c,:), 'LineWidth', lineW);

    title(sprintf('Condition %d', c));
    xlabel('Time (ms)');

    if c == 1
        ylabel(sprintf('CCA dimension %d', dimToPlot));
    end

    xticks(-500:500:1000);
    box off;
end

% Combined view of all conditions.
figure('Color', 'w', 'Position', [300 300 500 350]);
hold on;

for c = 1:C

    idx = (c-1)*T + (1:T);

    plot(xVector, shared_A(idx,dimToPlot), ...
        '-', 'Color', colors1(c,:), 'LineWidth', 1.2);

    plot(xVector, shared_B(idx,dimToPlot), ...
        '-.', 'Color', colors2(c,:), 'LineWidth', 1.2);

end

xlabel('Time (ms)');
ylabel(sprintf('CCA dimension %d', dimToPlot));
xlim([xVector(1), xVector(end)]);
box off;

%% Original PCA axis alignment with single CCA dims
%
% Measures how much each PCA basis vector contributes to each
% canonical axis. The calculation uses the CCA coefficient matrices
% in PCA-score coordinates.

numPCsAC = min(numPCsToTest, size(A_cca,1));
numPCsM2 = min(numPCsToTest, size(B_cca,1));
numCCA = min(d, size(A_cca,2));

figure('Color', 'w', 'Position', [200 200 1000 500]);

for ccaDim = 1:numCCA

    % AC contribution of each PCA-score coordinate to this CCA axis
    vA = A_cca(:,ccaDim);
    vB = B_cca(:,ccaDim);

    % Normalize so squared components sum to 1
    vA = vA / max(norm(vA), eps);
    vB = vB / max(norm(vB), eps);

    varA = vA(1:numPCsAC).^2 * 100;
    varB = vB(1:numPCsM2).^2 * 100;

    subplot(2, numCCA, ccaDim);
    hold on;

    plot(1:numPCsAC, varA, '-o', ...
        'Color', colors1(end,:), 'MarkerSize', 3);

    plot(1:numPCsM2, varB, '-s', ...
        'Color', colors2(max(1,round(C/2)),:), 'MarkerSize', 3);

    xlabel('PCA-score coordinate');
    ylabel('Squared loading (%)');
    title(sprintf('CCA dimension %d', ccaDim));
    box off;

    % Angular difference between each PCA coordinate vector and
    % the corresponding canonical axis.
    % The angle is calculated in the same coordinate space
    anglesA = nan(numPCsAC,1);
    anglesB = nan(numPCsM2,1);

    for pc = 1:numPCsAC
        e = zeros(size(A_cca,1),1);
        e(pc) = 1;
        anglesA(pc) = acosd(min(1, max(-1, abs(dot(e,vA)))));
    end

    for pc = 1:numPCsM2
        e = zeros(size(B_cca,1),1);
        e(pc) = 1;
        anglesB(pc) = acosd(min(1, max(-1, abs(dot(e,vB)))));
    end

    subplot(2, numCCA, ccaDim + numCCA);
    hold on;

    plot(1:numPCsAC, anglesA, '-o', ...
        'Color', colors1(end,:), 'MarkerSize', 3);

    plot(1:numPCsM2, anglesB, '-s', ...
        'Color', colors2(max(1,round(C/2)),:), 'MarkerSize', 3);

    xlabel('PCA coordinate');
    ylabel('Angle (degrees)');
    title(sprintf('CCA dimension %d', ccaDim));
    box off;

end

%% exploring similarity between original PCA time series

nCommonPCs = min([numPCsToTest, size(score_A,2), size(score_B,2)]);

cosSimilarity = nan(nCommonPCs,1);
anglesDeg = nan(nCommonPCs,1);

for pc = 1:nCommonPCs

    a = score_A(:,pc);
    b = score_B(:,pc);

    valid = isfinite(a) & isfinite(b);
    a = a(valid);
    b = b(valid);

    if numel(a) < 2 || norm(a) == 0 || norm(b) == 0
        continue;
    end

    % Sign align based on correlation
    if corr(a,b) < 0
        b = -b;
    end

    a = a / norm(a);
    b = b / norm(b);

    cosSimilarity(pc) = max(-1, min(1, dot(a,b)));
    anglesDeg(pc) = acosd(cosSimilarity(pc));

end

figure('Color', 'w', 'Position', [300 300 250 200]);

plot(1:nCommonPCs, cosSimilarity, '-o', ...
    'LineWidth', 1.5, ...
    'Color', colorsMaster(round((C+1)/2),:), ...
    'MarkerFaceColor', colorsMaster(round((C+1)/2),:), ...
    'MarkerSize', 4);

yline(0, '--k');
xlabel('PC index');
ylabel('Cosine similarity');
xlim([1 nCommonPCs]);
ylim([-1 1]);
box off;

%% optional dark background 

figure('Color', 'k', 'Position', [200 200 450 400]);
ax = axes;
hold(ax, 'on');
set(ax, 'Color', 'k');

for c = 1:C

    idx = (c-1)*T + (1:T);

    trajMean = (shared_A(idx,1:3) + shared_B(idx,1:3)) / 2;

    plot3(trajMean(:,1), trajMean(:,2), trajMean(:,3), ...
        '-', 'Color', colorsMaster(c,:), 'LineWidth', lineW);

    trialStart = 1;
    trialMid = min(501,T);
    trialEnd = T;

    scatter3(trajMean(trialStart,1), trajMean(trialStart,2), ...
        trajMean(trialStart,3), markerSize, colorsMaster(c,:), 'filled');

    scatter3(trajMean(trialMid,1), trajMean(trialMid,2), ...
        trajMean(trialMid,3), 100, colorsMaster(c,:), '*', 'LineWidth', 1.5);

    scatter3(trajMean(trialEnd,1), trajMean(trialEnd,2), ...
        trajMean(trialEnd,3), markerSize, colorsMaster(c,:));

end

ax.XColor = 'w';
ax.YColor = 'w';
ax.ZColor = 'w';
ax.GridColor = 'w';
ax.LineWidth = 1;
ax.FontSize = 10;

xlabel('CCA dimension 1', 'Color', 'w');
ylabel('CCA dimension 2', 'Color', 'w');
zlabel('CCA dimension 3', 'Color', 'w');

set(ax, 'XTickLabel', [], 'YTickLabel', [], 'ZTickLabel', []);

grid on;
view(3);
box off;
