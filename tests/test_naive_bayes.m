test_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(test_dir, '..', 'src'));

% Numeric feature matrix test: class 1 has feature 1, class 2 has feature 2.
train_data = [
    4, 0;
    3, 1;
    0, 4;
    1, 3
];
train_labels = [1; 1; 2; 2];
test_data = [
    5, 0;
    0, 5
];

[predicted_labels, model, log_scores] = naive_bayes(train_data, train_labels, test_data);

assert(isequal(predicted_labels(:), [1; 2]));
assert(numel(model.classes) == 2);
assert(size(log_scores, 1) == 2);

% Cell-array shingle input test: verifies automatic shingle vocabulary creation.
train_shingles = {
    [10, 10, 20], ...
    [10, 20], ...
    [99, 99, 100], ...
    [99, 100]
};
test_shingles = {
    [10, 20], ...
    [99, 100]
};

[cell_predictions, cell_model] = naive_bayes(train_shingles, train_labels, test_shingles);

assert(isequal(cell_predictions(:), [1; 2]));
assert(~isempty(cell_model.vocabulary));

disp('naive bayes tests passed');
