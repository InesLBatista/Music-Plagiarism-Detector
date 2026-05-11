% TODO 3: Create a Bloom Filter implementation to quickly check for the presence of note sequences in a set, aiding in efficient duplicate detection.

function bf = bloom_create(num_bits, num_hashes)
    % Creates a new empty Bloom Filter.
    % num_bits: how many switches — more = fewer false positives, more memory
    % num_hashes: how many different hash functions to use per item
    % Returns a struct with the bit array and the filter's settings.
    if nargin < 1
        num_bits = 1000;
    end
    if nargin < 2
        num_hashes = 3;
    end
    bf.bits = false(1, num_bits);
    bf.num_bits = num_bits;
    bf.num_hashes = num_hashes;
end

function bf = bloom_add(bf, shingle_hash)
    % Adds a shingle to the Bloom Filter.
    % It flips on several switches based on the hash value.
    % After this, bloom_check can detect if this shingle was ever added.
    positions = get_bit_positions(shingle_hash, bf.num_hashes, bf.num_bits);
    bf.bits(positions) = true;
end

function bf = bloom_add_set(bf, shingle_set)
    % Adds all shingles from a melody's shingle set into the filter at once.
    % shingle_set: numeric vector of hashes (output of shingles.m)
    for i = 1:length(shingle_set)
        bf = bloom_add(bf, shingle_set(i));
    end
end

function result = bloom_check(bf, shingle_hash)
    % Checks if a shingle might be in the filter.
    % Returns true if it MIGHT be there (could be a false positive).
    % Returns false if it is DEFINITELY not there (never a false negative).
    positions = get_bit_positions(shingle_hash, bf.num_hashes, bf.num_bits);
    result = all(bf.bits(positions));
end

function count = bloom_count_matches(bf, shingle_set)
    % Counts how many shingles from a melody's set appear in the filter.
    % Useful to estimate overlap between two melodies.
    % A high count means the melodies are likely similar.
    count = 0;
    for i = 1:length(shingle_set)
        if bloom_check(bf, shingle_set(i))
            count = count + 1;
        end
    end
end

function positions = get_bit_positions(hash_val, num_hashes, num_bits)
    % Derives num_hashes bit positions from a single hash value.
    % Uses double hashing: simulates multiple hash functions from just two.
    h1 = mod(hash_val, num_bits) + 1;
    h2 = mod(floor(hash_val / num_bits), num_bits) + 1;
    positions = zeros(1, num_hashes);
    for i = 1:num_hashes
        positions(i) = mod(h1 + (i - 1) * h2, num_bits) + 1;
    end
    positions = unique(positions);
end