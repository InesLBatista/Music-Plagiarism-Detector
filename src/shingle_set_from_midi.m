function shingles = shingle_set_from_midi(midi_path, options)
    %SHINGLE_SET_FROM_MIDI Generate a shingle set for a MIDI file using current options.
    %   SHINGLES = SHINGLE_SET_FROM_MIDI(MIDI_PATH, OPTIONS) reads the MIDI file,
    %   extracts the interval-duration sequence and returns the set of unique
    %   shingles for the specified shingle length.

    [sequence, ~, ~, ~] = generate_interval_duration_sequence_from_midi(midi_path, options);
    shingles = get_interval_duration_shingle_set(sequence, options.shingle_k);
end
