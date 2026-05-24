# Music Plagiarism Detector

## 1. Introduction

This project aims to develop a tool to detect possible cases of musical plagiarism through melody comparison. The main approach uses k-shingles to represent small melody fragments and compare those fragments between different songs.

The system works on a simplified representation of melody: sequences of notes and their respective durations. From this representation, pitch and rhythm features are extracted and then converted into comparable shingle sets.

## 2. Objectives

The main objectives of the project are:

- Represent melodies in a simple and comparable way.
- Normalize melodies to reduce irrelevant differences, such as transposition or small rhythmic variations.
- Generate shingles based on sequences of 8 elements.
- Compare melodies efficiently using probabilistic structures and hashing.

## 3. Project Structure

The project is organized into the following folders:

- `src/`: contains the MATLAB files.
- `data/`: reserved for musical input data or examples.
- `tests/`: reserved for tests.
- `docs/`: contains documentation, reports, and slides.

Main files in `src/`:

- `preprocessing.m`: melody preprocessing.
- `midi_to_note_events.m`: MIDI parsing into normalized note events.
- `melody_events_to_interval_duration_sequence.m`: conversion from note events to `(melodic_interval, quantized_duration)` sequences.
- `generate_interval_duration_sequence_from_midi.m`: end-to-end helper for MIDI files.
- `get_interval_duration_shingle_set.m`: shingle generation using 8 interval-duration pairs.
- `shingles.m`: shingle generation and hashing.
- `bloom_filter.m`: Bloom Filter implementation.
- `minhash_lsh.m`: MinHash and Locality Sensitive Hashing implementation.
- `naive_bayes.m`: Multinomial Naive Bayes classifier.
- `detection.m`: placeholder for detection integration.
- `main.m`: placeholder for the main script.

## 4. Implemented Modules

### 4.1 Preprocessing

The `preprocessing.m` module implements the first phase of the pipeline. It receives a melody represented as an array of structs, where each note has at least the fields `note` and `duration`.

The implemented operations include:

- removal of pauses/rests;
- removal of excessively short notes that may be noise;
- duration quantization to a 1/16 grid;
- conversion of notes into intervals;
- rhythmic normalization through ratios between consecutive durations.

The conversion to intervals is important because it makes the representation invariant to transposition. For example, two melodies with the same melodic contour but played in different keys can still be compared meaningfully.

### 4.1.1 MIDI Dataset Treatment

For datasets such as MAESTRO, the raw MIDI files must first be converted into a normalized intermediate representation. The implemented MIDI stage extracts note events with:

- MIDI note number;
- pitch class;
- note name;
- onset in ticks and beats;
- duration in ticks and beats;
- velocity;
- channel and track.

From these events, the project can generate sequences of `(melodic_interval, quantized_duration)`. By default, the melody extraction keeps the highest note at each onset, which is a simple approximation for piano melody extraction in polyphonic MIDI files.

Example:

```matlab
addpath('src');

midi_path = 'data/maestro-v3.0.0/2018/MIDI-Unprocessed_Chamber3_MID--AUDIO_10_R3_2018_wav--1.midi';

options.duration_grid = 0.25;      % sixteenth-note grid in quarter-note beats
options.extraction = 'top_note_per_onset';
options.interval_mod12 = false;    % keep signed melodic direction

[sequence, melody, events, info] = generate_interval_duration_sequence_from_midi(midi_path, options);
shingle_set = get_interval_duration_shingle_set(sequence, 8);
```

The resulting `sequence` is an `N x 2` matrix:

```matlab
[melodic_interval, quantized_duration]
```

Each row represents the movement from the previous melody note to the current note, paired with the current note duration.

### 4.2 Shingle Generation

The `shingles.m` module implements k-shingle generation. By default, the value used is `k = 8`, aligned with the 8-note rule.

Two variants were implemented:

- shingles based only on pitch intervals;
- combined shingles that interleave pitch and rhythm information.

Each shingle is converted into a numeric value through polynomial hashing. This allows melodic fragments to be stored and compared more efficiently than comparing full vectors.

Rhythm is discretized into 5 categories:

- much shorter;
- shorter;
- approximately equal;
- longer;
- much longer.

This discretization reduces sensitivity to small temporal variations while still preserving relevant rhythmic information.

### 4.3 Bloom Filter

The `bloom_filter.m` module implements a Bloom Filter for fast verification of possible shingle presence.

Implemented functionalities:

- creation of a Bloom Filter with a configurable number of bits and hash functions;
- insertion of a shingle;
- insertion of a set of shingles;
- verification of probable presence;
- counting of probable matches between a shingle set and the filter.

The Bloom Filter is suitable for initial filtering because it allows quick verification of whether certain shingles may have appeared in a reference melody. Since it is a probabilistic structure, it may produce false positives but not false negatives.

### 4.4 MinHash and LSH

The `minhash_lsh.m` module implements a strategy for finding similar melodies in a more scalable way.

Implemented components:

- generation of MinHash signatures for shingle sets;
- grouping of signatures into bands using Locality Sensitive Hashing;
- identification of candidate pairs that fall into the same bucket;
- validation of candidates through Jaccard similarity.

Jaccard similarity is calculated between shingle sets:

J(A, B) = |A ∩ B| / |A ∪ B|

In the current code, pairs with similarity equal to or greater than `0.8` are considered similar.

### 4.5 Naive Bayes

The `naive_bayes.m` module implements a Multinomial Naive Bayes classifier for melodies represented by extracted features.

Implemented components:

- classification from numeric feature matrices;
- classification from cell arrays of shingle hashes;
- automatic conversion of shingle sets into count-based feature matrices;
- Laplace smoothing through the `alpha` parameter;
- output of predicted labels, the trained model, and log posterior scores.

This module can be used after shingle extraction to classify melodies according to labeled training examples.

## 5. Planned Pipeline  

The complete planned pipeline for the system is:

1. Load or represent a melody as a sequence of notes and durations.
2. Apply preprocessing to obtain intervals and normalized rhythm.
3. Generate shingles of size 8.
4. Compare shingles using a Bloom Filter for fast filtering.
5. Use MinHash + LSH to find similar candidates in larger datasets.
6. Use Naive Bayes to classify melodies from extracted features when labeled data is available.
7. Validate candidates using Jaccard similarity.
8. Produce a final decision or possible plagiarism score.

## 6. Current Implementation Status

At the moment, the following components are implemented:

- preprocessing;
- shingle generation;
- Bloom Filter;
- MinHash + LSH;
- Jaccard similarity calculation for candidates;
- Multinomial Naive Bayes classifier.

The following components are still missing:

- integrated detection module;
- end-to-end executable main script;
- Musical file loading.


## 7. Next Steps

The recommended next steps are:

1. Implement `detection.m`, integrating preprocessing, shingles, Bloom Filter, and MinHash/LSH.
2. Implement `main.m` to execute the complete pipeline.
3. Validate the system with simple artificial melodies before using real data.
4. Add support for loading musical files.

## 8. Conclusion

The project already contains the main algorithmic foundation for comparing and classifying melodies through shingles, Bloom Filter, MinHash/LSH, Jaccard similarity, and Naive Bayes. The current implementation covers representation, normalization, efficient comparison, and feature-based classification of melodic fragments, but it still requires integration to become a complete musical plagiarism detection tool.

Future work should focus on connecting the existing modules, creating tests, and validating the system with real musical data.
