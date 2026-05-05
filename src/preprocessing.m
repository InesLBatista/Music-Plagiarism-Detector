% TODO 1: Develop functions to load and preprocess musical data, such as parsing MIDI files or note sequences into a usable format for analysis.

% Data Representation: Each note as (note, duration), represented as struct('note', 'C', 'duration', 1.0)

function intervals = notes_to_intervals(notes)
    % Convert a sequence of note names to intervals (transposition invariant).
    % notes: cell array of note strings like {'C', 'C#', 'D', ...}
    pitch_map = containers.Map({'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'}, ...
                               {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11});
    intervals = [];
    for i = 1:length(notes)-1
        intervals = [intervals, pitch_map(notes{i+1}) - pitch_map(notes{i})];
    end
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