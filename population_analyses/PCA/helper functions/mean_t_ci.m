function [mu, ciLower, ciUpper, n] = mean_t_ci(x, dim)

if nargin < 2
    dim = 1;
end

n = sum(~isnan(x), dim);
mu = mean(x, dim, 'omitnan');

sampleSD = std(x, 0, dim, 'omitnan');
sem = sampleSD ./ sqrt(n);

criticalValue = nan(size(n));
valid = n >= 2;

criticalValue(valid) = tinv(0.975, n(valid) - 1);

ciLower = mu - criticalValue .* sem;
ciUpper = mu + criticalValue .* sem;

ciLower(~valid) = NaN;
ciUpper(~valid) = NaN;
end
