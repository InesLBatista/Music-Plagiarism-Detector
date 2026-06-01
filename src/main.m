% This should orchestrate dataset loading, preprocessing, detection, and output reporting.

function results = main(varargin)
%MAIN Execute end-to-end plagiarism detection and print a ranked report.
%   RESULTS = MAIN() runs the pipeline with default settings over MAESTRO.
%   RESULTS = MAIN('Name', Value, ...) customizes query/database/options.

	root_dir = fileparts(fileparts(mfilename('fullpath')));
	src_dir = fullfile(root_dir, 'src');
	addpath(src_dir);

	params = parse_inputs(root_dir, varargin{:});
	if params.demo_mode
		results = run_demo_mode(params);
		return;
	end
	if params.all_vs_all
		results = run_all_vs_all(params);
		return;
	end
	[query_midi, database_midis] = resolve_query_and_database(params);

	fprintf('--- Music Plagiarism Detector ---\n');
	fprintf('Query MIDI: %s\n', query_midi);
	fprintf('Database size: %d\n', numel(database_midis));

	detection_options = struct();
	detection_options.duration_grid = params.duration_grid;
	detection_options.extraction = params.extraction;
	detection_options.interval_mod12 = params.interval_mod12;
	detection_options.shingle_k = params.shingle_k;
	detection_options.bf_threshold = params.bf_threshold;
	detection_options.num_hashes = params.num_hashes;
	detection_options.bands = params.bands;

	method = 'baseline_jaccard';
	fallback_reason = '';

	if params.use_detection_module
		try
			[max_similarity, candidates] = detect_plagiarism(query_midi, database_midis, detection_options);
			method = 'detection_module';
		catch ME
			fallback_reason = ME.message;
			fprintf('Warning: detection module failed, switching to baseline.\n');
			fprintf('Reason: %s\n', fallback_reason);
			[max_similarity, candidates] = baseline_detect(query_midi, database_midis, detection_options);
		end
	else
		[max_similarity, candidates] = baseline_detect(query_midi, database_midis, detection_options);
	end

	print_report(candidates, max_similarity, method, params.top_k_display);

	results = struct();
	results.query_midi = query_midi;
	results.database_midis = database_midis;
	results.max_similarity = max_similarity;
	results.candidates = candidates;
	results.method = method;
	results.options = detection_options;
	results.fallback_reason = fallback_reason;
end

function params = parse_inputs(root_dir, varargin)
	parser = inputParser;
	parser.FunctionName = 'main';

	addParameter(parser, 'query_midi', '', @(x) ischar(x) || isstring(x));
	addParameter(parser, 'database_midis', {}, @(x) iscell(x) || isstring(x));
	addParameter(parser, 'data_dir', fullfile(root_dir, 'data', 'maestro-v3.0.0'), @(x) ischar(x) || isstring(x));
	addParameter(parser, 'max_database', inf, @(x) isnumeric(x) && isscalar(x) && x >= 1);
	addParameter(parser, 'top_k_display', 10, @(x) isnumeric(x) && isscalar(x) && x >= 1);
	addParameter(parser, 'recursive', true, @(x) islogical(x) || isnumeric(x));
	addParameter(parser, 'use_detection_module', true, @(x) islogical(x) || isnumeric(x));
	addParameter(parser, 'demo_mode', false, @(x) islogical(x) || isnumeric(x));
	addParameter(parser, 'demo_all_vs_all_size', 6, @(x) isnumeric(x) && isscalar(x) && x >= 2);
	addParameter(parser, 'all_vs_all', true, @(x) islogical(x) || isnumeric(x));

	addParameter(parser, 'shingle_k', 8, @(x) isnumeric(x) && isscalar(x) && x >= 1);
	addParameter(parser, 'duration_grid', 0.25, @(x) isnumeric(x) && isscalar(x) && x > 0);
	addParameter(parser, 'extraction', 'top_note_per_onset', @(x) ischar(x) || isstring(x));
	addParameter(parser, 'interval_mod12', false, @(x) islogical(x) || isnumeric(x));
	addParameter(parser, 'bf_threshold', 0.5, @(x) isnumeric(x) && isscalar(x) && x >= 0 && x <= 1);
	addParameter(parser, 'num_hashes', 100, @(x) isnumeric(x) && isscalar(x) && x >= 1);
	addParameter(parser, 'bands', 20, @(x) isnumeric(x) && isscalar(x) && x >= 1);

	parse(parser, varargin{:});
	params = parser.Results;

	params.query_midi = char(string(params.query_midi));
	params.data_dir = char(string(params.data_dir));
	params.extraction = char(string(params.extraction));

	if isstring(params.database_midis)
		params.database_midis = cellstr(params.database_midis);
	end
