function [similarity, candidates] = detect_plagiarism(query_midi, database_midis, options)
%DETECT_PLAGIARISM Compare one query MIDI against a database of MIDI files.

    if nargin < 3
        options = struct();
    end

    [q_events, ~] = midi_to_note_events(query_midi);
    [q_seq, ~, ~] = melody_events_to_interval_duration_sequence(q_events, options);

    k = 8;
    if isfield(options, 'shingle_k')
        k = options.shingle_k;
    end
    q_shingles = get_interval_duration_shingle_set(q_seq, k);

    if isempty(database_midis)
        similarity = 0;
        candidates = [];
        return;
    end

    num_db = numel(database_midis);
    db_shingle_sets = cell(num_db, 1);
    db_bloom_filters = cell(num_db, 1);

    for i = 1:num_db
        [db_events, ~] = midi_to_note_events(database_midis{i});
        [db_seq, ~, ~] = melody_events_to_interval_duration_sequence(db_events, options);
        db_shingle_sets{i} = get_interval_duration_shingle_set(db_seq, k);

        bf = bloom_create(10000, 5);
        db_bloom_filters{i} = bloom_add_set(bf, db_shingle_sets{i});
    end

    bf_scores = zeros(num_db, 1);
    for i = 1:num_db
        if ~isempty(q_shingles)
            match_count = bloom_count_matches(db_bloom_filters{i}, q_shingles);
            bf_scores(i) = match_count / numel(q_shingles);
        end
    end

    all_shingle_sets = [db_shingle_sets; {q_shingles}];
    num_hashes = 100;
    bands = 20;
    if isfield(options, 'num_hashes'), num_hashes = options.num_hashes; end
    if isfield(options, 'bands'), bands = options.bands; end

    similar_pairs = find_similar_melodies_lsh(all_shingle_sets, num_hashes, bands);

    candidates = [];
    candidate_indices = [];
    if ~isempty(similar_pairs)
        query_idx = num_db + 1;
        matches_query = any(similar_pairs == query_idx, 2);
        pairs_with_query = similar_pairs(matches_query, :);
        candidate_indices = pairs_with_query(pairs_with_query ~= query_idx);
    end

    bf_threshold = 0.5;
    if isfield(options, 'bf_threshold'), bf_threshold = options.bf_threshold; end
    high_bf_indices = find(bf_scores >= bf_threshold);
    candidate_indices = unique([candidate_indices; high_bf_indices]);

    for i = 1:numel(candidate_indices)
        db_idx = candidate_indices(i);
        sim = local_jaccard(q_shingles, db_shingle_sets{db_idx});
        candidates = [candidates; struct('index', db_idx, 'path', database_midis{db_idx}, ...
            'similarity', sim, 'bf_estimate', bf_scores(db_idx))]; %#ok<AGROW>
    end

    if isempty(candidates)
        similarity = 0;
    else
        [similarity, ~] = max([candidates.similarity]);
        [~, sort_idx] = sort([candidates.similarity], 'descend');
        candidates = candidates(sort_idx);
    end
end

function sim = local_jaccard(set1, set2)
    if isempty(set1) || isempty(set2)
        sim = 0;
        return;
    end
    inter = numel(intersect(set1, set2));
    union_sz = numel(union(set1, set2));
    sim = inter / union_sz;
end
