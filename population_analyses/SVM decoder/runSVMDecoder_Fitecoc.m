function [avgScore, CtoPlot] = runSVMDecoder_Fitecoc(data, trainingType, trainPer)
% runSVMDecoder_Master Trains and evaluates an SVM classifier to decode
%                      stimulus or condition identity from neural activity
%                      as used in Zempolich et al., 2026.
%
%   [avgScore, CtoPlot] = runSVMDecoder_Master(data, trainingType, trainPer)
%
%   INPUTS:
%       data         - Cell array containing neural activity measurements
%                      for each category or experimental condition.
%                      Each cell is organized as features (e.g., neurons)
%                      x trials.
%       trainingType - Specifies the training/testing strategy:
%                      1 = Leave-one-trial-out cross-validation.
%                      2 = Random train/test split.
%       trainPer     - Percentage of trials used for training when
%                      trainingType = 2 (e.g., 80 for an 80/20 split).
%
%   OUTPUTS:
%       avgScore - Mean classification accuracy across held-out trials
%                  for trainingType = 1, or classification accuracy on
%                  the held-out test set for trainingType = 2.
%       CtoPlot  - Row-normalized confusion matrix, with rows representing
%                  true categories and columns representing predicted
%                  categories. Values indicate the proportion of trials
%                  assigned to each predicted category.
%
%   METHOD:
%       Trials are balanced across categories by randomly selecting an
%       equal number of trials from each category. Neural activity is
%       standardized across features, and category labels are assigned
%       to each trial.
%
%       A multiclass error-correcting output codes (ECOC) classifier with
%       SVM learners is trained to predict category identity from neural
%       activity. Classification performance is evaluated using either
%       leave-one-trial-out cross-validation or a random train/test split.
%
%   Built in MATLAB functions required/Dependencies: fitcecoc, predict, confusionmat

% Author:       Grant W. Zempolich
% Created:      2025-06-30
% Last updated: 2026-10-13

%% Balance the number of trials across categories

% Determine the number of categories and the number of trials available
% for each category.
numCats = length(data);
sizesOfData = [];

for n = 1:numCats
    sizesOfData(n) = size(data{n}, 2);
end

% Use the smallest category size to ensure that all categories contribute
% the same number of trials to the decoding analysis.
minTrials = min(sizesOfData);

% Randomly select minTrials trials from each category.
% This prevents categories with more trials from contributing
% disproportionately to classifier training and evaluation.
newData = {};

for n = 1:numCats
    currentData = data{n};

    % Randomly sample trials without replacement.
    dataIdxs = randperm(size(currentData, 2), minTrials);

    newData{n} = currentData(:, dataIdxs);
end

% Concatenate all categories into a single trial-by-feature matrix.
% Each row represents one trial and each column represents one feature
% (e.g., the activity of an individual neuron).
newData = cell2mat(newData);
newData = newData';

%% Standardize neural activity

% Z-score each feature across all selected trials.
% This places features on comparable scales by centering and scaling
% their activity values.
sigma = std(newData);

% Prevent division by zero for features with zero variance.
sigma(sigma == 0) = 1;

newData = (newData - mean(newData)) ./ sigma;

% Optional dimensionality reduction using principal component analysis:
% [coeff, score, latent, tsquared, explained, mu] = ...
%     pca(newData, 'NumComponents', 10);

% Optional normalization of individual feature columns:
% for l = 1:size(newData, 2)
%     newData(:, l) = normalize(newData(:, l));
% end

%% Generate category labels

% Assign an integer label to each trial based on its category.
% Labels correspond to the order of categories in the input cell array:
% category 1 -> label 1, category 2 -> label 2, etc.
outcomeLabelVector = {};

for n = 1:numCats
    outcomeLabelVector{n} = n * ones(1, minTrials);
end

% Combine category labels into a column vector aligned with newData.
outcomeLabelVector = cell2mat(outcomeLabelVector);
outcomeLabelVector = outcomeLabelVector';