end

function all_results = run_all_vs_all(params)
	all_midis = collect_midi_files(params.data_dir, logical(params.recursive));
	if isempty(all_midis)
		error('main:NoMidiFound', 'No MIDI files were found in %s.', params.data_dir);
	end

	if ~isinf(params.max_database)
		max_n = min(params.max_database, numel(all_midis));
		all_midis = all_midis(1:max_n);
	end

	if numel(all_midis) < 2
		error('main:NotEnoughMidiForAllVsAll', ...
			'All-vs-all mode requires at least 2 MIDI files.');
	end

	detection_options = struct();
	detection_options.duration_grid = params.duration_grid;
	detection_options.extraction = params.extraction;
	detection_options.interval_mod12 = params.interval_mod12;
	detection_options.shingle_k = params.shingle_k;
	detection_options.bf_threshold = params.bf_threshold;
	detection_options.num_hashes = params.num_hashes;
	detection_options.bands = params.bands;

	n = numel(all_midis);
	fprintf('--- Music Plagiarism Detector (All-vs-All) ---\n');
	fprintf('Total queries: %d\n', n);
	fprintf('Comparisons per query: %d\n', n - 1);

	query_reports = repmat(struct( ...
		'query_path', '', ...
		'max_similarity', 0, ...
		'method', '', ...
		'fallback_reason', '', ...
		'top_candidates', []), n, 1);

	pair_rows = repmat(struct('query_index', 0, 'candidate_index', 0, 'similarity', 0, ...
		'query_path', '', 'candidate_path', ''), 0, 1);

	for i = 1:n
		query_midi = all_midis{i};
		database_midis = all_midis([1:i-1, i+1:end]);

		[max_similarity, candidates, method, fallback_reason] = run_detection_pipeline( ...
			query_midi, database_midis, detection_options, logical(params.use_detection_module));

		top_n = min(params.top_k_display, numel(candidates));
		if top_n > 0
			top_candidates = candidates(1:top_n);
		else
			top_candidates = candidates;
		end

		query_reports(i).query_path = query_midi;
		query_reports(i).max_similarity = max_similarity;
		query_reports(i).method = method;
		query_reports(i).fallback_reason = fallback_reason;
		query_reports(i).top_candidates = top_candidates;

		for j = 1:numel(candidates)
			pair_rows(end + 1) = struct( ...
				'query_index', i, ...
				'candidate_index', candidates(j).index, ...
				'similarity', candidates(j).similarity, ...
				'query_path', query_midi, ...
				'candidate_path', candidates(j).path); %#ok<AGROW>
		end

		fprintf('Processed query %d/%d | max_similarity=%.4f\n', i, n, max_similarity);
	end

	all_scores = [query_reports.max_similarity];
	fprintf('--- All-vs-All Summary ---\n');
	fprintf('Queries processed: %d\n', n);
	fprintf('Mean best similarity per query: %.4f\n', mean(all_scores));
	fprintf('Median best similarity per query: %.4f\n', median(all_scores));
	fprintf('Global max similarity: %.4f\n', max(all_scores));

	if ~isempty(pair_rows)
		[~, idx] = sort([pair_rows.similarity], 'descend');
		pair_rows = pair_rows(idx);
		top_pairs_n = min(params.top_k_display, numel(pair_rows));
		fprintf('Top %d query-candidate pairs overall:\n', top_pairs_n);
		for k = 1:top_pairs_n
			fprintf('  %2d) %.4f\n      Q: %s\n      C: %s\n', ...
				k, pair_rows(k).similarity, pair_rows(k).query_path, pair_rows(k).candidate_path);
		end
	end

	all_results = struct();
	all_results.mode = 'all_vs_all';
	all_results.total_queries = n;
	all_results.total_comparisons_per_query = n - 1;
	all_results.query_reports = query_reports;
	all_results.global_pairs_ranked = pair_rows;
	all_results.options = detection_options;
