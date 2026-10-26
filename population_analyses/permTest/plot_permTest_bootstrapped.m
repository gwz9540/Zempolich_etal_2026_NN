%% Bootstrap comparison of mi tails across three conditions
% Requires runPermShuffle.m and compute_percentile.m 
%
% User inputs: Change tailMode below to 'upper' or 'lower'.
%
% Panel A: Bootstrap distributions of the fraction of neurons in the tail.
% Panel B: Pairwise differences with bootstrap 95% CIs and
%          Holm-corrected paired permutation p-values.
 
% Author: Grant W. Zempolich
% Date: 2026-10-12

% clearvars -except spikes1BSL spikes2BSL spikes4BSL spikes5BSL spikes6BSL spikes7BSL sigCells3

rng(1);

%% user inputs

tailMode = 'upper';   % 'upper' = MI >= 97.5
                      % 'lower' = MI <= 2.5

nBoots = 1000;        % Use 1000+ for final analysis
nPerms = 1000;        % Inner permutations for runPermShuffle function
nPermTest = 10000;    % Pairwise permutation tests

conditionNames = {'Condition 1','Condition 2','Condition 3'};

colors = [
    0.20 0.45 0.70
    0.85 0.40 0.30
    0.25 0.60 0.45
];

%% define tail

switch lower(tailMode)
    case 'upper'
        threshold = 97.5;
        tailLabel = 'Upper tail (MI percentile >= 97.5)';
        fractionLabel = 'Neurons in upper tail (%)';
        filePrefix = 'MI_UpperTail';

    case 'lower'
        threshold = 2.5;
        tailLabel = 'Lower tail (MI percentile <= 2.5)';
        fractionLabel = 'Neurons in lower tail (%)';
        filePrefix = 'MI_LowerTail';

    otherwise
        error('tailMode must be either ''upper'' or ''lower''.');
end

%% define  data

Condition(1).name = conditionNames{1};
Condition(1).spikes1 = spikes6BSL(sigCells3 == 1); %post exit tone
Condition(1).spikes2 = spikes7BSL(sigCells3 == 1);

Condition(2).name = conditionNames{2};
Condition(2).spikes1 = spikes4BSL(sigCells3 == 1); % post entry tone
Condition(2).spikes2 = spikes5BSL(sigCells3 == 1);

Condition(3).name = conditionNames{3};
Condition(3).spikes1 = spikes1BSL(sigCells3 == 1); % pre exit tone
Condition(3).spikes2 = spikes2BSL(sigCells3 == 1);

nConditions = 3;
nNeurons = numel(Condition(1).spikes1);

for c = 1:nConditions
    assert(numel(Condition(c).spikes1) == nNeurons && ...
           numel(Condition(c).spikes2) == nNeurons, ...
           'All conditions must contain matching neuron counts.');
end

%% calculate MI percentiles

MI_observed = cell(1,nConditions);

for c = 1:nConditions

    fprintf('Calculating observed MI: %s\n',Condition(c).name);

    MI_observed{c} = runPermShuffle( ...
        Condition(c).spikes1, ...
        Condition(c).spikes2, ...
        nPerms);

    MI_observed{c} = MI_observed{c}(:);

end

% Function to identify the selected tail
if strcmpi(tailMode,'upper')
    inTail = @(x) x >= threshold;
else
    inTail = @(x) x <= threshold;
end

% Observed tail fractions
tailObserved = nan(1,nConditions);

for c = 1:nConditions
    valid = isfinite(MI_observed{c});
    tailObserved(c) = mean(inTail(MI_observed{c}(valid)));
end

%% bootstrap

tailBoot = nan(nBoots,nConditions);

for b = 1:nBoots
    disp(['Boot #',num2str(b)])
    if mod(b,100) == 0 || b == 1
        fprintf('Bootstrap %d / %d\n',b,nBoots);
    end

    % Resample neuron identities with replacement.
    % Use identical indices across conditions.
    idx = randi(nNeurons,nNeurons,1);

    for c = 1:nConditions

        spikes1 = Condition(c).spikes1(idx);
        spikes2 = Condition(c).spikes2(idx);

        MI_boot = runPermShuffle(spikes1,spikes2,nPerms);
        MI_boot = MI_boot(:);

        valid = isfinite(MI_boot);

        if any(valid)
            tailBoot(b,c) = mean(inTail(MI_boot(valid)));
        end

    end
end

%% bootstrap CIs

bootCI = nan(nConditions,2);

for c = 1:nConditions
    bootCI(c,:) = prctile(tailBoot(:,c),[2.5 97.5]);
