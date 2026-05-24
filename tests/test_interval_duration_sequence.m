test_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(test_dir, '..', 'src'));

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
