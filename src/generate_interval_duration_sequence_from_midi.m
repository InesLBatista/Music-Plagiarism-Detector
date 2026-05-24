% DONE: End-to-end helper that converts a MIDI file into plagiarism-ready features.
% Pipeline: MIDI file -> normalized note events -> (melodic_interval, quantized_duration) sequence.

function [sequence, melody, events, info] = generate_interval_duration_sequence_from_midi(midi_path, options)
%GENERATE_INTERVAL_DURATION_SEQUENCE_FROM_MIDI MIDI to (interval, duration).
%   [sequence, melody, events, info] = generate_interval_duration_sequence_from_midi(path)
%   parses a MIDI file and returns an Nx2 sequence where each row is:
%       [signed_melodic_interval, quantized_duration]

    % If the caller does not define options, use the defaults from the
    % conversion function: top note melody extraction and 0.25 beat grid.
    if nargin < 2
        options = struct();
    end

    % First step: read the MIDI file and convert raw note on/off messages
    % into note events with onset, duration, pitch and velocity.
    [events, midi_meta] = midi_to_note_events(midi_path);

    % Second step: turn those note events into the sequence used by the
    % plagiarism detector: [melodic_interval, quantized_duration].
    [sequence, melody, info] = melody_events_to_interval_duration_sequence(events, options);

    % Keep the MIDI metadata together with the sequence metadata, so later
    % stages can inspect ticks-per-quarter, format, track count, etc.
    info.midi = midi_meta;
end
