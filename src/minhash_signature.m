function sig = minhash_signature(shingle_set, num_hashes)
%MINHASH_SIGNATURE Compute MinHash signature for one shingle set.

    if nargin < 2
        num_hashes = 100;
    end

    if isempty(shingle_set)
        sig = zeros(1, num_hashes);
        return;
    end

    max_shingle = 2147483647;
    rng(42);
    a = randi([1, max_shingle], 1, num_hashes);
    b = randi([0, max_shingle], 1, num_hashes);
    p = 4294967311;

    sig = zeros(1, num_hashes);
    shingle_set = double(shingle_set);
    for i = 1:num_hashes
        hashes = mod(a(i) * shingle_set + b(i), p);
        sig(i) = min(hashes);
    end
end