end

function demo_results = run_demo_mode(params)
	all_midis = collect_midi_files(params.data_dir, logical(params.recursive));
	if numel(all_midis) < 3
		error('main:NotEnoughMidiForDemo', ...
			'Demo mode requires at least 3 MIDI files in %s.', params.data_dir);
	end

	detection_options = struct();
	detection_options.duration_grid = params.duration_grid;
	detection_options.extraction = params.extraction;
	detection_options.interval_mod12 = params.interval_mod12;
	detection_options.shingle_k = params.shingle_k;
	detection_options.bf_threshold = params.bf_threshold;
	detection_options.num_hashes = params.num_hashes;
	detection_options.bands = params.bands;

	query_midi = all_midis{1};
	contrast_midi = all_midis{2};
	aux_midi = all_midis{3};

	fprintf('=== DEMO MODE (Presentation) ===\n');
	fprintf('Query: %s\n', query_midi);
	fprintf('Contrast candidate: %s\n', contrast_midi);
	fprintf('Aux candidate: %s\n\n', aux_midi);

	% Scenario A: query compared with itself plus one different MIDI.
	fprintf('Scenario A: Self-match control\n');
	db_self = {query_midi, contrast_midi};
	[self_max, self_candidates, self_method, self_fallback] = run_detection_pipeline( ...
		query_midi, db_self, detection_options, logical(params.use_detection_module));
	print_report(self_candidates, self_max, self_method, params.top_k_display);

	if ~isempty(self_fallback)
		fprintf('Scenario A fallback reason: %s\n', self_fallback);
	end
	fprintf('\n');

	% Scenario B: different query with no identical item in DB.
	fprintf('Scenario B: Different-file control\n');
	db_diff = {query_midi, aux_midi};
	[diff_max, diff_candidates, diff_method, diff_fallback] = run_detection_pipeline( ...
		contrast_midi, db_diff, detection_options, logical(params.use_detection_module));
	print_report(diff_candidates, diff_max, diff_method, params.top_k_display);

	if ~isempty(diff_fallback)
		fprintf('Scenario B fallback reason: %s\n', diff_fallback);
	end
	fprintf('\n');

	% Scenario C: simulated half-similar control at feature level.
	fprintf('Scenario C: Simulated half-similar control (feature-level)\n');
	[half_results, half_ok] = simulate_half_similar(query_midi, contrast_midi, detection_options);
	if half_ok
		fprintf('Hybrid set built with 50%% shingles from query and 50%% from contrast.\n');
		fprintf('Similarity(query, hybrid): %.4f\n', half_results.query_similarity);
		fprintf('Similarity(contrast, hybrid): %.4f\n', half_results.contrast_similarity);
	else
		fprintf('Could not build half-similar simulation (insufficient shingles).\n');
	end
	fprintf('\n');

	fprintf('--- Demo Summary ---\n');
	fprintf('Self-match max similarity: %.4f\n', self_max);
	fprintf('Different-file max similarity: %.4f\n', diff_max);
	if half_ok
		fprintf('Half-similar simulated score: %.4f\n', half_results.query_similarity);
	end
	if self_max > diff_max
		fprintf('Expected behavior confirmed: self-match score is higher.\n');
	else
		fprintf('Warning: self-match score is not higher. Consider tuning shingle_k/duration_grid.\n');
	end
	fprintf('\n');

	% Scenario D: mini all-vs-all demo on a small subset.
	multi_n = min(numel(all_midis), params.demo_all_vs_all_size);
	multi_list = all_midis(1:multi_n);
	fprintf('Scenario D: Multi-vs-multi control (%d files)\n', multi_n);
	multi_results = run_multi_vs_multi_demo( ...
		multi_list, detection_options, logical(params.use_detection_module), params.top_k_display);
	fprintf('Mean best similarity: %.4f\n', multi_results.mean_best_similarity);
	fprintf('Median best similarity: %.4f\n', multi_results.median_best_similarity);
	fprintf('Global max similarity: %.4f\n', multi_results.global_max_similarity);

	demo_results = struct();
	demo_results.mode = 'demo';
	demo_results.query_midi = query_midi;
	demo_results.contrast_midi = contrast_midi;
	demo_results.aux_midi = aux_midi;
	demo_results.self_scenario = struct( ...
		'max_similarity', self_max, ...
		'candidates', self_candidates, ...
		'method', self_method, ...
		'fallback_reason', self_fallback);
	demo_results.diff_scenario = struct( ...
		'max_similarity', diff_max, ...
		'candidates', diff_candidates, ...
		'method', diff_method, ...
		'fallback_reason', diff_fallback);
	demo_results.half_similar_scenario = struct( ...
		'available', half_ok, ...
		'results', half_results);
	demo_results.multi_vs_multi_scenario = multi_results;
	demo_results.options = detection_options;
