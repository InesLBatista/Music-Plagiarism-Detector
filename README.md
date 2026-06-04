# Music Plagiarism Detector

MATLAB project for supporting the detection of possible music plagiarism cases through melody comparison. The core idea is to transform music into comparable sequences, generate small fragments with k-shingles, and measure similarity between those fragments.

The current focus is on comparing melodies represented as pairs:
```matlab
(melodic_interval, quantized_duration)
```
This makes it possible to compare not only pitch movement, but also the rhythm associated with each melodic movement.

## Objective
The system aims to:
- read musical data, especially MIDI files;
- extract normalized musical events;
- convert those events into sequences of melodic intervals and quantized durations;
- generate shingles of 8 musical pairs;
- compare melodies using efficient structures such as Bloom Filter, MinHash, and LSH;
- support classification with Naive Bayes when labeled data is available.

## Project Structure
```text
Music-Plagiarism-Detector/
├── data/      Musical data, including MIDI datasets such as MAESTRO
├── docs/      Documentation
├── src/       MATLAB source code
└── tests/     MATLAB test scripts
```

Main files in src/:
- midi_to_note_events.m: reads MIDI files and extracts normalized musical events.
- melody_events_to_interval_duration_sequence.m: converts events into `(melodic_interval, quantized_duration)` sequences.
- generate_interval_duration_sequence_from_midi.m: end-to-end helper from MIDI to sequence.
- get_interval_duration_shingle_set.m: generates shingles of 8 `(interval, duration)` pairs.
- preprocessing.m: preprocesses simple melodies manually represented as notes and durations.
- shingles.m: generates shingles for interval sequences or interleaved pitch/rhythm sequences.
- bloom_filter.m: Bloom Filter implementation for fast shingle presence checks.
- minhash_lsh.m: MinHash and Locality Sensitive Hashing implementation.
- naive_bayes.m: Multinomial Naive Bayes classifier.
- detection.m: detection integration module, still to be implemented.
- main.m: main executable script, still to be implemented.

## Current Pipeline
For MIDI datasets, the expected pipeline is:
```text
MIDI
  -> normalized musical events
  -> melody extraction
  -> sequence (melodic_interval, quantized_duration)
  -> shingles of 8 pairs
  -> comparison/similarity
```

### 1. MIDI To Events
midi_to_note_events.m transforms MIDI note on and note off messages into an intermediate representation containing:
- MIDI note number;
- pitch class;
- note name;
- onset in ticks and beats;
- duration in ticks and beats;
- velocity;
- channel;
- track.
This stage is important because MIDI files are raw musical data. Before evaluating plagiarism, MIDI events must be converted into a comparable musical representation.

### 2. Events To Musical Sequence
melody_events_to_interval_duration_sequence.m converts normalized events into an N x 2 matrix:
```matlab
[melodic_interval, quantized_duration]
```
Each row represents the movement from the previous note to the current note, paired with the quantized duration of the current note.

By default, for polyphonic piano MIDI, the system uses:
```matlab
options.extraction = 'top_note_per_onset';
```
This means that when several notes start at the same time, the highest note is selected as a simple approximation of the main melody.

### 3. Sequence To Shingles
get_interval_duration_shingle_set.m generates shingles over complete pairs. Therefore, when k = 8, the system compares 8 musical pairs:
```text
[(interval1, duration1), ..., (interval8, duration8)]
```
This is different from interleaving pitch and rhythm into a single list, because each musical element explicitly preserves the relationship between interval and duration.

## Usage Example
```matlab
addpath('src');

midi_path = 'data/maestro-v3.0.0/2018/MIDI-Unprocessed_Chamber3_MID--AUDIO_10_R3_2018_wav--1.midi';

options.duration_grid = 0.25;      % sixteenth-note grid in quarter-note beats
options.extraction = 'top_note_per_onset';
options.interval_mod12 = false;    % keep signed interval direction

[sequence, melody, events, info] = generate_interval_duration_sequence_from_midi(midi_path, options);
shingle_set = get_interval_duration_shingle_set(sequence, 8);
```
Main output:
```matlab
sequence
```
with format:
```matlab
[melodic_interval, quantized_duration]
```

## Run Main And Demo
Start MATLAB in the project root and run:

```matlab
addpath('src');
```

### Main (Default: all-vs-all)
By default, `main` compares every MIDI file in the dataset as query against all other files (excluding itself):

```matlab
r = main;
```

Useful options:

```matlab
% Run on a smaller subset (faster debug)
r = main('max_database', 20);

% Show more rows in terminal report
r = main('max_database', 20, 'top_k_display', 25);

% Single-query mode (query against selected database)
r = main('all_vs_all', false, 'max_database', 30);
```

`main` returns a struct. In all-vs-all mode, key fields are:
- `r.mode` (`'all_vs_all'`)
- `r.total_queries`
- `r.query_reports`
- `r.global_pairs_ranked`

### Demo Mode
Demo mode runs presentation scenarios (self-match, different-file control, half-similar simulation, and mini multi-vs-multi):

```matlab
d = main('demo_mode', true);
```

Useful demo options:

```matlab
% Define mini multi-vs-multi subset size used in demo scenario D
d = main('demo_mode', true, 'demo_all_vs_all_size', 6);

% Show more top pairs/candidates in demo reports
d = main('demo_mode', true, 'demo_all_vs_all_size', 8, 'top_k_display', 10);
```

`demo_mode` returns a struct with scenario outputs, including:
- `d.self_scenario`
- `d.diff_scenario`
- `d.half_similar_scenario`
- `d.multi_vs_multi_scenario`

### Dataset results and report generation
A new reporting helper generates integrated dataset analytics and saves outputs into the `results/` directory.

```matlab
r = generate_dataset_report();
```

This writes:
- `results/dataset_summary.txt`
- `results/top_pairs.csv`
- `results/hist_best_similarity.png`
- `results/query_vs_database_top_candidates.png`
- `results/dataset_report.mat`

Custom options are supported:

```matlab
r = generate_dataset_report('max_database', 50, 'results_dir', fullfile(pwd, 'results', 'my_report'));
```

### Recommended quick validation flow
1. `r = main('max_database', 4, 'top_k_display', 3);`
2. `d = main('demo_mode', true, 'demo_all_vs_all_size', 4);`
3. `r = main;` (full dataset)

## Comparison Modules
### Bloom Filter
The Bloom Filter allows the system to quickly check whether certain shingles may exist in a reference melody. It is useful as a first filtering step because it is fast and does not produce false negatives, although it may produce false positives.

### MinHash And LSH
MinHash creates compact signatures for shingle sets. LSH groups similar signatures to find candidates without comparing every song against every other song.
Final validation uses Jaccard similarity:
```text
J(A, B) = |A ∩ B| / |A ∪ B|
```

### Naive Bayes
The Naive Bayes classifier can be used when labeled examples are available. It accepts both numeric feature matrices and shingle sets, converting shingles into a count matrix.
- define a final plagiarism score;
- validate the system with real MAESTRO subsets;
- improve melody extraction for polyphonic MIDI.

