% Test script for detection.m
addpath('../src');

% Paths to some MIDI files for testing
data_dir = '../data/maestro-v3.0.0/2004/';
midi_files = {
    'MIDI-Unprocessed_SMF_02_R1_2004_01-05_ORIG_MID--AUDIO_02_R1_2004_06_Track06_wav.midi',
    'MIDI-Unprocessed_SMF_02_R1_2004_01-05_ORIG_MID--AUDIO_02_R1_2004_08_Track08_wav.midi',
    'MIDI-Unprocessed_SMF_02_R1_2004_01-05_ORIG_MID--AUDIO_02_R1_2004_10_Track10_wav.midi'
};

full_paths = cellfun(@(x) fullfile(data_dir, x), midi_files, 'UniformOutput', false);

% Test 1: Compare a file with itself (should be 1.0)
fprintf('Test 1: Self-comparison\n');
query = full_paths{1};
database = full_paths;
[sim, candidates] = detect_plagiarism(query, database);
fprintf('Max Similarity: %.4f\n', sim);
assert(sim == 1.0, 'Self-comparison should return 1.0 similarity');

% Test 2: Compare a file with others
fprintf('\nTest 2: Comparison with others\n');
query = full_paths{1};
database = full_paths(2:3);
[sim, candidates] = detect_plagiarism(query, database);
fprintf('Max Similarity: %.4f\n', sim);
for i = 1:length(candidates)
    fprintf('Candidate %d: %s (Similarity: %.4f)\n', i, candidates(i).path, candidates(i).similarity);
end

fprintf('\nAll tests passed!\n');