end

function multi_results = run_multi_vs_multi_demo(midi_list, detection_options, use_detection_module, top_k_display)
	n = numel(midi_list);
	query_reports = repmat(struct( ...
		'query_path', '', ...
		'max_similarity', 0, ...
		'method', '', ...
		'fallback_reason', ''), n, 1);

	pair_rows = repmat(struct('query_path', '', 'candidate_path', '', 'similarity', 0), 0, 1);

	for i = 1:n
		query_midi = midi_list{i};
		database_midis = midi_list([1:i-1, i+1:end]);

		[max_similarity, candidates, method, fallback_reason] = run_detection_pipeline( ...
			query_midi, database_midis, detection_options, use_detection_module);

		query_reports(i).query_path = query_midi;
		query_reports(i).max_similarity = max_similarity;
		query_reports(i).method = method;
		query_reports(i).fallback_reason = fallback_reason;

		for j = 1:numel(candidates)
			pair_rows(end + 1) = struct( ...
				'query_path', query_midi, ...
				'candidate_path', candidates(j).path, ...
				'similarity', candidates(j).similarity); %#ok<AGROW>
		end
	end

	if isempty(pair_rows)
		top_pairs = pair_rows;
	else
		[~, idx] = sort([pair_rows.similarity], 'descend');
		pair_rows = pair_rows(idx);
		top_n = min(top_k_display, numel(pair_rows));
		top_pairs = pair_rows(1:top_n);

		fprintf('Top %d pairs in multi-vs-multi:\n', top_n);
		for k = 1:top_n
			fprintf('  %2d) %.4f\n      Q: %s\n      C: %s\n', ...
				k, top_pairs(k).similarity, top_pairs(k).query_path, top_pairs(k).candidate_path);
		end
	end

	best_scores = [query_reports.max_similarity];
	multi_results = struct();
	multi_results.total_queries = n;
	multi_results.query_reports = query_reports;
	multi_results.mean_best_similarity = mean(best_scores);
	multi_results.median_best_similarity = median(best_scores);
	multi_results.global_max_similarity = max(best_scores);
	multi_results.top_pairs = top_pairs;
end

function [results, ok] = simulate_half_similar(query_midi, contrast_midi, options)
	q_shingles = shingle_set_from_midi(query_midi, options);
	c_shingles = shingle_set_from_midi(contrast_midi, options);

	results = struct( ...
		'query_similarity', NaN, ...
		'contrast_similarity', NaN, ...
		'hybrid_size', 0, ...
		'query_source_count', 0, ...
		'contrast_source_count', 0);

	if numel(q_shingles) < 2 || numel(c_shingles) < 2
		ok = false;
		return;
	end

	q_count = floor(numel(q_shingles) / 2);
	c_count = floor(numel(c_shingles) / 2);
	if q_count < 1 || c_count < 1
		ok = false;
		return;
	end

	q_part = q_shingles(1:q_count);
	c_part = c_shingles(1:c_count);
	hybrid = unique([q_part(:); c_part(:)])';

	results.query_similarity = jaccard_similarity(q_shingles, hybrid);
	results.contrast_similarity = jaccard_similarity(c_shingles, hybrid);
	results.hybrid_size = numel(hybrid);
	results.query_source_count = numel(q_part);
	results.contrast_source_count = numel(c_part);
	ok = true;
end

