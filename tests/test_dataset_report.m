test_dir = fileparts(mfilename('fullpath'));
addpath(fullfile(test_dir, '..', 'src'));

results_dir = fullfile(test_dir, '..', 'results', 'test_report');
if exist(results_dir, 'dir')
    rmdir(results_dir, 's');
end

results = generate_dataset_report( ...
    'max_database', 10, ...
    'results_dir', results_dir, ...
    'top_k_display', 5, ...
    'use_detection_module', false);

assert(isstruct(results), 'generate_dataset_report must return a struct.');
assert(isfield(results, 'analysis'), 'Results struct must contain analysis data.');
assert(exist(fullfile(results_dir, 'dataset_summary.txt'), 'file') == 2, 'Summary text file must exist.');
assert(exist(fullfile(results_dir, 'hist_best_similarity.png'), 'file') == 2, 'Histogram image must be saved.');
assert(exist(fullfile(results_dir, 'top_pairs.csv'), 'file') == 2, 'Top pairs CSV must be saved.');
assert(exist(fullfile(results_dir, 'query_vs_database_top_candidates.png'), 'file') == 2, 'Query comparison plot must be saved.');

disp('dataset report tests passed');
