test_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(test_dir, '..', 'src'));

% End-to-end test for:
% MIDI file -> note events -> melody -> [melodic_interval, quantized_duration].
tmp_midi = fullfile(tempdir, 'music_plagiarism_detector_two_notes.mid');
write_two_note_midi(tmp_midi);

options.duration_grid = 0.25;
options.extraction = 'top_note_per_onset';
options.interval_mod12 = false;

[sequence, melody, events, info] = generate_interval_duration_sequence_from_midi(tmp_midi, options);

assert(numel(events) == 2);
assert(numel(melody) == 2);
assert(isequal(sequence, [4, 0.5]));
assert(info.num_pairs == 1);
assert(info.midi.ticks_per_quarter == 480);

delete(tmp_midi);
disp('generate interval-duration sequence from MIDI tests passed');

function write_two_note_midi(path)
    fid = fopen(path, 'w', 'b');
    cleaner = onCleanup(@() fclose(fid));

    % Header chunk: MThd, length 6, format 0, 1 track, 480 ticks/quarter.
    fwrite(fid, uint8([77 84 104 100]), 'uint8');
    fwrite(fid, uint8([0 0 0 6]), 'uint8');
    fwrite(fid, uint8([0 0]), 'uint8');
    fwrite(fid, uint8([0 1]), 'uint8');
    fwrite(fid, uint8([1 224]), 'uint8');

    % C4 lasts 480 ticks. E4 starts immediately after and lasts 240 ticks.
    track_data = uint8([ ...
        0, 144, 60, 64, ...       % delta 0, note on C4
        131, 96, 128, 60, 0, ...  % delta 480, note off C4
        0, 144, 64, 70, ...       % delta 0, note on E4
        129, 112, 128, 64, 0, ... % delta 240, note off E4
        0, 255, 47, 0 ...         % delta 0, end of track
    ]);

    fwrite(fid, uint8([77 84 114 107]), 'uint8');
    fwrite(fid, uint8([0 0 0 numel(track_data)]), 'uint8');
    fwrite(fid, track_data, 'uint8');
end
