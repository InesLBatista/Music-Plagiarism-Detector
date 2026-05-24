test_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(test_dir, '..', 'src'));

% This test builds a tiny MIDI file with one note:
% C4 starts at tick 0, lasts 480 ticks, then the track ends.
tmp_midi = fullfile(tempdir, 'music_plagiarism_detector_one_note.mid');
write_one_note_midi(tmp_midi);

[events, meta] = midi_to_note_events(tmp_midi);

assert(meta.format == 0);
assert(meta.num_tracks == 1);
assert(meta.ticks_per_quarter == 480);
assert(numel(events) == 1);

assert(events(1).note_number == 60);
assert(strcmp(events(1).note_name, 'C4'));
assert(events(1).pitch_class == 0);
assert(events(1).onset_tick == 0);
assert(events(1).duration_tick == 480);
assert(events(1).onset_beat == 0);
assert(events(1).duration_beat == 1);
assert(events(1).velocity == 64);

delete(tmp_midi);
disp('midi_to_note_events tests passed');

function write_one_note_midi(path)
    fid = fopen(path, 'w', 'b');
    cleaner = onCleanup(@() fclose(fid));

    % Header chunk: MThd, length 6, format 0, 1 track, 480 ticks/quarter.
    fwrite(fid, uint8([77 84 104 100]), 'uint8');
    fwrite(fid, uint8([0 0 0 6]), 'uint8');
    fwrite(fid, uint8([0 0]), 'uint8');
    fwrite(fid, uint8([0 1]), 'uint8');
    fwrite(fid, uint8([1 224]), 'uint8');

    % Track chunk: note on, note off after 480 ticks, end-of-track meta event.
    track_data = uint8([ ...
        0, 144, 60, 64, ...       % delta 0, note on, C4, velocity 64
        131, 96, 128, 60, 0, ...  % delta 480, note off, C4
        0, 255, 47, 0 ...         % delta 0, end of track
    ]);

    fwrite(fid, uint8([77 84 114 107]), 'uint8');
    fwrite(fid, uint8([0 0 0 numel(track_data)]), 'uint8');
    fwrite(fid, track_data, 'uint8');
end
