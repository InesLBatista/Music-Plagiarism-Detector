test_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(test_dir, '..', 'src'));

% Four interval-duration pairs produce three shingles when k = 2.
sequence = [
    2, 0.25;
    1, 0.50;
   -3, 0.25;
    5, 1.00
];

shingles = get_interval_duration_shingle_set(sequence, 2);
assert(numel(shingles) == 3);
assert(numel(unique(shingles)) == 3);

% A repeated sequence should collapse duplicated shingles into a unique set.
repeated_sequence = [
    2, 0.25;
    1, 0.50;
    2, 0.25;
    1, 0.50
];

repeated_shingles = get_interval_duration_shingle_set(repeated_sequence, 2);
assert(numel(repeated_shingles) == 2);

% If k is larger than the sequence, no shingles can be generated.
empty_shingles = get_interval_duration_shingle_set(sequence, 10);
assert(isempty(empty_shingles));

disp('interval-duration shingle tests passed');