end

fprintf('\nObserved fractions in selected tail:\n');

for c = 1:nConditions
    fprintf('%s: %.2f%%\n', ...
        Condition(c).name,100*tailObserved(c));
end

%% perm tests, pairwise

pairs = [1 2; 1 3; 2 3];
nPairs = size(pairs,1);

pRaw = nan(nPairs,1);
observedDiff = nan(nPairs,1);
bootDiff = nan(nBoots,nPairs);

for k = 1:nPairs

    c1 = pairs(k,1);
    c2 = pairs(k,2);

    % Paired neurons valid in both conditions
    valid = isfinite(MI_observed{c1}) & ...
            isfinite(MI_observed{c2});

    x = inTail(MI_observed{c1}(valid));
    y = inTail(MI_observed{c2}(valid));

    d = double(x)-double(y);
    observedDiff(k) = mean(d);

    % Paired bootstrap difference, in percentage points
    bootDiff(:,k) = 100 * ...
        (tailBoot(:,c1)-tailBoot(:,c2));

    nullDiff = zeros(nPermTest,1);

    for r = 1:nPermTest
        flip = 2*(rand(size(d)) > 0.5)-1;
        nullDiff(r) = mean(d.*flip);
    end

    % Two-sided permutation p-value
    pRaw(k) = (1+sum(abs(nullDiff) >= ...
        abs(observedDiff(k))))/(nPermTest+1);

    fprintf('Completed comparison %d / %d\n',k,nPairs);

end

%% correction

[~,order] = sort(pRaw);
pHolm = nan(size(pRaw));

for j = 1:nPairs
    pHolm(order(j)) = min(1, ...
        (nPairs-j+1)*pRaw(order(j)));
end
 
