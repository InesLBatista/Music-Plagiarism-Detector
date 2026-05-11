% TODO 2: Implement the k-shingles generation for note sequences, focusing on the 8-note rule to create shingles for melody comparison.

function shingle_set = get_shingle_set(note_intervals, k)
    % Main function. Takes a melody and produces a set of unique numbers.
    % note_intervals: list of pitch jumps
    % k: chunk size (8)
    % Returns: list of unique integers representing all the chunks found.
    if nargin < 2
        k = 8;
    end
    shingles = generate_shingles(note_intervals, k);
    hashes = cellfun(@hash_shingle, shingles);
    shingle_set = unique(hashes);
end

function shingle_set = get_combined_shingle_set(note_intervals, rhythm_norm, k)
    %takes rhythm into account.It interleaves pitch and rhythm info
    % so each chunk captures both what notes were played and how long they lasted.
    if nargin < 3
        k = 8;
    end
    rhythm_bins = quantize_rhythm(rhythm_norm);
    min_len = min(length(note_intervals), length(rhythm_bins));
    combined = zeros(1, min_len * 2);
    combined(1:2:end) = note_intervals(1:min_len);
    combined(2:2:end) = rhythm_bins(1:min_len);
    shingle_set = get_shingle_set(combined, k);
end

function shingles = generate_shingles(sequence, k)
    % Sliding window over the melody: cuts the sequence into all overlapping
    % chunks of size k. e.g. [1,2,3,4,5] with k=3 gives [1,2,3], [2,3,4], [3,4,5].
    % Returns all chunks as a list of arrays.
    n = length(sequence);
    if n < k
        shingles = {};
        return;
    end
    num_shingles = n - k + 1;
    shingles = cell(1, num_shingles);
    for i = 1:num_shingles
        shingles{i} = sequence(i:i+k-1);
    end
end

function h = hash_shingle(shingle)
    % Converts a chunk of 8 numbers into a single integer "ID".
    % This makes chunks fast to store and compare.
    % 8 numbers you just compare 1. Uses a polynomial rolling hash.
    base = 31;
    mod_val = 2^31 - 1; % large prime to avoid collisions
    h = 0;
    for i = 1:length(shingle)
        h = mod(h * base + shingle(i) + 128, mod_val);
    end
end

function bins = quantize_rhythm(rhythm_norm)
    % Rhythm comes as continuous ratios (e.g. 1.3 means next note lasts 1.3x longer).
    % Exact floats are too sensitive for comparison, so we round them into 5 buckets:
    %   1 = much shorter, 2 = shorter, 3 = roughly equal, 4 = longer, 5 = much longer
    bins = ones(size(rhythm_norm));
    bins(rhythm_norm >= 0.5 & rhythm_norm < 0.8) = 2;
    bins(rhythm_norm >= 0.8 & rhythm_norm < 1.25) = 3;
    bins(rhythm_norm >= 1.25 & rhythm_norm < 2.0) = 4;
    bins(rhythm_norm >= 2.0) = 5;
end