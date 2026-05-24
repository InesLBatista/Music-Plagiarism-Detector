% DONE: Generate shingles over explicit (melodic_interval, quantized_duration) pairs.
% Unlike the older combined shingle function, k = 8 means 8 musical pairs.

function shingle_set = get_interval_duration_shingle_set(sequence, k, duration_scale)
%GET_INTERVAL_DURATION_SHINGLE_SET Hash shingles made of k interval-duration pairs.
%   shingle_set = get_interval_duration_shingle_set(sequence, 8) receives an
%   Nx2 matrix [interval, quantized_duration] and returns unique hashes for
%   every sliding window of 8 pairs.

    % Default window size follows the "8-note" idea, but here each element is
    % a full pair: one melodic interval plus one quantized duration.
    if nargin < 2
        k = 8;
    end

    % Durations can be fractional beats, so scale them before hashing to keep
    % the hash input numeric and stable.
    if nargin < 3
        duration_scale = 1000;
    end

    % Empty or too-short sequences cannot produce any shingles.
    if isempty(sequence)
        shingle_set = [];
        return;
    end

    % The sequence must have exactly two columns:
    %   column 1 = melodic interval
    %   column 2 = quantized duration
    if size(sequence, 2) ~= 2
        error('get_interval_duration_shingle_set:InvalidSequence', ...
            'sequence must be an Nx2 matrix: [interval, quantized_duration].');
    end

    if size(sequence, 1) < k
        shingle_set = [];
        return;
    end

    % Sliding window over the sequence. Each window contains k rows, meaning
    % k interval-duration pairs.
    num_shingles = size(sequence, 1) - k + 1;
    hashes = zeros(1, num_shingles);
    for i = 1:num_shingles
        window = sequence(i:i + k - 1, :);
        encoded = encode_window(window, duration_scale);
        hashes(i) = hash_values(encoded);
    end
    shingle_set = unique(hashes);
end

function encoded = encode_window(window, duration_scale)
    % Convert the k x 2 matrix into one row vector:
    % [interval1, duration1, interval2, duration2, ...]
    % This preserves the order of pitch and rhythm information inside a shingle.
    encoded = zeros(1, numel(window));
    encoded(1:2:end) = window(:, 1);
    encoded(2:2:end) = round(window(:, 2) .* duration_scale);
end

function h = hash_values(values)
    % Polynomial rolling hash, similar in spirit to shingles.m, but with a
    % larger base because the encoded windows include both intervals and durations.
    base = 131;
    mod_val = 2147483647;
    h = 0;
    for i = 1:numel(values)
        h = mod(h * base + values(i) + 1000003, mod_val);
    end
end
