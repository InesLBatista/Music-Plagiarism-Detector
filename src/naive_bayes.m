% DONE 5: Multinomial Naive Bayes classifier for shingle-based feature sets.
% Can classify melodies when labeled training data is available.

function [predicted_labels, model, log_scores] = naive_bayes(train_data, train_labels, test_data, alpha)
    if nargin < 4
        alpha = 1;
    end
    if nargin < 3
        error('naive_bayes requires train_data, train_labels, and test_data.');
    end
    if iscell(train_data)
        [train_features, vocabulary] = shingles_to_feature_matrix(train_data);
        test_features = shingles_to_feature_matrix(test_data, vocabulary);
    else
        train_features = train_data;
        test_features = test_data;
        vocabulary = [];
    end

    validate_inputs(train_features, train_labels, test_features);
    model = train_multinomial_nb(train_features, train_labels, alpha, vocabulary);
    [predicted_labels, log_scores] = predict_multinomial_nb(model, test_features);
end

function model = train_multinomial_nb(features, labels, alpha, vocabulary)
    % Learns priors and feature likelihoods with Laplace smoothing.
    labels = labels(:);
    classes = unique(labels, 'stable');
    num_classes = numel(classes);
    num_features = size(features, 2);

    class_priors = zeros(1, num_classes);
    feature_log_probs = zeros(num_classes, num_features);

    for c = 1:num_classes
        class_mask = labels == classes(c);
        class_features = features(class_mask, :);
        class_priors(c) = sum(class_mask) / numel(labels);
        feature_counts = sum(class_features, 1);
        total_count = sum(feature_counts);
        probs = (feature_counts + alpha) ./ (total_count + alpha * num_features);
        feature_log_probs(c, :) = log(probs);
    end

    model.classes = classes;
    model.class_log_priors = log(class_priors);
    model.feature_log_probs = feature_log_probs;
    model.alpha = alpha;
    model.vocabulary = vocabulary;
end

function [predicted_labels, log_scores] = predict_multinomial_nb(model, features)
    % Computes log posterior scores and returns the highest scoring class.
    num_samples = size(features, 1);
    num_classes = numel(model.classes);
    log_scores = zeros(num_samples, num_classes);
    for c = 1:num_classes
        log_scores(:, c) = model.class_log_priors(c) + features * model.feature_log_probs(c, :)';
    end
    [~, best_idx] = max(log_scores, [], 2);
    predicted_labels = model.classes(best_idx);
end

function [features, vocabulary] = shingles_to_feature_matrix(shingle_sets, vocabulary)
    % Converts shingle hash sets into a count-based feature matrix.
    if nargin < 2
        all_shingles = [];
        for i = 1:numel(shingle_sets)
            all_shingles = [all_shingles, shingle_sets{i}(:)'];
        end
        vocabulary = unique(all_shingles);
    end

    features = zeros(numel(shingle_sets), numel(vocabulary));
    for i = 1:numel(shingle_sets)
        shingles = shingle_sets{i};
        for j = 1:numel(shingles)
            idx = find(vocabulary == shingles(j), 1);
            if ~isempty(idx)
                features(i, idx) = features(i, idx) + 1;
            end
        end
    end
end

function validate_inputs(train_features, train_labels, test_features)
    % Checks the minimum shape constraints for training and prediction.
    if size(train_features, 1) ~= numel(train_labels)
        error('Number of training rows must match number of labels.');
    end
    if size(train_features, 2) ~= size(test_features, 2)
        error('Train and test feature matrices must have the same number of columns.');
    end
    if any(train_features(:) < 0) || any(test_features(:) < 0)
        error('Multinomial Naive Bayes requires non-negative feature values.');
    end
end
