function bf = bloom_add_set(bf, shingle_set)
%BLOOM_ADD_SET Insert all shingle hashes into a Bloom filter.

    for i = 1:numel(shingle_set)
        positions = local_bit_positions(shingle_set(i), bf.num_hashes, bf.num_bits);
        bf.bits(positions) = true;
    end
end

function positions = local_bit_positions(hash_val, num_hashes, num_bits)
    h1 = mod(hash_val, num_bits) + 1;
    h2 = mod(floor(hash_val / num_bits), num_bits) + 1;

    positions = zeros(1, num_hashes);
    for k = 1:num_hashes
        positions(k) = mod(h1 + (k - 1) * h2, num_bits) + 1;
    end
    positions = unique(positions);
end
