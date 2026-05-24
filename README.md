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

## Comparison Modules
### Bloom Filte
The Bloom Filter allows the system to quickly check whether certain shingles may exist in a reference melody. It is useful as a first filtering step because it is fast and does not produce false negatives, although it may produce false positives.

### MinHash And LSH
MinHash creates compact signatures for shingle sets. LSH groups similar signatures to find candidates without comparing every song against every other song.
Final validation uses Jaccard similarity:
```text
J(A, B) = |A ∩ B| / |A ∪ B|
```

### Naive Bayes
The Naive Bayes classifier can be used when labeled examples are available. It accepts both numeric feature matrices and shingle sets, converting shingles into a count matrix.

## Tests
Tests are located in tests/ and are separated by component:
- test_midi_to_note_events.m: tests basic MIDI parsing.
- test_generate_interval_duration_sequence_from_midi.m: tests the MIDI-to-sequence pipeline.
- test_interval_duration_sequence.m: tests sequence creation from artificial events.
- test_interval_duration_shingles.m: tests interval-duration pair shingles.
- test_bloom_filter.m: tests Bloom Filter operations.
- test_minhash_lsh.m: tests MinHash and LSH.
- test_naive_bayes.m: tests Naive Bayes classification.


## Current Status
Implemented:
- basic MIDI parsing;
- conversion from MIDI to normalized musical events;
- generation of `(melodic_interval, quantized_duration)` sequences;
- shingle generation over interval-duration pairs;
- preprocessing for simple melodies;
- Bloom Filter;
- MinHash and LSH;
- Jaccard similarity for candidates;
- Naive Bayes;
- component-level tests.

Still to do:
- integrate everything in `detection.m`;
- implement `main.m`;
- define a final plagiarism score;
- validate the system with real MAESTRO subsets;
- improve melody extraction for polyphonic MIDI.

