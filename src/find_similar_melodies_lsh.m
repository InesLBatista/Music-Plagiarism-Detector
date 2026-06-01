function similar_pairs = find_similar_melodies_lsh(shingle_sets, num_hashes, bands)
%FIND_SIMILAR_MELODIES_LSH Find similar melody pairs using MinHash + LSH.

    if nargin < 2
        num_hashes = 100;
    end
    if nargin < 3
        bands = 20;
    end

    num_melodies = numel(shingle_sets);
    if num_melodies < 2
        similar_pairs = [];
        return;
    end

    bands = min(max(1, bands), num_hashes);

    signatures = zeros(num_melodies, num_hashes);
    for i = 1:num_melodies
        signatures(i, :) = minhash_signature(shingle_sets{i}, num_hashes);
    end

    buckets = local_lsh_buckets(signatures, bands);

    candidate_pairs = containers.Map('KeyType', 'char', 'ValueType', 'any');
    for b = 1:bands
        group = buckets{b};
        groups = unique(group);
        for g = groups'
            idx = find(group == g);
            if numel(idx) > 1
                for i = 1:numel(idx)
                    for j = i + 1:numel(idx)
                        p1 = min(idx(i), idx(j));
                        p2 = max(idx(i), idx(j));
                        key = sprintf('%d-%d', p1, p2);
                        candidate_pairs(key) = [p1, p2];
                    end
                end
            end
        end
    end

    keys = candidate_pairs.keys;
    similar_pairs = [];
    threshold = 0.8;
    for k = 1:numel(keys)
        pair = candidate_pairs(keys{k});
        sim = local_jaccard(shingle_sets{pair(1)}, shingle_sets{pair(2)});
        if sim >= threshold
            similar_pairs = [similar_pairs; pair]; %#ok<AGROW>
        end
    end
end

function buckets = local_lsh_buckets(signatures, bands)
    [num_melodies, num_hashes] = size(signatures);
    rows_per_band = max(1, floor(num_hashes / bands));

    buckets = cell(bands, 1);
    for b = 1:bands
        start_idx = (b - 1) * rows_per_band + 1;
        end_idx = min(num_hashes, b * rows_per_band);

        band_hashes = zeros(num_melodies, 1);
        for m = 1:num_melodies
            band_hashes(m) = local_hash_band(signatures(m, start_idx:end_idx));
        end

        [~, ~, group] = unique(band_hashes);
        buckets{b} = group;
    end
end

function h = local_hash_band(values)
    base = 31;
    mod_val = 2147483647;
    h = 0;
    for i = 1:numel(values)
        h = mod(h * base + values(i), mod_val);
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
