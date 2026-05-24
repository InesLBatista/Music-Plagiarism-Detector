% DONE: Parse MIDI note on/off messages into normalized note events.
% The output is an intermediate representation used before melody extraction.

function [events, meta] = midi_to_note_events(midi_path)
%MIDI_TO_NOTE_EVENTS Parse a MIDI file into normalized note events.
%   events = midi_to_note_events(path) returns a struct array with:
%   note_number, pitch_class, note_name, onset_tick, duration_tick,
%   onset_beat, duration_beat, velocity, channel, track.
%
%   Beats are expressed in quarter-note units using the MIDI ticks-per-quarter
%   division. Tempo is intentionally not needed for rhythm comparison because
%   plagiarism matching should be invariant to performance tempo.

    % Validate the input path before touching the file system.
    if nargin < 1 || ~isfile(midi_path)
        error('midi_to_note_events:FileNotFound', 'MIDI file not found: %s', midi_path);
    end

    % Open in big-endian mode. Standard MIDI files store multi-byte numbers in
    % big-endian order.
    fid = fopen(midi_path, 'r', 'b');
    if fid < 0
        error('midi_to_note_events:OpenFailed', 'Could not open MIDI file: %s', midi_path);
    end

    % Make sure the file is closed even if parsing fails halfway through.
    cleaner = onCleanup(@() fclose(fid));

    % MIDI files start with an MThd chunk containing format, track count and
    % timing division.
    chunk_type = read_chunk_type(fid);
    if ~strcmp(chunk_type, 'MThd')
        error('midi_to_note_events:InvalidHeader', 'Invalid MIDI header.');
    end

    header_len = fread(fid, 1, 'uint32');
    format_type = fread(fid, 1, 'uint16');
    num_tracks = fread(fid, 1, 'uint16');
    division = fread(fid, 1, 'uint16');

    % The MIDI header is normally 6 bytes, but skip any extra header bytes if
    % the file contains them.
    if header_len > 6
        fseek(fid, header_len - 6, 'cof');
    end

    % This parser supports the common ticks-per-quarter-note timing mode.
    % SMPTE timing is rarer and would need a different conversion.
    if bitand(division, 32768) ~= 0
        error('midi_to_note_events:SMPTEUnsupported', ...
            'SMPTE time division is not supported. Use ticks-per-quarter MIDI files.');
    end

    ticks_per_quarter = double(division);
    events = empty_events();

    % Parse every track chunk and collect note events from all tracks.
    for track_idx = 1:num_tracks
        if feof(fid)
            break;
        end

        track_type = read_chunk_type(fid);
        track_len = fread(fid, 1, 'uint32');
        track_data = fread(fid, track_len, 'uint8')';

        if strcmp(track_type, 'MTrk')
            track_events = parse_track(track_data, ticks_per_quarter, track_idx);
            events = [events, track_events]; %#ok<AGROW>
        end
    end

    % Keep events in musical order before returning them.
    events = sort_events(events);

    % Return basic metadata together with the events. This helps later stages
    % know how the MIDI timing was interpreted.
    meta.path = midi_path;
    meta.format = format_type;
    meta.num_tracks = num_tracks;
    meta.ticks_per_quarter = ticks_per_quarter;
    meta.num_events = numel(events);
end

function chunk_type = read_chunk_type(fid)
    % Read a 4-character MIDI chunk name, such as MThd or MTrk.
    raw = fread(fid, 4, 'uint8')';
    if numel(raw) < 4
        error('midi_to_note_events:UnexpectedEOF', 'Unexpected end of MIDI file.');
    end
    chunk_type = char(raw);
end

