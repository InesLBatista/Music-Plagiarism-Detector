test_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(test_dir, '..', 'src'));

data_dir = fullfile(test_dir, '..', 'data', 'maestro-v3.0.0');
midi_files = find_dataset_midi_files(data_dir, 1);

if isempty(midi_files)
    warning('No dataset MIDI files found. Falling back to synthetic MIDI for generate_interval_duration_sequence_from_midi test.');
    tmp_midi = fullfile(tempdir, 'music_plagiarism_detector_two_notes.midi');
    write_two_note_midi(tmp_midi);
    midi_path = tmp_midi;
    cleanup = onCleanup(@() delete(tmp_midi));
else
    midi_path = midi_files{1};
    cleanup = onCleanup(@() []);
end

options.duration_grid = 0.25;
options.extraction = 'top_note_per_onset';
options.interval_mod12 = false;

[sequence, melody, events, info] = generate_interval_duration_sequence_from_midi(midi_path, options);
assert(size(sequence, 2) == 2, 'Sequence must be Nx2.');
assert(info.num_pairs == size(sequence, 1), 'num_pairs must match sequence length.');
assert(info.num_melody_notes == numel(melody), 'num_melody_notes must match melody length.');
assert(~isempty(events), 'MIDI parsing should produce events.');
assert(all(sequence(:,2) > 0), 'Quantized durations must be positive.');

disp('generate interval-duration sequence from MIDI tests passed');

function paths = find_dataset_midi_files(root_dir, max_count)
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
    if nargin < 2 || isempty(max_count) || numel(full_paths) <= max_count
        paths = full_paths;
    else
        paths = full_paths(1:max_count);
    end
end

function write_two_note_midi(path)
    fid = fopen(path, 'w', 'b');
    cleaner = onCleanup(@() fclose(fid));

    fwrite(fid, uint8([77 84 104 100]), 'uint8');
    fwrite(fid, uint8([0 0 0 6]), 'uint8');
    fwrite(fid, uint8([0 0]), 'uint8');
    fwrite(fid, uint8([0 1]), 'uint8');
    fwrite(fid, uint8([1 224]), 'uint8');

    track_data = uint8([ ...
        0, 144, 60, 64, ...
        131, 96, 128, 60, 0, ...
        0, 144, 64, 70, ...
        129, 112, 128, 64, 0, ...
        0, 255, 47, 0 ...
    ]);

    fwrite(fid, uint8([77 84 114 107]), 'uint8');
    fwrite(fid, uint8([0 0 0 numel(track_data)]), 'uint8');
    fwrite(fid, track_data, 'uint8');
end
