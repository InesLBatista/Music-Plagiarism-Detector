function sim = jaccard_similarity(set1, set2)
%JACCARD_SIMILARITY Compute the Jaccard similarity between two sets.
%   sim = jaccard_similarity(set1, set2) returns the ratio of the size of the
%   intersection to the size of the union of the two sets.

    if nargin < 2
        error('jaccard_similarity requires two input arguments.');
    end

    if isempty(set1) || isempty(set2)
        sim = 0;
        return;
    end

    set1 = normalize_set_input(set1);
    set2 = normalize_set_input(set2);

    if isempty(set1) || isempty(set2)
        sim = 0;
        return;
    end

    inter = numel(intersect(set1, set2));
    union_sz = numel(union(set1, set2));

    if union_sz == 0
        sim = 0;
    else
        sim = inter / union_sz;
    end
end

function set_out = normalize_set_input(set_in)
    if ischar(set_in)
        set_in = cellstr(set_in);
    elseif isstring(set_in)
        set_in = cellstr(set_in);
    end

    if isnumeric(set_in) || islogical(set_in) || iscell(set_in)
        set_out = unique(set_in);
    else
        try
            set_out = unique(set_in);
        catch
            set_out = unique(cellstr(set_in));
        end
    end
end
