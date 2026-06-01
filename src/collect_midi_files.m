function files = collect_midi_files(base_dir, recursive)
    %COLLECT_MIDI_FILES Recursively collects .mid and .midi files from a directory.
    %   FILES = COLLECT_MIDI_FILES(BASE_DIR, RECURSIVE) returns a sorted cell array
    %   of all MIDI file paths under BASE_DIR. If RECURSIVE is true, searches
    %   subdirectories as well.

    if ~isfolder(base_dir)
        error('collect_midi_files:DataDirNotFound', 'Data directory not found: %s', base_dir);
    end

    if recursive
        midi_a = dir(fullfile(base_dir, '**', '*.midi'));
        midi_b = dir(fullfile(base_dir, '**', '*.mid'));
    else
        midi_a = dir(fullfile(base_dir, '*.midi'));
        midi_b = dir(fullfile(base_dir, '*.mid'));
    end

    files = cell(1, numel(midi_a) + numel(midi_b));
    k = 1;
    for i = 1:numel(midi_a)
        files{k} = fullfile(midi_a(i).folder, midi_a(i).name);
        k = k + 1;
    end
    for i = 1:numel(midi_b)
        files{k} = fullfile(midi_b(i).folder, midi_b(i).name);
        k = k + 1;
    end

    files = unique(files);
    files = sort(files);
end
