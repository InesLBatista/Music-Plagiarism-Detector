% DONE: Convert normalized note events into (melodic_interval, quantized_duration) sequences.
% The default melody extraction keeps the highest note at each onset for polyphonic piano MIDI.

function [sequence, melody, info] = melody_events_to_interval_duration_sequence(events, options)
%MELODY_EVENTS_TO_INTERVAL_DURATION_SEQUENCE Build (interval, duration) pairs.
%   sequence = melody_events_to_interval_duration_sequence(events) converts
%   normalized note events into an Nx2 matrix:
%       column 1: signed melodic interval in semitones
%       column 2: quantized duration in beats
%
%   Each row represents the movement from the previous melody note to the
%   current melody note, paired with the current note duration.

    % Options are optional so the function can be called directly after MIDI
    % parsing without extra setup.
    if nargin < 2
        options = struct();
    end

    % Read configurable preprocessing choices. Defaults are conservative:
    % quarter-note beats quantized to 0.25 and signed intervals preserved.
    duration_grid = get_option(options, 'duration_grid', 0.25);
    min_duration = get_option(options, 'min_duration', 0);
    interval_mod12 = get_option(options, 'interval_mod12', false);
    extraction = get_option(options, 'extraction', 'top_note_per_onset');

    % No note events means there is no melody to compare, so return an empty
    % sequence with metadata still filled in.
    if isempty(events)
        sequence = zeros(0, 2);
        melody = empty_melody();
        info = build_info(duration_grid, min_duration, interval_mod12, extraction);
        return;
    end

    % Clean and order the events before choosing the melody notes. This keeps
    % later interval computation deterministic.
    events = filter_events(events, min_duration);
    events = sort_events(events);
    melody = extract_melody(events, extraction);

    % At least two notes are needed to create one melodic interval.
    if numel(melody) < 2
        sequence = zeros(0, 2);
        info = build_info(duration_grid, min_duration, interval_mod12, extraction);
        info.num_melody_notes = numel(melody);
        info.num_pairs = 0;
        return;
    end

    % Split the melody into pitch and duration vectors. Durations are
    % quantized first so small performance differences do not dominate matching.
    notes = [melody.note_number];
    durations = [melody.duration_beat];
    quantized_durations = quantize_values(durations, duration_grid);

    % Intervals represent melodic movement between consecutive notes.
    % Signed intervals preserve direction; mod12 can be enabled if only pitch
    % class movement matters.
    intervals = diff(notes);
    if interval_mod12
        intervals = mod(intervals, 12);
    end

    % Pair each interval with the duration of the note it arrives on. The first
    % note has no previous note, so its duration is not used in the sequence.
    sequence = [intervals(:), quantized_durations(2:end)'];

    % Store the quantized duration back into the melody notes for debugging,
    % reports, or later visualization.
    for i = 1:numel(melody)
        melody(i).duration_quantized = quantized_durations(i);
    end

    % Metadata helps the next pipeline stages understand how this sequence was built.
    info = build_info(duration_grid, min_duration, interval_mod12, extraction);
    info.num_melody_notes = numel(melody);
    info.num_pairs = size(sequence, 1);
end

function value = get_option(options, field_name, default_value)
    % Small helper to read optional fields without repeating isfield checks.
    if isstruct(options) && isfield(options, field_name)
        value = options.(field_name);
    else
        value = default_value;
    end
end

function events = filter_events(events, min_duration)
    % Remove notes that are too short to be useful for melodic comparison.
    % min_duration is expressed in beats.
    if min_duration <= 0 || isempty(events)
        return;
    end
    keep = [events.duration_beat] >= min_duration;
    events = events(keep);
end

function melody = extract_melody(events, extraction)
    % Choose how to reduce MIDI note events into a melody line. Piano MIDI is
    % often polyphonic, so the default keeps the highest note at each onset.
    switch lower(extraction)
        case 'top_note_per_onset'
            melody = top_note_per_onset(events);
        case 'all_notes'
            melody = copy_events_to_melody(events);
        otherwise
            error('melody_events_to_interval_duration_sequence:UnknownExtraction', ...
                'Unknown melody extraction mode: %s', extraction);
    end
end

function melody = top_note_per_onset(events)
    % For each onset, pick a single note. The highest pitch is selected first;
    % if there is a tie, the longer duration wins.
    onset_ticks = [events.onset_tick];
    unique_onsets = unique(onset_ticks, 'stable');
    melody = empty_melody();

    for i = 1:numel(unique_onsets)
        same_onset = find(onset_ticks == unique_onsets(i));
        notes = [events(same_onset).note_number];
        durations = [events(same_onset).duration_beat];
        [~, idx] = sortrows([-notes(:), -durations(:)], [1, 2]);
        selected = events(same_onset(idx(1)));
        melody(end + 1) = event_to_melody_note(selected); %#ok<AGROW>
    end
end

function melody = copy_events_to_melody(events)
    % Alternative mode: keep every note event. This is less melodic for piano,
    % but useful for debugging or monophonic MIDI files.
    melody = empty_melody();
    for i = 1:numel(events)
        melody(end + 1) = event_to_melody_note(events(i)); %#ok<AGROW>
    end
end

function note = event_to_melody_note(event)
    % Copy only the fields needed by the melody/sequence stage.
    note.note_number = event.note_number;
    note.pitch_class = event.pitch_class;
    note.note_name = event.note_name;
    note.onset_beat = event.onset_beat;
    note.duration_beat = event.duration_beat;
    note.duration_quantized = NaN;
    note.velocity = event.velocity;
end

function values = quantize_values(values, grid)
    % Snap durations to a fixed rhythmic grid, e.g. 0.25 beat = sixteenth note
    % when one beat is a quarter note.
    if grid <= 0
        error('melody_events_to_interval_duration_sequence:InvalidGrid', ...
            'duration_grid must be greater than zero.');
    end
    values = round(values ./ grid) .* grid;
    values(values <= 0) = grid;
end

function events = sort_events(events)
    % Sort by onset, and for simultaneous notes put the highest note first.
    if isempty(events)
        return;
    end
    sort_key = [[events.onset_tick]', -[events.note_number]'];
    [~, idx] = sortrows(sort_key, [1, 2]);
    events = events(idx);
end

function info = build_info(duration_grid, min_duration, interval_mod12, extraction)
    % Keep the preprocessing choices attached to the output for traceability.
    info.duration_grid = duration_grid;
    info.min_duration = min_duration;
    info.interval_mod12 = interval_mod12;
    info.extraction = extraction;
    info.num_melody_notes = 0;
    info.num_pairs = 0;
end

function melody = empty_melody()
    % Empty struct with the exact fields expected by the rest of this file.
    melody = struct('note_number', {}, 'pitch_class', {}, 'note_name', {}, ...
        'onset_beat', {}, 'duration_beat', {}, 'duration_quantized', {}, ...
        'velocity', {});
end
