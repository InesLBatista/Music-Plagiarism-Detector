% GENERATE_DATASET_REPORT Run the dataset analysis pipeline and save summary outputs.
%   RESULTS = GENERATE_DATASET_REPORT() analyzes the MAESTRO dataset and writes
%   plots, tables and summary files into the results/ directory.
%   RESULTS = GENERATE_DATASET_REPORT('Name', Value, ...) customizes the analysis.

function results = generate_dataset_report(varargin)
    root_dir = fileparts(fileparts(mfilename('fullpath')));
    src_dir = fullfile(root_dir, 'src');
    addpath(src_dir);

    params = parse_report_inputs(root_dir, varargin{:});
    if ~exist(params.results_dir, 'dir')
        mkdir(params.results_dir);
    end

    fprintf('Generating dataset report in %s\n', params.results_dir);

    % Run the integrated all-vs-all pipeline.
    all_results = main( ...
        'data_dir', params.data_dir, ...
        'max_database', params.max_database, ...
        'top_k_display', params.top_k_display, ...
        'all_vs_all', true, ...
        'use_detection_module', params.use_detection_module, ...
        'recursive', true, ...
        'shingle_k', params.shingle_k, ...
        'duration_grid', params.duration_grid, ...
        'extraction', params.extraction, ...
        'interval_mod12', params.interval_mod12, ...
        'bf_threshold', params.bf_threshold, ...
        'num_hashes', params.num_hashes, ...
        'bands', params.bands);

    results = struct();
    results.params = params;
    results.analysis = all_results;

    save(fullfile(params.results_dir, 'dataset_report.mat'), 'all_results', 'params');

    % Produce summary metrics and plots for the final report.
    similarity_scores = [all_results.query_reports.max_similarity];
    report_stats = build_report_stats(similarity_scores, all_results.global_pairs_ranked, params);
    results.summary = report_stats;

    write_summary_text(report_stats, all_results, params);
    export_top_pairs_table(all_results.global_pairs_ranked, params.results_dir);
    plot_best_similarity_histogram(similarity_scores, params.results_dir);
    plot_query_vs_database(params, params.results_dir);

    fprintf('Dataset report generation completed. Files written to %s\n', params.results_dir);
end

