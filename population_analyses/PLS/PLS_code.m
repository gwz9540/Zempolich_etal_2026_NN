%% Partial-least-squares regression to identify similarity of various neural dimensions across recording conditions
%
% Expected data:
% psth_train    : 1x9 cell, neurons x timeBins
% psth_test     : 1x9 cell, same format
% psth_new_all  : struct with 9 fields (amp1..amp9)
%                  each field = {rec1 [N x T], rec2, ..., rec20}
% psth_new_all2 : struct, same format for testing split

close all;
clc;

psth_train = PSTHsToUseOG_M2_post_3Zone; % paper specific labels, can be replace with any data used as the training template
psth_test = PSTHsToUseOG_M2_post_3Zone;
psth_new_all = newPSTHsToPlotTrain_BrookeM2_3Zone;
psth_new_all2 = newPSTHsToPlotTrain_BrookeM2_3Zone;

PC_To_Regress = 1;
numSplits = 20;
numPLS = 1;
numPCs_new = 20;
numRecs = 20;
nConds = length(psth_train);

cmap = [linspace(1,0.3,9)', linspace(0.9,0,9)', linspace(1,0.5,9)'];

%%Extract planning axis from psth_train

Xtrain = [];
for amp = 1:nConds
    Xtrain = [Xtrain, psth_train{amp}]; % neurons x allTime
end

[Xtrain_z, mu_train, sigma_train] = zscore(Xtrain, 0, 2);
[coeff, ~] = pca(Xtrain_z');  % observations = time points
planning_axis = coeff(:,PC_To_Regress);

% Project training data onto planning axis
planning_proj_train = planning_axis' * Xtrain_z;  % 1 x total_time

%% sanity-check projection of psth_test

Xtest = [];
for amp = 1:nConds
    Xtest = [Xtest, psth_test{amp}];   % neurons x allTime
end

Xtest_z = (Xtest-mu_train) ./ sigma_train;

figure; hold on;
title('Sanity check: psth_test projection');
xlabel('Time (bins)');
ylabel('Projection');
set(gca,'FontSize',14);

for amp = 1:nConds
    XtestC = psth_test{amp};
    Xtest_zc = (XtestC - mu_train) ./ sigma_train;
    proj = planning_axis' * Xtest_zc;
    plot(proj, 'Color', cmap(amp,:), 'LineWidth', 2);
end

legend(arrayfun(@(x) sprintf('Amp %d',x),1:nConds,'UniformOutput',false));

% Project test data onto planning axis
planning_proj_train = planning_axis' * Xtest_z;  % 1 x total_time
disp('Extracted PC1 as planning axis and computed training projection.');

%% PLS on raw neuron PSTHs
ampFields = fieldnames(psth_new_all);
PLS_corr_CV = zeros(numSplits,1);
PLS_varexpl_CV = zeros(numSplits,1);

for n = 1:numSplits
    Xtrain_split = [];
    for a = 1:numel(ampFields)
        Xtrain_split = [Xtrain_split, psth_new_all.(ampFields{a}){n}]; % neurons x time
    end

    % Z-score neurons
    mu_split = mean(Xtrain_split,2);
    sigma_split = std(Xtrain_split,0,2);
    sigma_split(sigma_split==0) = 1; % avoid divide by zero
    Xtrain_split_z = (Xtrain_split - mu_split) ./ sigma_split;

    % Interpolate planning_proj_train to match training split time points
    % if different (for the paper they are the same to begin with)
    len_split = size(Xtrain_split_z,2);
    len_train = length(planning_proj_train);
    Ytrain_interp = interp1(linspace(0,1,len_train), planning_proj_train, linspace(0,1,len_split), 'linear')';

    % Check for zero variance in Y
    if std(Ytrain_interp) == 0
        warning('Split %d: planning projection has zero variance; returning NaN.', n);
        PLS_corr_CV(n) = NaN;
        PLS_varexpl_CV(n) = NaN;
        continue;
    end

    % PLS regression (observations = rows = time points)
    Xobs = Xtrain_split_z'; % time points x neurons
    Yobs = Ytrain_interp;   % time points x 1

    [~,~,~,~,beta] = plsregress(Xobs, Yobs, numPLS);
    Ypred = [ones(size(Xobs,1),1), Xobs] * beta;

    % Testing split
    Xtest_split = [];
    for a = 1:numel(ampFields)
        Xtest_split = [Xtest_split, psth_new_all2.(ampFields{a}){n}];
    end
    Xtest_split_z = (Xtest_split - mu_split) ./ sigma_split;
    Xtest_obs = Xtest_split_z'; % time points x neurons
    Ypred_test = [ones(size(Xtest_obs,1),1), Xtest_obs] * beta;

    % Interpolate planning_proj_train to test time points
    Ytest_interp = interp1(linspace(0,1,len_train), planning_proj_train, linspace(0,1,size(Xtest_obs,1)), 'linear')';

    % Align planning axis sign
    if corr(Ypred_test, Ytest_interp) < 0
        Ypred_test = -Ypred_test;
    end
    
    if std(Ytest_interp)==0
        PLS_corr_CV(n) = NaN;
        PLS_varexpl_CV(n) = NaN;
    else
        PLS_corr_CV(n) = corr(Ypred_test, Ytest_interp);
        PLS_varexpl_CV(n) = 1 - var(Ytest_interp - Ypred_test)/var(Ytest_interp);
    end

    fprintf('Split %d: PLS corr = %.3f, varExpl = %.3f\n', n, PLS_corr_CV(n), PLS_varexpl_CV(n));
end

%% Summary plots
figure;
subplot(2,1,1);
bar(PLS_corr_CV);
ylabel('Correlation'); title('CV PLS correlation across splits');

subplot(2,1,2);
bar(PLS_varexpl_CV);
ylabel('Variance Explained'); xlabel('Split');
title('CV Planning dimension detectability');
