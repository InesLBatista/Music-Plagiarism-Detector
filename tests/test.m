% Run the complete project test suite, including dataset integration.

test_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(test_dir, '..', 'src'));

run(fullfile(test_dir, 'test_dataset_integration.m'));
run(fullfile(test_dir, 'test_midi_to_note_events.m'));
run(fullfile(test_dir, 'test_generate_interval_duration_sequence_from_midi.m'));
run(fullfile(test_dir, 'test_interval_duration_sequence.m'));
run(fullfile(test_dir, 'test_interval_duration_shingles.m'));
run(fullfile(test_dir, 'test_bloom_filter.m'));
run(fullfile(test_dir, 'test_minhash_lsh.m'));
run(fullfile(test_dir, 'test_naive_bayes.m'));
run(fullfile(test_dir, 'test_dataset_report.m'));
