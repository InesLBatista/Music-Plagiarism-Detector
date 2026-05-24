test_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(test_dir, '..', 'src'));

% This test targets the intended public MinHash/LSH functions.
% If MATLAB cannot find these functions, split minhash_lsh.m into one file
% per public function or expose a wrapper function.

% Identical shingle sets must have identical MinHash signatures.
set_a = [10, 20, 30, 40, 50];
set_b = [10, 20, 30, 40, 50];
sig_a = minhash_signature(set_a, 20);
sig_b = minhash_signature(set_b, 20);
assert(isequal(sig_a, sig_b));

% LSH should report identical melodies as a similar pair.
shingle_sets = {
    [10, 20, 30, 40, 50], ...
    [10, 20, 30, 40, 50], ...
    [1000, 2000, 3000]
};

similar_pairs = find_similar_melodies_lsh(shingle_sets, 20, 5);
assert(any(ismember(similar_pairs, [1, 2], 'rows')));

disp('minhash/lsh tests passed');
