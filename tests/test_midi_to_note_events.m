test_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(test_dir, '..', 'src'));

data_dir = fullfile(test_dir, '..', 'data', 'maestro-v3.0.0');
midi_files = find_dataset_midi_files(data_dir, 1);

if isempty(midi_files)
    warning('No dataset MIDI files found. Falling back to synthetic MIDI for midi_to_note_events test.');
    tmp_midi = fullfile(tempdir, 'music_plagiarism_detector_one_note.midi');
    write_one_note_midi(tmp_midi);
    test_midi = tmp_midi;
    cleanup = onCleanup(@() delete(tmp_midi));
else
    test_midi = midi_files{1};
    cleanup = onCleanup(@() []);
end

[events, meta] = midi_to_note_events(test_midi);
assert(~isempty(events), 'Parsed MIDI should contain at least one note event.');
assert(isfield(meta, 'ticks_per_quarter') && meta.ticks_per_quarter > 0, 'MIDI metadata must include ticks_per_quarter.');
assert(isfield(events, 'note_number') && isfield(events, 'note_name') && isfield(events, 'pitch_class'), 'Event struct must contain expected fields.');
assert(all([events.duration_beat] > 0), 'Note durations must be positive.');
assert(all([events.onset_beat] >= 0), 'Note onsets must be non-negative.');

disp('midi_to_note_events tests passed');

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

function write_one_note_midi(path)
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
        0, 255, 47, 0 ...
    ]);

    fwrite(fid, uint8([77 84 114 107]), 'uint8');
    fwrite(fid, uint8([0 0 0 numel(track_data)]), 'uint8');
    fwrite(fid, track_data, 'uint8');
end
