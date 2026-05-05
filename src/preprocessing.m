% TODO 1: Develop functions to load and preprocess musical data, such as parsing MIDI files or note sequences into a usable format for analysis.

% Data Representation: Each note as (note, duration), represented as struct('note', 'C', 'duration', 1.0)

function intervals = notes_to_intervals(notes)
    % Convert a sequence of note names to intervals (transposition invariant).
    % notes: cell array of note strings like {'C', 'C#', 'Db', 'D', ...}
    pitch_map = containers.Map({
        'C','B#','C#','Db','D','D#','Eb','E','Fb','E#','F','F#','Gb', ...
        'G','G#','Ab','A','A#','Bb','B','Cb'}, ...
        {0,0,1,1,2,3,3,4,4,5,5,6,6,7,8,8,9,10,10,11,11});
    intervals = [];
    for i = 1:length(notes)-1
        note1 = normalize_note_name(notes{i});
        note2 = normalize_note_name(notes{i+1});
        if ~isKey(pitch_map, note1) || ~isKey(pitch_map, note2)
            error('Unknown note name: %s or %s', notes{i}, notes{i+1});
        end
        intervals = [intervals, pitch_map(note2) - pitch_map(note1)];
    end
end

function note = normalize_note_name(raw_note)
    % Normalize note name string to uppercase and remove whitespace.
    note = upper(strtrim(raw_note));
end

function norm_durations = normalize_rhythm(durations)
    % Normalize durations to relative values (sum to 1).
    % durations: array of numbers
    total = sum(durations);
    if total == 0
        norm_durations = durations;  % Avoid division by zero
    else
        norm_durations = durations / total;
    end
end

function [note_intervals, rhythm_norm] = extract_features(melody)
    % Extract note intervals and normalized rhythm from a melody.
    % melody: array of structs with 'note' and 'duration'
    notes = {melody.note};
    durations = [melody.duration];

    note_intervals = notes_to_intervals(notes);
    rhythm_norm = normalize_rhythm(durations);
end