%% Initialize classifier performance outputs

% Store confusion matrices from individual cross-validation folds.
Cs = {};

% Store classification accuracy for each fold or evaluation.
all_Scores = [];

%% Training strategy 1: Leave-one-trial-out cross-validation

if trainingType == 1

    % Iteratively hold out one trial for testing while using all remaining
    % trials to train the classifier.
    for i = 1:size(newData, 1)

        trialsVector = 1:size(newData, 1);

        % Define training and test trial indices for the current fold.
        trialsToFit = trialsVector(1:end ~= i);
        trialsToTest = i;

        % Separate neural activity and labels into training and test sets.
        dataToFit = newData(trialsToFit, :);
        labelToFit = outcomeLabelVector(trialsToFit);

        dataToTest = newData(trialsToTest, :);
        labelToTest = outcomeLabelVector(trialsToTest);

        % Train a multiclass ECOC classifier using SVM learners.
        % The 'allpairs' coding scheme uses pairwise class comparisons.
        mdl = fitcecoc(dataToFit, labelToFit, 'Coding', 'allpairs');

        % Predict the category of the held-out trial.
        pred = predict(mdl, dataToTest);

        % Calculate classification accuracy for this fold.
        % Accuracy is 1 when the predicted label matches the true label
        % and 0 otherwise.
        score = length(find([pred - labelToTest] == 0)) / length(pred);

        % Generate a confusion matrix using the predefined category order.
        C = confusionmat(labelToTest, pred, 'Order', 1:numCats);

        % Store the confusion matrix and classification accuracy.
        Cs{i} = C;
        all_Scores(i) = score;

        % Calculate mean classification accuracy across completed folds.
        avgScore = mean(all_Scores);

        % Average confusion matrices across folds.
        % Each fold contributes equally to the average.
        meanCs = {mean(cat(3, Cs{:}), 3)};
        meanScores = mean(all_Scores);
        meanCs = cell2mat(meanCs);

        % Normalize each row by its total to obtain the proportion of
        % trials from each true category assigned to each predicted class.
        CtoPlot = meanCs ./ repmat(sum(meanCs')', 1, numCats);

    end

%% Training strategy 2: Random train/test split

elseif trainingType == 2

    % Generate indices for all trials in the balanced dataset.
    trialsVector = 1:size(newData, 1);

    % Randomly shuffle trial indices before splitting into training
    % and testing sets.
    randTrials = randperm(length(trialsVector));

    % Determine the number of trials assigned to the training set.
    % trainPer is expressed as a percentage (e.g., 80 for 80%).
    lastTrainTrial = round((trainPer / 100) * length(randTrials));

    % Assign the specified proportion of trials to training.
    trialsToFit = trialsVector(randTrials(1:lastTrainTrial));

    % Use the remaining trials for testing.
    trialsToTest = trialsVector(randTrials(lastTrainTrial + 1:end));

    % Extract neural activity and corresponding category labels.
    dataToFit = newData(trialsToFit, :);
    labelToFit = outcomeLabelVector(trialsToFit);

    dataToTest = newData(trialsToTest, :);
    labelToTest = outcomeLabelVector(trialsToTest);

    % Train the multiclass ECOC classifier using the training trials.
    mdl = fitcecoc(dataToFit, labelToFit);

    % Predict category labels for held-out test trials.
    pred = predict(mdl, dataToTest);

    % Calculate classification accuracy as the proportion of correctly
    % classified test trials.
    score = length(find([pred - labelToTest] == 0)) / length(pred);

    % Generate the confusion matrix, preserving category order.
    C = confusionmat(labelToTest, pred, 'Order', 1:numCats);

    % Report overall classification accuracy on the held-out test set.
    avgScore = score;

    % Normalize the confusion matrix by true category to obtain
    % per-category proportions of predicted labels.
    CtoPlot = C ./ repmat(sum(C')', 1, numCats);

end

end