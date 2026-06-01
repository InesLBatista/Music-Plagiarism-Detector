function sim = jaccard_similarity(set1, set2)
%JACCARD_SIMILARITY Compute the Jaccard similarity between two sets.
%   sim = jaccard_similarity(set1, set2) returns the ratio of the size of the
%   intersection to the size of the union of the two sets.

    if isempty(set1) || isempty(set2)
        sim = 0;
        return;
    end
    
    % Ensure inputs are treated as sets (unique elements)
    if ~isnumeric(set1) || ~isnumeric(set2)
        % Handle non-numeric sets if necessary, but usually shingles are numeric hashes
        inter = numel(intersect(set1, set2));
        union_sz = numel(union(set1, set2));
    else
        inter = numel(intersect(set1, set2));
        union_sz = numel(union(set1, set2));
    end
    
    if union_sz == 0
        sim = 0;
    else
        sim = inter / union_sz;
    end
end
