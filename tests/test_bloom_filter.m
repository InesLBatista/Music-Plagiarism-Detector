test_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(test_dir, '..', 'src'));

% This test targets the intended public Bloom Filter functions.
% If MATLAB cannot find bloom_create, split bloom_filter.m into one file per
% public function or rename the file/function according to MATLAB rules.

% Bloom Filter should report inserted shingles as probably present.
bf = bloom_create(200, 4);
shingle_set = [101, 202, 303, 404];
bf = bloom_add_set(bf, shingle_set);

for i = 1:numel(shingle_set)
    assert(bloom_check(bf, shingle_set(i)));
end

match_count = bloom_count_matches(bf, [101, 202, 999]);
assert(match_count >= 2);

% This test intentionally does not assert a non-member is false, because
% Bloom Filters can produce false positives by design.
disp('bloom filter tests passed');
