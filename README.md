# Music-Plagiarism-Detector
A music plagiarism detection tool based on the “8-note rule,” using k-shingles of note sequences to compare melodies. It leverages Naive Bayes, MinHash with LSH, and Bloom Filters to efficiently detect exact and near-duplicate musical patterns.
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