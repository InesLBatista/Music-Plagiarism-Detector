function result = bloom_check(bf, shingle_hash)
%BLOOM_CHECK Return true if hash may be in the Bloom filter.

    positions = local_bit_positions(shingle_hash, bf.num_hashes, bf.num_bits);
    result = all(bf.bits(positions));
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