function [max_similarity, candidates, method, fallback_reason] = run_detection_pipeline( ...
		query_midi, database_midis, detection_options, use_detection_module)
	method = 'baseline_jaccard';
	fallback_reason = '';

	if use_detection_module
		try
			[max_similarity, candidates] = detect_plagiarism(query_midi, database_midis, detection_options);
			method = 'detection_module';
		catch ME
			fallback_reason = ME.message;
			[max_similarity, candidates] = baseline_detect(query_midi, database_midis, detection_options);
		end
	else
		[max_similarity, candidates] = baseline_detect(query_midi, database_midis, detection_options);
	end
end

function [query_midi, database_midis] = resolve_query_and_database(params)
	all_midis = collect_midi_files(params.data_dir, logical(params.recursive));
	if isempty(all_midis)
		error('main:NoMidiFound', 'No MIDI files were found in %s.', params.data_dir);
	end

	if isempty(params.query_midi)
		query_midi = all_midis{1};
	else
		query_midi = char(string(params.query_midi));
	end

	if ~isfile(query_midi)
		error('main:QueryNotFound', 'Query MIDI not found: %s', query_midi);
	end

	if isempty(params.database_midis)
		others = all_midis(~strcmp(all_midis, query_midi));
		max_n = min(params.max_database, numel(others));
		database_midis = others(1:max_n);
	else
		database_midis = cellfun(@char, cellstr(string(params.database_midis)), 'UniformOutput', false);
	end

	if isempty(database_midis)
		error('main:EmptyDatabase', 'Database MIDI list is empty after filtering query file.');
	end
end

function files = collect_midi_files(base_dir, recursive)
	if ~isfolder(base_dir)
		error('main:DataDirNotFound', 'Data directory not found: %s', base_dir);
	end

	if recursive
		midi_a = dir(fullfile(base_dir, '**', '*.midi'));
		midi_b = dir(fullfile(base_dir, '**', '*.mid'));
	else
		midi_a = dir(fullfile(base_dir, '*.midi'));
		midi_b = dir(fullfile(base_dir, '*.mid'));
	end

	files = cell(1, numel(midi_a) + numel(midi_b));
	k = 1;
	for i = 1:numel(midi_a)
		files{k} = fullfile(midi_a(i).folder, midi_a(i).name);
		k = k + 1;
	end
	for i = 1:numel(midi_b)
		files{k} = fullfile(midi_b(i).folder, midi_b(i).name);
		k = k + 1;
	end
	files = unique(files);
	files = sort(files);
end

function [max_similarity, candidates] = baseline_detect(query_midi, database_midis, options)
	q_shingles = shingle_set_from_midi(query_midi, options);

	candidates = repmat(struct('index', 0, 'path', '', 'similarity', 0, 'bf_estimate', NaN), 0, 1);
	for i = 1:numel(database_midis)
		db_shingles = shingle_set_from_midi(database_midis{i}, options);
		sim = jaccard_similarity(q_shingles, db_shingles);
		candidates(end + 1) = struct( ...
			'index', i, ...
			'path', database_midis{i}, ...
			'similarity', sim, ...
			'bf_estimate', NaN); %#ok<AGROW>
	end

	if isempty(candidates)
		max_similarity = 0;
		return;
	end

	[~, idx] = sort([candidates.similarity], 'descend');
	candidates = candidates(idx);
	max_similarity = candidates(1).similarity;
end

function shingles = shingle_set_from_midi(midi_path, options)
	[sequence, ~, ~, ~] = generate_interval_duration_sequence_from_midi(midi_path, options);
	shingles = get_interval_duration_shingle_set(sequence, options.shingle_k);
end

function print_report(candidates, max_similarity, method, top_k_display)
	fprintf('Detection method: %s\n', method);
	fprintf('Max similarity: %.4f\n', max_similarity);

	if isempty(candidates)
		fprintf('No candidates were produced.\n');
		return;
	end

	top_n = min(top_k_display, numel(candidates));
	fprintf('Top %d candidates (of %d compared):\n', top_n, numel(candidates));
	for i = 1:top_n
		fprintf('  %2d) %.4f  %s\n', i, candidates(i).similarity, candidates(i).path);
	end
end
