% Test script for detection.m using dataset MIDI files.

test_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(test_dir, '..', 'src'));

data_dir = fullfile(test_dir, '..', 'data', 'maestro-v3.0.0');
midi_files = find_dataset_midi_files(data_dir, 4);
assert(numel(midi_files) >= 3, 'Need at least 3 dataset MIDI files for detection tests.');

query = midi_files{1};
database = midi_files(1:3);

fprintf('Test 1: Self-comparison\n');
[sim, candidates] = detect_plagiarism(query, database);
fprintf('Max Similarity: %.4f\n', sim);
assert(sim == 1.0, 'Self-comparison should return 1.0 similarity');
assert(~isempty(candidates), 'Self-comparison must return at least one candidate.');

fprintf('\nTest 2: Comparison with other dataset files\n');
[sim2, candidates2] = detect_plagiarism(query, database(2:3));
assert(isnumeric(sim2) && sim2 >= 0, 'Similarity result must be numeric and non-negative');
assert(all(arrayfun(@(c) isfield(c, 'path') && isfield(c, 'similarity'), candidates2)), 'Output candidates must contain path and similarity fields');

fprintf('\nDetection tests using dataset files passed.\n');

function paths = find_dataset_midi_files(root_dir, max_files)
    paths = {};
    if ~exist(root_dir, 'dir')
        return;
    end
    midi_files = dir(fullfile(root_dir, '**', '*.midi'));
    if isempty(midi_files)
        midi_files = dir(fullfile(root_dir, '**', '*.mid'));
    end
    if isempty(midi_files)
        return;
    end
    full_paths = fullfile({midi_files.folder}, {midi_files.name});
    if nargin < 2 || isempty(max_files) || numel(full_paths) <= max_files
        paths = full_paths;
    else
        paths = full_paths(1:max_files);
    end
end
