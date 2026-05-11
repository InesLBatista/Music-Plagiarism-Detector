# Music-Plagiarism-Detector
A music plagiarism detection tool based on the “8-note rule,” using k-shingles of note sequences to compare melodies. It leverages Naive Bayes, MinHash with LSH, and Bloom Filters to efficiently detect exact and near-duplicate musical patterns.

## Current Progress
- **TODO 1 (Preprocessing)**: Implemented data representation, normalization functions (notes_to_intervals, normalize_rhythm), extract_features for separate note and rhythm processing, and downloadMIDI for downloading MIDI files to data/.
- **TODO 2 (Shingles)**: Implemented k-shingles generation based on the 8-note rule. Includes sliding window over pitch intervals, polynomial rolling hash, rhythm quantization into 5 bins, and combined pitch+rhythm shingles. Functions split across shingles.m with unit tests in tests/.
- **TODO 3 (Bloom Filter)**: Implemented Bloom Filter for fast duplicate detection. Includes filter creation, single/batch insertion, membership check, and match counting between melody shingle sets. Functions split into bloom_create.m, bloom_add.m, bloom_add_set.m, bloom_check.m, bloom_count_matches.m with individual test files in tests/.

## Future Development
The project is structured as follows:

- **src/**: Contains the main MATLAB source code files.
  - main.m: Main script.
  - preprocessing.m: Data preprocessing.
  - shingles.m: K-shingles generation.
  - naive_bayes.m: Naive Bayes implementation.
  - minhash_lsh.m: MinHash and LSH.
  - bloom_filter.m: Bloom Filter.
  - detection.m: Core detection logic.

- **data/**: For sample music data files.

- **tests/**: Unit and integration tests.

- **docs/**: Documentation and reports.

Future tasks include implementing each module as per the TODOs in the code files, integrating them, and testing the system with real music data.