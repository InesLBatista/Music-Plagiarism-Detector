% TODO 4: Implement MinHash algorithm combined with Locality Sensitive Hashing (LSH) to efficiently find similar melodies using shingles.

function sig = minhash_signature(shingle_set, num_hashes)
	% Gera a assinatura MinHash de um conjunto de shingles
	% shingle_set: vetor de inteiros (hashes dos shingles)
	% num_hashes: número de funções hash (tamanho da assinatura)
	if nargin < 2
		num_hashes = 100;
	end
	max_shingle = 2^31-1;
	rng(42); % Para reprodutibilidade
	a = randi([1, max_shingle], 1, num_hashes);
	b = randi([0, max_shingle], 1, num_hashes);
	p = 4294967311; % primo grande
	sig = zeros(1, num_hashes);
	for i = 1:num_hashes
		hashes = mod(a(i) * double(shingle_set) + b(i), p);
		sig(i) = min(hashes);
	end
end

function buckets = lsh_buckets(signatures, bands)
	% Aplica LSH às assinaturas MinHash
	% signatures: matriz (num_melodias x num_hashes)
	% bands: número de bandas para LSH
	[num_melodies, num_hashes] = size(signatures);
	rows_per_band = floor(num_hashes / bands);
	buckets = cell(bands, 1);
	for b = 1:bands
		band_hashes = zeros(num_melodies, 1);
		for m = 1:num_melodies
			start_idx = (b-1)*rows_per_band + 1;
			end_idx = b*rows_per_band;
			band = signatures(m, start_idx:end_idx);
			band_hashes(m) = hash_band(band);
		end
		% Agrupa melodias pelo mesmo hash de banda
		[~, ~, group] = unique(band_hashes);
		buckets{b} = group;
	end
end

function h = hash_band(band)
	% Hash simples para vetor de inteiros
	base = 31;
	mod_val = 2^31 - 1;
	h = 0;
	for i = 1:length(band)
		h = mod(h * base + band(i), mod_val);
	end
end

function similar_pairs = find_similar_melodies_lsh(shingle_sets, num_hashes, bands)
	% Encontra pares de melodias similares usando MinHash + LSH
	% shingle_sets: cell array, cada célula é um vetor de shingles de uma melodia
	% num_hashes: tamanho da assinatura MinHash
	% bands: número de bandas para LSH
	if nargin < 2
		num_hashes = 100;
	end
	if nargin < 3
		bands = 20;
	end
	num_melodies = length(shingle_sets);
	signatures = zeros(num_melodies, num_hashes);
	for i = 1:num_melodies
		signatures(i, :) = minhash_signature(shingle_sets{i}, num_hashes);
	end
	buckets = lsh_buckets(signatures, bands);
	% Busca pares que caem no mesmo bucket em qualquer banda
	candidate_pairs = containers.Map('KeyType','char','ValueType','any');
	for b = 1:bands
		group = buckets{b};
		for g = unique(group)'
			idx = find(group == g);
			if numel(idx) > 1
				for i = 1:numel(idx)
					for j = i+1:numel(idx)
						key = sprintf('%d-%d', min(idx(i),idx(j)), max(idx(i),idx(j)));
						candidate_pairs(key) = [min(idx(i),idx(j)), max(idx(i),idx(j))];
					end
				end
			end
		end
	end
	% Calcula similaridade Jaccard real para os candidatos
	keys = candidate_pairs.keys;
	similar_pairs = [];
	threshold = 0.8; % pode ajustar
	for k = 1:length(keys)
		pair = candidate_pairs(keys{k});
		set1 = shingle_sets{pair(1)};
		set2 = shingle_sets{pair(2)};
		sim = jaccard_similarity(set1, set2);
		if sim >= threshold
			similar_pairs = [similar_pairs; pair];
		end
	end
end

function sim = jaccard_similarity(set1, set2)
	% Similaridade Jaccard entre dois conjuntos
	inter = numel(intersect(set1, set2));
	union_sz = numel(union(set1, set2));
	sim = inter / union_sz;
end