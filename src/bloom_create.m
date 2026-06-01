function bf = bloom_create(num_bits, num_hashes)
%BLOOM_CREATE Create an empty Bloom filter.
%   BF = BLOOM_CREATE(NUM_BITS, NUM_HASHES) initializes a Bloom filter struct.

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
