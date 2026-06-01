test_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(test_dir, '..', 'src'));

data_dir = fullfile(test_dir, '..', 'data', 'maestro-v3.0.0');
midi_files = find_dataset_midi_files(data_dir, 1);

if ~isempty(midi_files)
    [events, ~] = midi_to_note_events(midi_files{1});
    options.duration_grid = 0.25;
    options.extraction = 'top_note_per_onset';
    [sequence, melody, info] = melody_events_to_interval_duration_sequence(events, options);
    assert(size(sequence, 2) == 2, 'Dataset-derived sequence must be Nx2.');
    assert(info.num_pairs == size(sequence, 1), 'num_pairs must match actual sequence length.');
    assert(info.num_melody_notes == numel(melody), 'Metadata num_melody_notes must match melody entries.');
    assert(all(sequence(:,2) > 0), 'Quantized durations must be positive.');
end

events = struct('note_number', {}, 'pitch_class', {}, 'note_name', {}, ...
    'onset_tick', {}, 'duration_tick', {}, 'onset_beat', {}, ...
    'duration_beat', {}, 'velocity', {}, 'off_velocity', {}, ...
    'channel', {}, 'track', {});

events(1) = make_event(60, 0, 1.00, 90);
events(2) = make_event(64, 1, 0.50, 88);
events(3) = make_event(67, 1, 1.00, 80); % chord note, top note should win
events(4) = make_event(69, 2, 0.75, 84);

options.duration_grid = 0.25;
[sequence, melody, info] = melody_events_to_interval_duration_sequence(events, options);

expected = [7, 1.00; 2, 0.75];
assert(isequal(sequence, expected));
assert(numel(melody) == 3);
assert(info.num_pairs == 2);

shingles = get_interval_duration_shingle_set(sequence, 2);
assert(numel(shingles) == 1);

disp('interval-duration sequence tests passed');

function event = make_event(note_number, onset_beat, duration_beat, velocity)
    event.note_number = note_number;
    event.pitch_class = mod(note_number, 12);
    event.note_name = sprintf('N%d', note_number);
    event.onset_tick = onset_beat * 480;
    event.duration_tick = duration_beat * 480;
    event.onset_beat = onset_beat;
    event.duration_beat = duration_beat;
    event.velocity = velocity;
    event.off_velocity = 0;
    event.channel = 1;
    event.track = 1;
end

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