% [sortedP, order] = sort(pRaw);
% 
% pHolm = nan(size(pRaw));
% adjustedSorted = (nPairs - (1:nPairs)' + 1) .* sortedP;
% 
% % Enforce monotonicity of adjusted p-values
% adjustedSorted = cummax(adjustedSorted);
% 
% % Adjusted p-values cannot exceed 1
% adjustedSorted = min(1, adjustedSorted);
% 
% % Return values to the original comparison order
% pHolm(order) = adjustedSorted;

%% pairwise CIs for panel B

diffCI = nan(nPairs,2);

for k = 1:nPairs
    diffCI(k,:) = prctile(bootDiff(:,k),[2.5 97.5]);
end

Results = table( ...
    pairs(:,1),pairs(:,2), ...
    100*observedDiff,pRaw,pHolm, ...
    diffCI(:,1),diffCI(:,2), ...
    'VariableNames', ...
    {'ConditionA','ConditionB','Difference_pp', ...
     'Pvalue','Pvalue_Holm','CI95_Lower','CI95_Upper'});

fprintf('\nPairwise comparisons: %s\n',tailLabel);
disp(Results);

%% make figure

fig = figure('Color','w', ...
    'Units','inches', ...
    'Position',[1 1 3.4 1.9], ...
    'Renderer','painters');

tiledlayout(1,2, ...
    'TileSpacing','compact', ...
    'Padding','compact');

fontName = 'Arial';
fontSize = 7.5;

%% panel A - raw bootstrap distributions with mean and 95%

ax1 = nexttile;
hold(ax1,'on');

for c = 1:nConditions

    vals = 100*tailBoot(:,c);
    vals = vals(isfinite(vals));

    % Bootstrap distribution
    histogram(ax1,vals, ...
        'Normalization','pdf', ...
        'NumBins',20, ...
        'FaceColor',colors(c,:), ...
        'EdgeColor','none', ...
        'FaceAlpha',0.22);

end

% Calculate mean and percentile-based 95% bootstrap CI
bootMean = nan(1,nConditions);
bootCI95 = nan(nConditions,2);

for c = 1:nConditions

    vals = 100*tailBoot(:,c);
    vals = vals(isfinite(vals));

    bootMean(c) = mean(vals);
    bootCI95(c,:) = prctile(vals,[2.5 97.5]);

end

% Overlay mean and 95% CI on the histogram

yl = ylim(ax1);
yPositions = yl(2)*[0.88 0.76 0.64];

for c = 1:nConditions

    % 95% CI
    plot(ax1,bootCI95(c,:), ...
        [yPositions(c) yPositions(c)], ...
        '-', ...
        'Color',colors(c,:), ...
        'LineWidth',1.5);

    % CI end caps
    capHeight = yl(2)*0.025;

    plot(ax1,[bootCI95(c,1) bootCI95(c,1)], ...
        yPositions(c)+[-capHeight capHeight], ...
        '-', ...
        'Color',colors(c,:), ...
        'LineWidth',1);

    plot(ax1,[bootCI95(c,2) bootCI95(c,2)], ...
        yPositions(c)+[-capHeight capHeight], ...
        '-', ...
        'Color',colors(c,:), ...
        'LineWidth',1);

    % Bootstrap mean
    plot(ax1,bootMean(c),yPositions(c), ...
        'o', ...
        'MarkerSize',4, ...
        'MarkerFaceColor',colors(c,:), ...
        'MarkerEdgeColor','w', ...
        'LineWidth',0.5);

end

xlabel(ax1,'Tail neurons (%)');
ylabel(ax1,'Density');

title(ax1,'A','FontWeight','bold', ...
    'FontSize',8,'HorizontalAlignment','left');

xl = xlim(ax1);

for c = 1:nConditions
    text(ax1,xl(2),yPositions(c), ...
        conditionNames{c}, ...
        'Color',colors(c,:), ...
        'FontSize',6.5, ...
        'FontName',fontName, ...
        'HorizontalAlignment','right', ...
        'VerticalAlignment','bottom', ...
        'Clipping','on');
end

set(ax1, ...
    'FontName',fontName, ...
    'FontSize',fontSize, ...
    'TickDir','out', ...
    'LineWidth',0.7, ...
    'Box','off', ...
    'Layer','top');

%% panel B: paired diffs

ax2 = nexttile;
hold(ax2,'on');

xline(ax2,0,'--', ...
    'Color',[0.65 0.65 0.65], ...
    'LineWidth',0.7);

pairLabels = {
    'C1 - C2'
    'C1 - C3'
    'C2 - C3'
};

for k = 1:nPairs

    estimate = 100*observedDiff(k);

    errorbar(ax2,estimate,k, ...
        estimate-diffCI(k,1), ...
        diffCI(k,2)-estimate, ...
        'horizontal','o', ...
        'Color',[0.25 0.25 0.25], ...
        'MarkerFaceColor',colors(pairs(k,1),:), ...
        'MarkerEdgeColor','none', ...
        'MarkerSize',4, ...
        'LineWidth',1, ...
        'CapSize',3);
end

yticks(ax2,1:nPairs);
yticklabels(ax2,pairLabels);
set(ax2,'YDir','reverse');

xlabel(ax2,'Difference (percentage points)');

title(ax2,'B','FontWeight','bold', ...
    'FontSize',8,'HorizontalAlignment','left');

set(ax2, ...
    'FontName',fontName, ...
    'FontSize',fontSize, ...
    'TickDir','out', ...
    'LineWidth',0.7, ...
    'Box','off', ...
    'Layer','top');

ylim(ax2,[0.5 nPairs+0.5]);

xl = xlim(ax2);
xRange = max(diff(xl),eps);
xlim(ax2,[xl(1)-0.08*xRange, xl(2)+0.52*xRange]);

for k = 1:nPairs

    text(ax2,xl(2)+0.06*xRange,k, ...
        sprintf('%.3g',pHolm(k)), ...
        'FontName',fontName, ...
        'FontSize',7, ...
        'VerticalAlignment','middle', ...
        'HorizontalAlignment','left', ...
        'Clipping','off');
end

text(ax2,xl(2)+0.06*xRange,0.35,'Holm P', ...
    'FontName',fontName, ...
    'FontSize',6.5, ...
    'FontWeight','bold', ...
    'HorizontalAlignment','left', ...
    'VerticalAlignment','bottom', ...
    'Clipping','off');

% %% export
% 
% set([ax1 ax2],'Color','w');
% 
% exportgraphics(fig,[filePrefix '_Comparison.pdf'], ...
%     'ContentType','vector','BackgroundColor','white');
% 
% exportgraphics(fig,[filePrefix '_Comparison.tif'], ...
%     'Resolution',600,'BackgroundColor','white');
%% export data

cd('Z:XXX')

% exportgraphics(fig,[filePrefix '_Comparison.pdf'], ...
%     'ContentType','vector');
% 
% exportgraphics(fig,[filePrefix '_Comparison.tif'], ...
%     'Resolution',600);
% 
save([filePrefix '_Results.mat'], ...
    'tailBoot','tailObserved','bootCI', ...
    'observedDiff','diffCI','pRaw','pHolm','Results', ...
    'tailMode','threshold');

% fprintf('\nAnalysis complete: %s\n',tailLabel);