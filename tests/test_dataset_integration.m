% Dataset integration test for the full MIDI-to-plagiarism pipeline.

test_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(test_dir, '..', 'src'));

data_dir = fullfile(test_dir, '..', 'data', 'maestro-v3.0.0');
midi_files = find_dataset_midi_files(data_dir, 4);
assert(~isempty(midi_files), 'No dataset MIDI files were found under %s.', data_dir);

fprintf('Using %d dataset MIDI files from %s\n', numel(midi_files), data_dir);

query_file = midi_files{1};
database_files = midi_files(2:end);

options.duration_grid = 0.25;
options.extraction = 'top_note_per_onset';
options.interval_mod12 = false;

[sequence, melody, events, info] = generate_interval_duration_sequence_from_midi(query_file, options);
assert(~isempty(events), 'Parsed dataset MIDI should contain events.');
assert(size(sequence, 2) == 2, 'Sequence must be Nx2.');
assert(info.num_pairs == size(sequence, 1), 'Metadata num_pairs must match sequence length.');
assert(info.num_melody_notes == numel(melody), 'Metadata num_melody_notes must match melody length.');
assert(all(sequence(:,2) > 0), 'Quantized durations must be positive.');

[sim, candidates] = detect_plagiarism(query_file, database_files, struct('duration_grid', options.duration_grid, ...
    'extraction', options.extraction, 'interval_mod12', options.interval_mod12, 'shingle_k', 8, 'num_hashes', 50, 'bands', 10, 'bf_threshold', 0.1));
assert(isnumeric(sim) && sim >= 0, 'Similarity must be numeric and non-negative.');
assert(all(arrayfun(@(c) isfield(c, 'path') && isfield(c, 'similarity'), candidates)), 'Candidates must contain path and similarity fields.');

fprintf('Dataset integration tests passed for query file: %s\n', query_file);

function list = find_dataset_midi_files(root_dir, max_files)
    list = {};
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
        list = full_paths;
    else
        list = full_paths(1:max_files);
    end
end