function events = parse_track(data, ticks_per_quarter, track_idx)
    % Track data is a stream of delta-time events. pos walks byte by byte,
    % while abs_tick stores the absolute musical time.
    pos = 1;
    abs_tick = 0;
    running_status = [];

    % active keeps note-on events that have not yet received their note-off.
    % Rows are channels, columns are MIDI note numbers + 1.
    active = cell(16, 128);
    events = empty_events();

    while pos <= numel(data)
        % Each MIDI event begins with a variable-length delta time.
        [delta, pos] = read_varlen(data, pos);
        abs_tick = abs_tick + delta;
        if pos > numel(data)
            break;
        end

        % MIDI can omit repeated status bytes using "running status". If the
        % current byte is data, reuse the previous channel status.
        status = data(pos);
        if status >= 128
            pos = pos + 1;
            if status < 240
                running_status = status;
            end
        else
            if isempty(running_status)
                error('midi_to_note_events:MissingRunningStatus', ...
                    'Running status used before any status byte.');
            end
            status = running_status;
        end

        % Meta events and system exclusive events are skipped here. They can
        % contain tempo, text, pedal, etc., but this stage only needs notes.
        if status == 255
            if pos > numel(data)
                break;
            end
            pos = pos + 1; % meta type
            [len, pos] = read_varlen(data, pos);
            pos = pos + len;
            continue;
        elseif status == 240 || status == 247
            [len, pos] = read_varlen(data, pos);
            pos = pos + len;
            continue;
        end

        message_type = bitand(status, 240);
        channel = bitand(status, 15) + 1;

        % Note-on starts an active note. Note-off closes it and creates a
        % normalized event with onset and duration.
        switch message_type
            case 128 % note off
                [note, velocity, pos] = read_two_data_bytes(data, pos);
                [active, events] = close_note(active, events, channel, note, ...
                    velocity, abs_tick, ticks_per_quarter, track_idx);
            case 144 % note on, velocity zero is note off
                [note, velocity, pos] = read_two_data_bytes(data, pos);
                if velocity == 0
                    [active, events] = close_note(active, events, channel, note, ...
                        velocity, abs_tick, ticks_per_quarter, track_idx);
                else
                    stack = active{channel, note + 1};
                    active{channel, note + 1} = [stack; double(abs_tick), double(velocity)];
                end
            case {160, 176, 224}
                % Aftertouch, control change and pitch bend have two data bytes.
                pos = pos + 2;
            case {192, 208}
                % Program change and channel pressure have one data byte.
                pos = pos + 1;
            otherwise
                error('midi_to_note_events:UnsupportedMessage', ...
                    'Unsupported MIDI message type: %d', message_type);
        end
    end
end

function [value, pos] = read_varlen(data, pos)
    % MIDI variable-length quantities use 7 bits per byte. The high bit means
    % "another byte follows".
    value = 0;
    while pos <= numel(data)
        byte = double(data(pos));
        pos = pos + 1;
        value = value * 128 + bitand(byte, 127);
        if byte < 128
            return;
        end
    end
    error('midi_to_note_events:InvalidVarlen', 'Invalid variable-length quantity.');
end

function [byte1, byte2, pos] = read_two_data_bytes(data, pos)
    % Most note-related MIDI messages carry two data bytes: note and velocity.
    if pos + 1 > numel(data)
        error('midi_to_note_events:UnexpectedEOF', 'Unexpected end of MIDI event.');
    end
    byte1 = double(data(pos));
    byte2 = double(data(pos + 1));
    pos = pos + 2;
end

function [active, events] = close_note(active, events, channel, note, off_velocity, ...
        off_tick, ticks_per_quarter, track_idx)
    % Close the earliest active note with this pitch/channel. This handles
    % repeated notes of the same pitch by treating active notes as a queue.
    stack = active{channel, note + 1};
    if isempty(stack)
        return;
    end

    onset_tick = stack(1, 1);
    on_velocity = stack(1, 2);
    active{channel, note + 1} = stack(2:end, :);

    duration_tick = double(off_tick) - onset_tick;
    if duration_tick <= 0
        return;
    end

    % Build the normalized note event. Beats are quarter-note beats, so they
    % stay useful even if the performance tempo changes.
    event.note_number = double(note);
    event.pitch_class = mod(double(note), 12);
    event.note_name = midi_note_name(double(note));
    event.onset_tick = onset_tick;
    event.duration_tick = duration_tick;
    event.onset_beat = onset_tick / ticks_per_quarter;
    event.duration_beat = duration_tick / ticks_per_quarter;
    event.velocity = on_velocity;
    event.off_velocity = double(off_velocity);
    event.channel = channel;
    event.track = track_idx;
    events(end + 1) = event; %#ok<AGROW>
end

function events = sort_events(events)
    % Sort by onset. For notes that start together, put the highest pitch first.
    if isempty(events)
        return;
    end
    sort_key = [[events.onset_tick]', -[events.note_number]'];
    [~, idx] = sortrows(sort_key, [1, 2]);
    events = events(idx);
end

function events = empty_events()
    % Empty struct with all fields used by normalized MIDI note events.
    events = struct('note_number', {}, 'pitch_class', {}, 'note_name', {}, ...
        'onset_tick', {}, 'duration_tick', {}, 'onset_beat', {}, ...
        'duration_beat', {}, 'velocity', {}, 'off_velocity', {}, ...
        'channel', {}, 'track', {});
end

function name = midi_note_name(note_number)
    % Convert MIDI note number to a readable note name, e.g. 60 -> C4.
    names = {'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'};
    octave = floor(note_number / 12) - 1;
    name = sprintf('%s%d', names{mod(note_number, 12) + 1}, octave);
end
