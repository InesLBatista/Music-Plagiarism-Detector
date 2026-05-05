% TODO 1: Develop functions to load and preprocess musical data, such as parsing MIDI files or note sequences into a usable format for analysis.

% Data Representation: Each note as (note, duration), represented as struct('note', 'C', 'duration', 1.0)
% Velocity is ignored if present. Rests are removed and very short notes are filtered.

function [note_intervals, rhythm_norm] = preprocess(melody)
    % Main preprocessing pipeline for a melody.
    % melody: array of structs with fields 'note', 'duration', and optional 'velocity'.
    melody = remove_rests(melody);
    melody = remove_short_notes(melody);
    melody = quantize_durations(melody);

    notes = {melody.note};
    durations = [melody.duration];

    note_intervals = notes_to_intervals(notes);
    rhythm_norm = normalize_rhythm_ratios(durations);
end

function melody = remove_rests(melody)
    % Remove rest events from a melody.
    rest_names = {'R', 'REST', 'Z', '-', 'NONE'};
    keep = true(size(melody));
    for i = 1:length(melody)
        note_str = normalize_note_name(melody(i).note);
        if any(strcmp(note_str, rest_names)) || isempty(note_str)
            keep(i) = false;
        end
    end
    melody = melody(keep);
end

function melody = remove_short_notes(melody)
    % Remove extremely short notes that may come from MIDI noise.
    if isempty(melody)
        return;
    end
    durations = [melody.duration];
    median_duration = median(durations);
    min_duration = max(0.01, median_duration * 0.1);
    keep = durations >= min_duration;
    melody = melody(keep);
end

function melody = quantize_durations(melody)
    % Quantize note durations to reduce MIDI timing noise.
    if isempty(melody)
        return;
    end
    grid = 1/16; % quantization step, e.g. 16th note grid
    for i = 1:length(melody)
        melody(i).duration = round(melody(i).duration / grid) * grid;
        if melody(i).duration <= 0
            melody(i).duration = grid;
        end
    end
end

function intervals = notes_to_intervals(notes)
    % Convert a sequence of note names to intervals (transposition invariant).
    % notes: cell array of note strings like {'C', 'C#', 'Db', 'D', ...}
    pitch_map = containers.Map({
        'C','B#','C#','DB','D','D#','EB','E','FB','E#','F','F#','GB', ...
        'G','G#','AB','A','A#','BB','B','CB'}, ...
        {0,0,1,1,2,3,3,4,4,5,5,6,6,7,8,8,9,10,10,11,11});
    intervals = [];
    for i = 1:length(notes)-1
        note1 = normalize_note_name(notes{i});
        note2 = normalize_note_name(notes{i+1});
        if ~isKey(pitch_map, note1) || ~isKey(pitch_map, note2)
            error('Unknown note name: %s or %s', notes{i}, notes{i+1});
        end
        % Use mod 12 to keep intervals within one octave.
        % This makes the interval representation transposition invariant.
        intervals = [intervals, mod(pitch_map(note2) - pitch_map(note1), 12)];
    end
end

function note = normalize_note_name(raw_note)
    % Normalize note name string to uppercase and remove whitespace.
    note = upper(strtrim(raw_note));
end

function ratio = normalize_rhythm_ratios(durations)
    % Normalize rhythm using duration ratios instead of total duration.
    % This preserves local temporal structure.
    if numel(durations) <= 1
        ratio = 1;
        return;
    end
    ratio = durations(2:end) ./ durations(1:end-1);
    ratio(~isfinite(ratio)) = 1; % avoid inf or NaN
end