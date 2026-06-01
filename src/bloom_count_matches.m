function count = bloom_count_matches(bf, shingle_set)
%BLOOM_COUNT_MATCHES Count probable matches in a Bloom filter.

    count = 0;
    for i = 1:numel(shingle_set)
        if bloom_check(bf, shingle_set(i))
            count = count + 1;
        end
    end
end