function params = parse_report_inputs(root_dir, varargin)
    parser = inputParser;
    parser.FunctionName = 'generate_dataset_report';

    addParameter(parser, 'data_dir', fullfile(root_dir, 'data', 'maestro-v3.0.0'), @(x) ischar(x) || isstring(x));
    addParameter(parser, 'max_database', inf, @(x) isnumeric(x) && isscalar(x) && x >= 1);
    addParameter(parser, 'results_dir', fullfile(root_dir, 'results'), @(x) ischar(x) || isstring(x));
    addParameter(parser, 'use_detection_module', true, @(x) islogical(x) || isnumeric(x));
    addParameter(parser, 'top_k_display', 10, @(x) isnumeric(x) && isscalar(x) && x >= 1);
    addParameter(parser, 'shingle_k', 8, @(x) isnumeric(x) && isscalar(x) && x >= 1);
    addParameter(parser, 'duration_grid', 0.25, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(parser, 'extraction', 'top_note_per_onset', @(x) ischar(x) || isstring(x));
    addParameter(parser, 'interval_mod12', false, @(x) islogical(x) || isnumeric(x));
    addParameter(parser, 'bf_threshold', 0.5, @(x) isnumeric(x) && isscalar(x) && x >= 0 && x <= 1);
    addParameter(parser, 'num_hashes', 100, @(x) isnumeric(x) && isscalar(x) && x >= 1);
    addParameter(parser, 'bands', 20, @(x) isnumeric(x) && isscalar(x) && x >= 1);

    parse(parser, varargin{:});
    params = parser.Results;

    params.data_dir = char(string(params.data_dir));
    params.results_dir = char(string(params.results_dir));
    params.extraction = char(string(params.extraction));
    params.all_vs_all = true;
end

function stats = build_report_stats(similarity_scores, global_pairs, params)
    stats.num_queries = numel(similarity_scores);
    stats.mean_best_similarity = mean(similarity_scores);
    stats.median_best_similarity = median(similarity_scores);
    stats.max_best_similarity = max(similarity_scores);
    stats.min_best_similarity = min(similarity_scores);
    stats.num_pairs_ranked = numel(global_pairs);
    stats.threshold_counts = struct();
    thresholds = [0.25, 0.5, 0.75, 0.9];
    names = {'above_025', 'above_050', 'above_075', 'above_090'};
    for i = 1:numel(thresholds)
        stats.threshold_counts.(names{i}) = sum(similarity_scores >= thresholds(i));
    end
    stats.dataset_path = params.data_dir;
    stats.max_database = params.max_database;
    stats.results_dir = params.results_dir;
end

function write_summary_text(stats, all_results, params)
    filename = fullfile(params.results_dir, 'dataset_summary.txt');
    fid = fopen(filename, 'w');
    cleaner = onCleanup(@() fclose(fid));

    fprintf(fid, 'Music Plagiarism Detector Dataset Report\n');
    fprintf(fid, 'Dataset directory: %s\n', stats.dataset_path);
    fprintf(fid, 'Results directory: %s\n', stats.results_dir);
    fprintf(fid, 'Files analyzed (max_database): %s\n', num2str(stats.max_database));
    fprintf(fid, '\nSummary metrics:\n');
    fprintf(fid, '  Queries analyzed: %d\n', stats.num_queries);
    fprintf(fid, '  Mean best similarity: %.4f\n', stats.mean_best_similarity);
    fprintf(fid, '  Median best similarity: %.4f\n', stats.median_best_similarity);
    fprintf(fid, '  Best similarity observed: %.4f\n', stats.max_best_similarity);
    fprintf(fid, '  Worst best similarity observed: %.4f\n', stats.min_best_similarity);
    fprintf(fid, '\nSimilarity thresholds:\n');
    fprintf(fid, '  >= 0.25: %d\n', stats.threshold_counts.above_025);
    fprintf(fid, '  >= 0.50: %d\n', stats.threshold_counts.above_050);
    fprintf(fid, '  >= 0.75: %d\n', stats.threshold_counts.above_075);
    fprintf(fid, '  >= 0.90: %d\n', stats.threshold_counts.above_090);
    fprintf(fid, '\nTop pairs in full dataset:\n');

    top_n = min(numel(all_results.global_pairs_ranked), params.top_k_display);
    for i = 1:top_n
        pair = all_results.global_pairs_ranked(i);
        fprintf(fid, '  %d) %.4f | Query: %s | Candidate: %s\n', i, pair.similarity, pair.query_path, pair.candidate_path);
    end
end

function export_top_pairs_table(global_pairs, results_dir)
    if isempty(global_pairs)
        return;
    end
    query_paths = {global_pairs.query_path}';
    candidate_paths = {global_pairs.candidate_path}';
    similarities = [global_pairs.similarity]';
    data_table = table(query_paths, candidate_paths, similarities, ...
        'VariableNames', {'QueryPath', 'CandidatePath', 'Similarity'});
    writetable(data_table, fullfile(results_dir, 'top_pairs.csv'));
end

function plot_best_similarity_histogram(similarity_scores, results_dir)
    fig = figure('Visible', 'off');
    
    % Define bins apropriados para a escala dos dados
    max_val = max(similarity_scores);
    if max_val <= 0.1
        % Para valores muito pequenos (como no teu caso), usa bins mais finos
        edges = 0:0.002:0.1;  % bins de 0.002 (0.2%) até 0.1
    else
        edges = 0:0.01:1;      % bins de 1% para valores normais
    end
    
    histogram(similarity_scores, edges, 'FaceColor', [0.2, 0.6, 0.8]);
    xlabel('Best similarity per query');
    ylabel('Number of queries');
    title('Dataset best-similarity distribution');
    
    % Adiciona linha vertical no limiar de plágio (0.01)
    hold on;
    line([0.01, 0.01], ylim, 'Color', 'red', 'LineStyle', '--', 'LineWidth', 1.5);
    legend({'Distribuição', 'Limiar de plágio (0.01)'}, 'Location', 'best');
    
    grid on;
    saveas(fig, fullfile(results_dir, 'hist_best_similarity.png'));
    close(fig);
end

function plot_query_vs_database(params, results_dir)
    all_midis = collect_midi_files(params.data_dir, true);
    if isempty(all_midis)
        return;
    end
    if ~isinf(params.max_database)
        all_midis = all_midis(1:min(numel(all_midis), params.max_database));
    end

    query_midi = all_midis{1};
    database_midis = all_midis(~strcmp(all_midis, query_midi));
    if isempty(database_midis)
        return;
    end

    q_shingles = shingle_set_from_midi(query_midi, params);
    similarities = zeros(numel(database_midis), 1);
    for i = 1:numel(database_midis)
        db_shingles = shingle_set_from_midi(database_midis{i}, params);
        similarities(i) = jaccard_similarity(q_shingles, db_shingles);
    end

    [sorted_values, sorted_indices] = sort(similarities, 'descend');
    sorted_paths = database_midis(sorted_indices);
    top_n = min(40, numel(sorted_values));

    fig = figure('Visible', 'off');
    bar(sorted_values(1:top_n), 'FaceColor', [0.4, 0.7, 0.3]);
    xlabel('Candidate index (sorted by similarity)');
    ylabel('Similarity to query');
    title(sprintf('Query vs database similarities\nQuery: %s', get_short_name(query_midi)));
    ylim([0, 1]);
    grid on;
    saveas(fig, fullfile(results_dir, 'query_vs_database_top_candidates.png'));
    close(fig);

    % Save the first query comparison details for the report.
    details_file = fullfile(results_dir, 'query_1_vs_database.csv');
    summary_table = table(sorted_paths(1:top_n)', sorted_values(1:top_n), ...
        'VariableNames', {'CandidatePath', 'Similarity'});
    writetable(summary_table, details_file);
end

function short_name = get_short_name(path)
    [~, name, ext] = fileparts(path);
    short_name = [name, ext];
end
