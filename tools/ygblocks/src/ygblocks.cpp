// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Zhi-Jie Xu
//
// YGBlocks - an independent reimplementation of the GBlocks 0.91b
// conserved-block selection for FASTA and PHYLIP alignments.
//
// The block-selection rules implemented here reproduce GBlocks for
// nucleotide, codon and protein alignments. Protein similarity uses the
// Gonnet 120-derived matrix.

#include <algorithm>
#include <array>
#include <cctype>
#include <fstream>
#include <iostream>
#include <map>
#include <sstream>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

using std::string;
using std::vector;

namespace AlnUtils {

enum class SeqType { Protein, DNA, Codon };

class AlnFileFormatError : public std::runtime_error {
public:
    explicit AlnFileFormatError(const string& message)
        : std::runtime_error(message) {}
};

class SequenceNotAlignedError : public std::runtime_error {
public:
    explicit SequenceNotAlignedError(const string& message)
        : std::runtime_error(message) {}
};

inline bool IsGapChar(char c) {
    return c == '-' || c == '.';
}

inline bool IsDNAState(char c) {
    switch (std::toupper(static_cast<unsigned char>(c))) {
    case 'A': case 'C': case 'G': case 'T': case 'U':
        return true;
    default:
        return false;
    }
}

inline bool IsProteinState(char c) {
    switch (std::toupper(static_cast<unsigned char>(c))) {
    case 'A': case 'C': case 'D': case 'E': case 'F':
    case 'G': case 'H': case 'I': case 'K': case 'L':
    case 'M': case 'N': case 'P': case 'Q': case 'R':
    case 'S': case 'T': case 'V': case 'W': case 'Y':
        return true;
    default:
        return false;
    }
}

struct AlnProfile {
    int ntaxa = 0;
    int lseq = 0;
    SeqType seqtype = SeqType::Protein;

    vector<string> taxalabels;
    vector<string> sequences;
    vector<string> original_sequences;
    int original_lseq = 0;
    vector<int> column_map;  // compressed column -> original column

    void ReadFASTA(const string& filepath);
    void ReadPHYLIP(const string& filepath);
    void ReadAlignment(const string& filepath);
    void DropGapOnlyColumns();
    vector<string> TrimAlignment(const vector<char>& mask) const;
    vector<string> MaskedReportRows(const vector<char>& mask) const;

    bool IsStandardState(char c) const {
        return seqtype == SeqType::Protein ? IsProteinState(c)
                                           : IsDNAState(c);
    }
};

inline void AlnProfile::ReadFASTA(const string& filepath) {
    std::ifstream in(filepath);
    if (!in)
        throw AlnFileFormatError("Cannot open alignment file: " + filepath);

    taxalabels.clear();
    sequences.clear();

    string line;
    string current;
    bool have_record = false;

    auto finish_record = [&]() {
        if (!have_record)
            return;
        // GBlocks ignores spaces inside FASTA sequence lines but counts
        // other characters (including tabs) as alignment positions.
        string compact;
        compact.reserve(current.size());
        for (char c : current)
            if (c != ' ')
                compact.push_back(c);
        sequences.push_back(std::move(compact));
        current.clear();
    };

    while (std::getline(in, line)) {
        if (!line.empty() && line.back() == '\r')
            line.pop_back();

        if (!line.empty() && line[0] == '>') {
            finish_record();
            taxalabels.push_back(line.substr(1));
            have_record = true;
        } else {
            if (!have_record) {
                bool blank = true;
                for (char c : line)
                    if (!std::isspace(static_cast<unsigned char>(c)))
                        blank = false;
                if (blank)
                    continue;
                throw AlnFileFormatError(
                    "Only FASTA input is supported (expected '>').");
            }
            current += line;
        }
    }
    finish_record();

    ntaxa = static_cast<int>(sequences.size());
    if (ntaxa < 2)
        throw AlnFileFormatError("At least two sequences are required.");

    lseq = static_cast<int>(sequences.front().size());
    if (lseq < 2)
        throw AlnFileFormatError(
            "At least two alignment positions are required.");

    for (const auto& sequence : sequences) {
        if (static_cast<int>(sequence.size()) != lseq)
            throw SequenceNotAlignedError(
                "Sequences do not have the same length.");
    }
}

inline string TrimCopy(const string& value) {
    size_t begin = 0;
    while (begin < value.size() &&
           std::isspace(static_cast<unsigned char>(value[begin])))
        ++begin;
    size_t end = value.size();
    while (end > begin &&
           std::isspace(static_cast<unsigned char>(value[end - 1])))
        --end;
    return value.substr(begin, end - begin);
}

inline string StripWhitespace(const string& value) {
    string result;
    result.reserve(value.size());
    for (char c : value) {
        if (!std::isspace(static_cast<unsigned char>(c)))
            result.push_back(c);
    }
    return result;
}

inline bool IsBlankLine(const string& line) {
    for (char c : line)
        if (!std::isspace(static_cast<unsigned char>(c)))
            return false;
    return true;
}

inline vector<string> SplitWhitespace(const string& line) {
    vector<string> fields;
    size_t pos = 0;
    while (pos < line.size()) {
        while (pos < line.size() &&
               std::isspace(static_cast<unsigned char>(line[pos])))
            ++pos;
        if (pos >= line.size())
            break;
        size_t end = pos;
        while (end < line.size() &&
               !std::isspace(static_cast<unsigned char>(line[end])))
            ++end;
        fields.push_back(line.substr(pos, end - pos));
        pos = end;
    }
    return fields;
}

inline void SplitPHYLIPRecord(const string& line, string& name,
                              string& sequence) {
    name.clear();
    sequence.clear();

    if (line.empty() || std::isspace(static_cast<unsigned char>(line[0])))
        return;

    // Relaxed PHYLIP often pads the name with several spaces. Splitting at
    // the first run of two or more spaces also preserves names that contain
    // a single internal space (e.g. "Octolasion lacteum*").
    size_t double_space = line.find("  ");
    if (double_space != string::npos) {
        name = TrimCopy(line.substr(0, double_space));
        sequence = StripWhitespace(line.substr(double_space));
        if (!name.empty())
            return;
    }

    size_t first_space = line.find_first_of(" \t");
    if (first_space == string::npos) {
        // Strict PHYLIP without a separating space: 10-character name.
        if (line.size() <= 10) {
            name = TrimCopy(line);
        } else {
            name = TrimCopy(line.substr(0, 10));
            sequence = StripWhitespace(line.substr(10));
        }
        return;
    }

    // Relaxed PHYLIP: first whitespace-delimited field is the name.
    name = line.substr(0, first_space);
    sequence = StripWhitespace(line.substr(first_space + 1));
    if (name.empty()) {
        // A line that starts with whitespace is a continuation line.
        sequence = StripWhitespace(line);
    }
}

inline void SplitPHYLIPRecordWithLength(const string& line, int sites,
                                        string& name, string& sequence) {
    size_t pos = line.size();
    size_t cut = line.size();
    int count = 0;
    while (pos > 0 && count < sites) {
        --pos;
        if (!std::isspace(static_cast<unsigned char>(line[pos]))) {
            ++count;
            cut = pos;
        }
    }
    if (count == sites) {
        name = TrimCopy(line.substr(0, cut));
        sequence = StripWhitespace(line.substr(cut));
        if (!name.empty())
            return;
    }
    SplitPHYLIPRecord(line, name, sequence);
}

inline void AlnProfile::ReadPHYLIP(const string& filepath) {
    std::ifstream in(filepath);
    if (!in)
        throw AlnFileFormatError("Cannot open alignment file: " + filepath);

    string line;
    while (std::getline(in, line)) {
        if (!line.empty() && line.back() == '\r')
            line.pop_back();
        if (!IsBlankLine(line))
            break;
    }
    if (line.empty())
        throw AlnFileFormatError("Empty PHYLIP file: " + filepath);

    std::istringstream header(line);
    int taxa = 0;
    int sites = 0;
    if (!(header >> taxa >> sites) || taxa < 2 || sites < 2)
        throw AlnFileFormatError("Invalid PHYLIP header: " + line);

    taxalabels.assign(static_cast<size_t>(taxa), string());
    sequences.assign(static_cast<size_t>(taxa), string());

    vector<string> first_lines;
    while (first_lines.size() < static_cast<size_t>(taxa) &&
           std::getline(in, line)) {
        if (!line.empty() && line.back() == '\r')
            line.pop_back();
        if (IsBlankLine(line))
            continue;
        first_lines.push_back(line);
    }
    if (first_lines.size() != static_cast<size_t>(taxa))
        throw AlnFileFormatError("PHYLIP file has too few sequence lines.");

    for (int i = 0; i < taxa; ++i) {
        string name;
        string sequence;
        SplitPHYLIPRecordWithLength(
            first_lines[static_cast<size_t>(i)], sites, name, sequence);
        if (name.empty())
            throw AlnFileFormatError(
                "Invalid PHYLIP sequence header (missing taxon name).");
        taxalabels[static_cast<size_t>(i)] = name;
        sequences[static_cast<size_t>(i)] = sequence;
    }

    vector<string> rest;
    bool saw_blank = false;
    while (std::getline(in, line)) {
        if (!line.empty() && line.back() == '\r')
            line.pop_back();
        if (IsBlankLine(line)) {
            if (!rest.empty())
                saw_blank = true;
            continue;
        }
        rest.push_back(line);
    }

    bool complete = true;
    for (const auto& sequence : sequences)
        if (static_cast<int>(sequence.size()) != sites)
            complete = false;

    if (!complete) {
        bool interleaved = saw_blank ||
            (!rest.empty() &&
             rest.size() % static_cast<size_t>(taxa) == 0);

        if (interleaved) {
            for (size_t offset = 0; offset < rest.size();
                 offset += static_cast<size_t>(taxa)) {
                for (int i = 0; i < taxa; ++i) {
                    size_t index = offset + static_cast<size_t>(i);
                    if (index >= rest.size())
                        break;
                    string chunk = rest[index];
                    string trimmed = TrimCopy(chunk);
                    const string& label = taxalabels[static_cast<size_t>(i)];
                    if (trimmed.compare(0, label.size(), label) == 0 &&
                        (trimmed.size() == label.size() ||
                         std::isspace(static_cast<unsigned char>(
                             trimmed[label.size()])))) {
                        chunk = trimmed.substr(label.size());
                    }
                    sequences[static_cast<size_t>(i)] +=
                        StripWhitespace(chunk);
                }
            }
        } else {
            // One-line-per-taxon sequential PHYLIP is already complete;
            // wrapped sequential layouts are intentionally rejected.
            throw AlnFileFormatError(
                "Unsupported PHYLIP layout; use interleaved PHYLIP.");
        }
    }

    for (const auto& sequence : sequences) {
        if (static_cast<int>(sequence.size()) != sites)
            throw SequenceNotAlignedError(
                "PHYLIP sequences do not match the declared length.");
    }

    ntaxa = taxa;
    lseq = sites;
}

inline void AlnProfile::ReadAlignment(const string& filepath) {
    std::ifstream in(filepath);
    if (!in)
        throw AlnFileFormatError("Cannot open alignment file: " + filepath);

    string line;
    while (std::getline(in, line)) {
        if (!line.empty() && line.back() == '\r')
            line.pop_back();
        if (!IsBlankLine(line))
            break;
    }
    if (line.empty())
        throw AlnFileFormatError("Empty alignment file: " + filepath);

    size_t first = line.find_first_not_of(" \t");
    if (first != string::npos && line[first] == '>')
        ReadFASTA(filepath);
    else if (first != string::npos &&
             std::isdigit(static_cast<unsigned char>(line[first])))
        ReadPHYLIP(filepath);
    else
        throw AlnFileFormatError(
            "Unsupported alignment format (expected FASTA or PHYLIP).");
}

inline void AlnProfile::DropGapOnlyColumns() {
    if (original_sequences.empty()) {
        original_sequences = sequences;
        original_lseq = lseq;
    }

    vector<char> keep(static_cast<size_t>(lseq), 0);
    column_map.clear();
    column_map.reserve(static_cast<size_t>(lseq));

    for (int col = 0; col < lseq; ++col) {
        bool all_gap = true;
        for (const auto& sequence : sequences) {
            if (!IsGapChar(sequence[static_cast<size_t>(col)])) {
                all_gap = false;
                break;
            }
        }
        keep[static_cast<size_t>(col)] = all_gap ? 0 : 1;
        if (!all_gap)
            column_map.push_back(col);
    }

    for (auto& sequence : sequences) {
        string compact;
        compact.reserve(sequence.size());
        for (int col = 0; col < lseq; ++col)
            if (keep[static_cast<size_t>(col)])
                compact.push_back(sequence[static_cast<size_t>(col)]);
        sequence.swap(compact);
    }

    lseq = static_cast<int>(column_map.size());
}

inline vector<string> AlnProfile::TrimAlignment(
    const vector<char>& mask) const {
    vector<string> result;
    result.reserve(sequences.size());
    for (const auto& sequence : sequences) {
        string selected;
        selected.reserve(sequence.size());
        for (int col = 0; col < lseq; ++col)
            if (mask[static_cast<size_t>(col)])
                selected.push_back(sequence[static_cast<size_t>(col)]);
        result.push_back(std::move(selected));
    }
    return result;
}

inline vector<string> AlnProfile::MaskedReportRows(
    const vector<char>& mask) const {
    vector<char> original_mask(static_cast<size_t>(original_lseq), 0);
    for (int col = 0; col < lseq; ++col) {
        if (mask[static_cast<size_t>(col)])
            original_mask[static_cast<size_t>(column_map[static_cast<size_t>(col)])] = 1;
    }

    vector<string> rows;
    rows.reserve(original_sequences.size());
    for (const auto& sequence : original_sequences) {
        string row;
        row.reserve(sequence.size());
        for (int col = 0; col < original_lseq; ++col) {
            char c = sequence[static_cast<size_t>(col)];
            if (c == '-') {
                // Every gap is rendered as a PHYLIP dot.
                row.push_back('.');
            } else if (original_mask[static_cast<size_t>(col)]) {
                row.push_back(static_cast<char>(
                    std::toupper(static_cast<unsigned char>(c))));
            } else {
                row.push_back(static_cast<char>(
                    std::tolower(static_cast<unsigned char>(c))));
            }
        }
        rows.push_back(std::move(row));
    }
    return rows;
}

}  // namespace AlnUtils

namespace GBlocks {

using namespace AlnUtils;

class GBlocksParamsError : public std::runtime_error {
public:
    explicit GBlocksParamsError(const string& message)
        : std::runtime_error(message) {}
};

enum class GapMode { None, Half, All };

struct Params {
    SeqType seqtype = SeqType::Protein;

    int b1 = 0;
    int b2 = 0;
    int b3 = 8;
    int b4 = 10;
    int b0 = -1;  // -1 means "same as b4"
    GapMode b5 = GapMode::None;
    bool b6 = true;

    bool save_selected = true;
    bool save_report = true;
    string extension = "-gb";

    int resolved_b1 = 0;
    int resolved_b2 = 0;
    int resolved_b0 = 0;

    void Resolve(int ntaxa) {
        const int default_b1 = ntaxa / 2 + 1;
        const int default_b2 = std::max(
            static_cast<int>(0.85 * ntaxa), default_b1);

        // GBlocks silently restores defaults for out-of-range values.
        if (b1 <= 0 || b1 < default_b1 || b1 > ntaxa)
            resolved_b1 = default_b1;
        else
            resolved_b1 = b1;

        if (b2 <= 0 || b2 < resolved_b1 || b2 > ntaxa)
            resolved_b2 = std::max(default_b2, resolved_b1);
        else
            resolved_b2 = b2;

        if (b4 < 2)
            b4 = 10;
        resolved_b0 = (b0 < 0) ? b4 : b0;
        if (resolved_b0 < 2)
            resolved_b0 = b4;

        if (b3 < 0)
            throw GBlocksParamsError("b3 must be non-negative.");
    }
};

// Gonnet 120-derived scores, used for protein alignments (including
// FASTA input with no -t, which GBlocks treats as protein). Matrix values
// follow the standard Gonnet matrix, e.g.
// https://www.mathworks.com/help/bioinfo/ref/gonnet.html
static const double GONNET120[20][20] = {
    {  2.4,  -0.6,  -0.3,  -0.3,   0.5,  -0.2,   0.0,   0.5,  -0.8,  -0.8,  -1.2,  -0.4,  -0.7,  -2.3,   0.3,   1.1,   0.6,  -3.6,  -2.2,   0.1},
    { -0.6,   4.7,   0.3,  -0.3,  -2.2,   1.5,   0.4,  -1.0,   0.6,  -2.4,  -2.2,   2.7,  -1.7,  -3.2,  -0.9,  -0.2,  -0.2,  -1.6,  -1.8,  -2.0},
    { -0.3,   0.3,   3.8,   2.2,  -1.8,   0.7,   0.9,   0.4,   1.2,  -2.8,  -3.0,   0.8,  -2.2,  -3.1,  -0.9,   0.9,   0.5,  -3.6,  -1.4,  -2.2},
    { -0.3,  -0.3,   2.2,   4.7,  -3.2,   0.9,   2.7,   0.1,   0.4,  -3.8,  -4.0,   0.5,  -3.0,  -4.5,  -0.7,   0.5,   0.0,  -5.2,  -2.8,  -2.9},
    {  0.5,  -2.2,  -1.8,  -3.2,  11.5,  -2.4,  -3.0,  -2.0,  -1.3,  -1.1,  -1.5,  -2.8,  -0.9,  -0.8,  -3.1,   0.1,  -0.5,  -1.0,  -0.5,   0.0},
    { -0.2,   1.5,   0.7,   0.9,  -2.4,   2.7,   1.7,  -1.0,   1.2,  -1.9,  -1.6,   1.5,  -1.0,  -2.6,  -0.2,   0.2,   0.0,  -2.7,  -1.7,  -1.5},
    {  0.0,   0.4,   0.9,   2.7,  -3.0,   1.7,   3.6,  -0.8,   0.4,  -2.7,  -2.8,   1.2,  -2.0,  -3.9,  -0.5,   0.2,  -0.1,  -4.3,  -2.7,  -1.9},
    {  0.5,  -1.0,   0.4,   0.1,  -2.0,  -1.0,  -0.8,   6.6,  -1.4,  -4.5,  -4.4,  -1.1,  -3.5,  -5.2,  -1.6,   0.4,  -1.1,  -4.0,  -4.0,  -3.3},
    { -0.8,   0.6,   1.2,   0.4,  -1.3,   1.2,   0.4,  -1.4,   6.0,  -2.2,  -1.9,   0.6,  -1.3,  -0.1,  -1.1,  -0.2,  -0.3,  -0.8,   2.2,  -2.0},
    { -0.8,  -2.4,  -2.8,  -3.8,  -1.1,  -1.9,  -2.7,  -4.5,  -2.2,   4.0,   2.8,  -2.1,   2.5,   1.0,  -2.6,  -1.8,  -0.6,  -1.8,  -0.7,   3.1},
    { -1.2,  -2.2,  -3.0,  -4.0,  -1.5,  -1.6,  -2.8,  -4.4,  -1.9,   2.8,   4.0,  -2.1,   2.8,   2.0,  -2.3,  -2.1,  -1.3,  -0.7,   0.0,   1.8},
    { -0.4,   2.7,   0.8,   0.5,  -2.8,   1.5,   1.2,  -1.1,   0.6,  -2.1,  -2.1,   3.2,  -1.4,  -3.3,  -0.6,   0.1,   0.1,  -3.5,  -2.1,  -1.7},
    { -0.7,  -1.7,  -2.2,  -3.0,  -0.9,  -1.0,  -2.0,  -3.5,  -1.3,   2.5,   2.8,  -1.4,   4.3,   1.6,  -2.4,  -1.4,  -0.6,  -1.0,  -0.2,   1.6},
    { -2.3,  -3.2,  -3.1,  -4.5,  -0.8,  -2.6,  -3.9,  -5.2,  -0.1,   1.0,   2.0,  -3.3,   1.6,   7.0,  -3.8,  -2.8,  -2.2,   3.6,   5.1,   0.1},
    {  0.3,  -0.9,  -0.9,  -0.7,  -3.1,  -0.2,  -0.5,  -1.6,  -1.1,  -2.6,  -2.3,  -0.6,  -2.4,  -3.8,   7.6,   0.4,   0.1,  -5.0,  -3.1,  -1.8},
    {  1.1,  -0.2,   0.9,   0.5,   0.1,   0.2,   0.2,   0.4,  -0.2,  -1.8,  -2.1,   0.1,  -1.4,  -2.8,   0.4,   2.2,   1.5,  -3.3,  -1.9,  -1.0},
    {  0.6,  -0.2,   0.5,   0.0,  -0.5,   0.0,  -0.1,  -1.1,  -0.3,  -0.6,  -1.3,   0.1,  -0.6,  -2.2,   0.1,   1.5,   2.5,  -3.5,  -1.9,   0.0},
    { -3.6,  -1.6,  -3.6,  -5.2,  -1.0,  -2.7,  -4.3,  -4.0,  -0.8,  -1.8,  -0.7,  -3.5,  -1.0,   3.6,  -5.0,  -3.3,  -3.5,  14.2,   4.1,  -2.6},
    { -2.2,  -1.8,  -1.4,  -2.8,  -0.5,  -1.7,  -2.7,  -4.0,   2.2,  -0.7,   0.0,  -2.1,  -0.2,   5.1,  -3.1,  -1.9,  -1.9,   4.1,   7.8,  -1.1},
    {  0.1,  -2.0,  -2.2,  -2.9,   0.0,  -1.5,  -1.9,  -3.3,  -2.0,   3.1,   1.8,  -1.7,   1.6,   0.1,  -1.8,  -1.0,   0.0,  -2.6,  -1.1,   3.4},
};

inline int ProteinIndex(char c) {
    switch (c) {
    case 'A': return 0;
    case 'R': return 1;
    case 'N': return 2;
    case 'D': return 3;
    case 'C': return 4;
    case 'Q': return 5;
    case 'E': return 6;
    case 'G': return 7;
    case 'H': return 8;
    case 'I': return 9;
    case 'L': return 10;
    case 'K': return 11;
    case 'M': return 12;
    case 'F': return 13;
    case 'P': return 14;
    case 'S': return 15;
    case 'T': return 16;
    case 'W': return 17;
    case 'Y': return 18;
    case 'V': return 19;
    default: return -1;
    }
}

struct ColumnInfo {
    int gap_count = 0;
    int mode_count = 0;
    char mode_state = '\0';
    bool gap_position = false;
};

class Selector {
public:
    Selector(AlnProfile& profile, Params& params)
        : aln(profile), params(params) {}

    vector<char> Run() {
        params.Resolve(aln.ntaxa);
        ClassifyColumns();
        RejectLongNonconservedRuns();
        TrimToHighlyConservedFlanks();
        RemoveShortInitialBlocks();
        RemoveGapAdjacentColumns();
        if (params.seqtype == SeqType::Codon)
            TrimToCompleteCodons();
        return BuildMask();
    }

    const vector<ColumnInfo>& Columns() const { return columns; }
    const vector<std::pair<int, int>>& FinalBlocks() const {
        return final_blocks;
    }

private:
    AlnProfile& aln;
    Params& params;

    vector<ColumnInfo> columns;  // per column after gap-only removal
    vector<int> level;           // 0 nonconserved, 1 conserved, 2 highly
    vector<int> rejected;        // 1 if removed by b3 rule
    vector<std::pair<int, int>> blocks;        // 0-based inclusive, after b0
    vector<std::pair<int, int>> final_blocks;  // 0-based inclusive

    static int StateRank(char c) {
        switch (c) {
        case 'A': return 0;  case 'C': return 1;  case 'D': return 2;
        case 'E': return 3;  case 'F': return 4;  case 'G': return 5;
        case 'H': return 6;  case 'I': return 7;  case 'K': return 8;
        case 'L': return 9;  case 'M': return 10; case 'N': return 11;
        case 'P': return 12; case 'Q': return 13; case 'R': return 14;
        case 'S': return 15; case 'T': return 16; case 'U': return 3;
        case 'V': return 17; case 'W': return 18; case 'Y': return 19;
        default: return 100;
        }
    }

    void ClassifyColumns() {
        columns.assign(static_cast<size_t>(aln.lseq), ColumnInfo{});
        level.assign(static_cast<size_t>(aln.lseq), 0);

        for (int col = 0; col < aln.lseq; ++col) {
            std::map<char, int> counts;
            ColumnInfo info;

            for (const auto& sequence : aln.sequences) {
                char raw = sequence[static_cast<size_t>(col)];
                if (IsGapChar(raw)) {
                    ++info.gap_count;
                    continue;
                }
                if (!aln.IsStandardState(raw))
                    continue;
                char state = static_cast<char>(
                    std::toupper(static_cast<unsigned char>(raw)));
                ++counts[state];
            }

            if (params.b5 == GapMode::None)
                info.gap_position = info.gap_count > 0;
            else if (params.b5 == GapMode::Half)
                info.gap_position = info.gap_count * 2 >= aln.ntaxa;
            else
                info.gap_position = false;

            if (info.gap_position || counts.empty()) {
                columns[static_cast<size_t>(col)] = info;
                continue;
            }

            char mode_state = '\0';
            int mode_count = 0;
            for (const auto& entry : counts) {
                char state = entry.first;
                int count = entry.second;
                if (count > mode_count ||
                    (count == mode_count &&
                     StateRank(state) < StateRank(mode_state))) {
                    mode_state = state;
                    mode_count = count;
                }
            }

            char second_state = '\0';
            int second_count = 0;
            for (const auto& entry : counts) {
                if (entry.first == mode_state)
                    continue;
                if (entry.second > second_count ||
                    (entry.second == second_count &&
                     StateRank(entry.first) < StateRank(second_state))) {
                    second_state = entry.first;
                    second_count = entry.second;
                }
            }

            info.mode_state = mode_state;
            info.mode_count = mode_count;
            columns[static_cast<size_t>(col)] = info;

            if (mode_count >= params.resolved_b2) {
                level[static_cast<size_t>(col)] = 2;
            } else if (mode_count >= params.resolved_b1) {
                bool promote = false;
                if (params.seqtype == SeqType::Protein && params.b6 &&
                    second_state != '\0') {
                    int mode_index = ProteinIndex(mode_state);
                    int second_index = ProteinIndex(second_state);
                    if (mode_index >= 0 && second_index >= 0) {
                        double score =
                            GONNET120[mode_index][second_index];
                        promote = score * second_count > 8.0;
                    }
                }
                level[static_cast<size_t>(col)] = promote ? 2 : 1;
            }
        }
    }

    void RejectLongNonconservedRuns() {
        rejected.assign(static_cast<size_t>(aln.lseq), 0);
        int run_start = -1;

        for (int col = 0; col <= aln.lseq; ++col) {
            bool nonconserved =
                (col < aln.lseq && level[static_cast<size_t>(col)] == 0);
            if (nonconserved) {
                if (run_start < 0)
                    run_start = col;
            } else if (run_start >= 0) {
                int length = col - run_start;
                if (length > params.b3)
                    for (int j = run_start; j < col; ++j)
                        rejected[static_cast<size_t>(j)] = 1;
                run_start = -1;
            }
        }
    }

    void TrimToHighlyConservedFlanks() {
        blocks.clear();
        int col = 0;
        while (col < aln.lseq) {
            while (col < aln.lseq && rejected[static_cast<size_t>(col)])
                ++col;
            if (col >= aln.lseq)
                break;

            int begin = col;
            while (col < aln.lseq && !rejected[static_cast<size_t>(col)])
                ++col;
            int end = col - 1;

            int first_hc = -1;
            int last_hc = -1;
            for (int i = begin; i <= end; ++i) {
                if (level[static_cast<size_t>(i)] == 2) {
                    if (first_hc < 0)
                        first_hc = i;
                    last_hc = i;
                }
            }

            if (first_hc >= 0 && last_hc > first_hc)
                blocks.emplace_back(first_hc, last_hc);
        }
    }

    void RemoveShortInitialBlocks() {
        blocks.erase(
            std::remove_if(blocks.begin(), blocks.end(),
                           [&](const std::pair<int, int>& block) {
                               return block.second - block.first + 1 <
                                      params.resolved_b0;
                           }),
            blocks.end());
    }

    void RemoveGapAdjacentColumns() {
        final_blocks.clear();

        for (const auto& block : blocks) {
            int begin = block.first;
            int end = block.second;
            vector<char> keep(static_cast<size_t>(end - begin + 1), 1);

            for (int col = begin; col <= end; ++col) {
                if (!columns[static_cast<size_t>(col)].gap_position)
                    continue;

                keep[static_cast<size_t>(col - begin)] = 0;

                for (int left = col - 1;
                     left >= begin && level[static_cast<size_t>(left)] == 0;
                     --left)
                    keep[static_cast<size_t>(left - begin)] = 0;

                for (int right = col + 1;
                     right <= end && level[static_cast<size_t>(right)] == 0;
                     ++right)
                    keep[static_cast<size_t>(right - begin)] = 0;
            }

            int col = begin;
            while (col <= end) {
                if (!keep[static_cast<size_t>(col - begin)]) {
                    ++col;
                    continue;
                }
                int run_begin = col;
                while (col <= end && keep[static_cast<size_t>(col - begin)])
                    ++col;
                int run_end = col - 1;
                if (run_end - run_begin + 1 >= params.b4)
                    final_blocks.emplace_back(run_begin, run_end);
            }
        }
    }

    void TrimToCompleteCodons() {
        vector<std::pair<int, int>> adjusted;
        for (const auto& block : final_blocks) {
            int one_begin = block.first + 1;
            int one_end = block.second + 1;
            int codon_begin =
                one_begin + ((3 - ((one_begin - 1) % 3)) % 3);
            int codon_end = one_end - (one_end % 3);
            if (codon_begin <= codon_end)
                adjusted.emplace_back(codon_begin - 1, codon_end - 1);
        }
        final_blocks.swap(adjusted);
    }

    vector<char> BuildMask() const {
        vector<char> mask(static_cast<size_t>(aln.lseq), 0);
        for (const auto& block : final_blocks)
            for (int col = block.first; col <= block.second; ++col)
                mask[static_cast<size_t>(col)] = 1;
        return mask;
    }
};

struct CommandLine {
    string input;
    Params params;
    bool help = false;
};

inline string Lower(string value) {
    for (char& c : value)
        c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    return value;
}

inline bool ParseBool(const string& value) {
    string v = Lower(value);
    if (v == "y" || v == "yes" || v == "true" || v == "1")
        return true;
    if (v == "n" || v == "no" || v == "false" || v == "0")
        return false;
    throw GBlocksParamsError("Expected y/n, got: " + value);
}

inline void PrintHelp() {
    std::cout
        << "YGBlocks - conserved block selection\n\n"
        << "Usage: ygblocks <alignment.fas|alignment.phy> [options]\n\n"
        << "Options:\n"
        << "  -t=p|d|c          sequence type: protein, DNA, codon (default: protein)\n"
        << "  -b1=N             minimum sequences for a conserved position\n"
        << "  -b2=N             minimum sequences for a flank position\n"
        << "  -b3=N             maximum contiguous nonconserved positions (8)\n"
        << "  -b4=N             minimum block length after gap cleaning (10)\n"
        << "  -b0=N             minimum initial block length (same as b4)\n"
        << "  -b5=n|h|a         gap positions: none, half, all (none)\n"
        << "  -b6=y|n           protein similarity matrix (yes)\n"
        << "  -e=EXT            output extension (default: -gb)\n"
        << "  -s=y|n            write selected alignment (default: yes)\n"
        << "  -p=y|t|s|n        write masked interleaved-PHYLIP report (yes)\n"
        << "  -h, --help        show this help\n\n"
        << "Selected alignment: <input><EXT>.fa\n"
        << "Masked report:      <input><EXT>.txt\n";
}

inline CommandLine ParseCommandLine(int argc, char** argv) {
    CommandLine cli;

    auto need_value = [&](int& index, const string& inline_value,
                          const string& option) -> string {
        if (!inline_value.empty())
            return inline_value;
        if (index + 1 >= argc)
            throw GBlocksParamsError("Missing value for " + option);
        return argv[++index];
    };

    for (int i = 1; i < argc; ++i) {
        string arg = argv[i];
        if (arg == "-h" || arg == "--help" || arg == "-?") {
            cli.help = true;
            continue;
        }
        if (arg.empty() || arg[0] != '-' || arg == "-") {
            if (cli.input.empty())
                cli.input = arg;
            else
                throw GBlocksParamsError(
                    "Unexpected extra argument: " + arg);
            continue;
        }

        string key = arg;
        string value;
        size_t eq = arg.find('=');
        if (eq != string::npos) {
            key = arg.substr(0, eq);
            value = arg.substr(eq + 1);
        }

        if (key == "-t") {
            string v = Lower(need_value(i, value, key));
            if (v == "p" || v == "protein")
                cli.params.seqtype = SeqType::Protein;
            else if (v == "d" || v == "dna")
                cli.params.seqtype = SeqType::DNA;
            else if (v == "c" || v == "codon")
                cli.params.seqtype = SeqType::Codon;
            else
                throw GBlocksParamsError("Invalid sequence type: " + v);
        } else if (key == "-b1") {
            cli.params.b1 = std::stoi(need_value(i, value, key));
        } else if (key == "-b2") {
            cli.params.b2 = std::stoi(need_value(i, value, key));
        } else if (key == "-b3") {
            cli.params.b3 = std::stoi(need_value(i, value, key));
        } else if (key == "-b4") {
            cli.params.b4 = std::stoi(need_value(i, value, key));
        } else if (key == "-b0") {
            cli.params.b0 = std::stoi(need_value(i, value, key));
        } else if (key == "-b5") {
            string v = Lower(need_value(i, value, key));
            if (v == "n" || v == "none")
                cli.params.b5 = GapMode::None;
            else if (v == "h" || v == "half")
                cli.params.b5 = GapMode::Half;
            else if (v == "a" || v == "all")
                cli.params.b5 = GapMode::All;
            else
                throw GBlocksParamsError("Invalid b5 value: " + v);
        } else if (key == "-b6") {
            cli.params.b6 = ParseBool(need_value(i, value, key));
        } else if (key == "-e") {
            cli.params.extension = need_value(i, value, key);
            if (cli.params.extension.size() > 5)
                throw GBlocksParamsError(
                    "Generic extension must have at most 5 characters.");
        } else if (key == "-s") {
            cli.params.save_selected =
                ParseBool(need_value(i, value, key));
        } else if (key == "-p") {
            string v = Lower(need_value(i, value, key));
            if (v == "n" || v == "no" || v == "false" || v == "0")
                cli.params.save_report = false;
            else if (v == "y" || v == "yes" || v == "t" ||
                     v == "s" || v == "true" || v == "1")
                cli.params.save_report = true;
            else
                throw GBlocksParamsError("Invalid -p value: " + v);
        } else if (key == "-q" || key == "-r" ||
                   key == "-v" || key == "-n" || key == "-u" ||
                   key == "-k" || key == "-d" || key == "-a" ||
                   key == "-c" || key == "-w") {
            // Report/interactive options accepted for command-line
            // compatibility. The selected-block FASTA is the only output
            // YR-MPE consumes.
            if (value.empty() && i + 1 < argc && argv[i + 1][0] != '-')
                ++i;
        } else {
            std::cerr << "WARNING: ignoring unknown option " << arg << '\n';
        }
    }

    return cli;
}

inline void WriteSelectedFASTA(const AlnProfile& aln,
                               const vector<string>& trimmed,
                               const string& filepath) {
    std::ofstream out(filepath);
    if (!out)
        throw std::runtime_error("Cannot write output file: " + filepath);

    for (size_t i = 0; i < trimmed.size(); ++i) {
        out << '>' << aln.taxalabels[i] << '\n';
        const string& sequence = trimmed[i];
        // GBlocks emits the separator before the character at each
        // boundary, including a separator after the final character.
        for (size_t pos = 0; pos <= sequence.size(); ++pos) {
            if (pos > 0 && pos % 60 == 0)
                out << '\n';
            else if (pos > 0 && pos % 10 == 0)
                out << ' ';
            if (pos < sequence.size())
                out << sequence[pos];
        }
        out << '\n';
    }
}

inline void WriteMaskedReport(const AlnProfile& aln,
                              const vector<string>& rows,
                              const string& filepath) {
    std::ofstream out(filepath);
    if (!out)
        throw std::runtime_error("Cannot write report file: " + filepath);

    out << aln.ntaxa << ' ' << aln.original_lseq << '\n';

    size_t name_width = 0;
    for (const auto& label : aln.taxalabels)
        name_width = std::max(name_width, label.size());
    name_width += 2;

    constexpr size_t block = 60;
    for (size_t start = 0; start < static_cast<size_t>(aln.original_lseq);
         start += block) {
        for (size_t i = 0; i < rows.size(); ++i) {
            if (start == 0) {
                out << aln.taxalabels[i];
                if (aln.taxalabels[i].size() < name_width)
                    out << string(name_width - aln.taxalabels[i].size(), ' ');
            } else {
                out << string(name_width, ' ');
            }

            size_t end = std::min(start + block,
                                  static_cast<size_t>(aln.original_lseq));
            for (size_t pos = start; pos < end; ++pos) {
                if (pos > start && (pos - start) % 10 == 0)
                    out << ' ';
                out << rows[i][pos];
            }
            out << '\n';
        }
        if (start + block < static_cast<size_t>(aln.original_lseq))
            out << '\n';
    }
}

}  // namespace GBlocks

int main(int argc, char** argv) {
    using namespace AlnUtils;
    using namespace GBlocks;

    try {
        CommandLine cli = ParseCommandLine(argc, argv);
        if (cli.help) {
            PrintHelp();
            return 0;
        }
        if (cli.input.empty())
            throw GBlocksParamsError("No input alignment supplied.");

        AlnProfile profile;
        profile.seqtype = cli.params.seqtype;
        profile.ReadAlignment(cli.input);
        profile.DropGapOnlyColumns();

        if (profile.lseq < 2)
            throw GBlocksParamsError(
                "No alignment positions remain after removing gap-only columns.");

        Selector selector(profile, cli.params);
        vector<char> mask = selector.Run();
        vector<string> trimmed = profile.TrimAlignment(mask);

        size_t selected = 0;
        for (char keep : mask)
            selected += keep ? 1 : 0;

        std::cout << "Gblocks processing file: " << cli.input << '\n';
        std::cout << "Original alignment: " << profile.lseq << " positions\n";
        std::cout << "Gblocks alignment:  " << selected << " positions";
        if (profile.lseq > 0)
            std::cout << " (" << (100.0 * selected / profile.lseq) << " %)";
        std::cout << " in " << selector.FinalBlocks().size()
                  << " selected block(s)\n";

        if (cli.params.save_selected) {
            string output = cli.input + cli.params.extension + ".fa";
            WriteSelectedFASTA(profile, trimmed, output);
            std::cout << "Saved: " << output << '\n';
        }

        if (cli.params.save_report) {
            string report = cli.input + cli.params.extension + ".txt";
            vector<string> report_rows = profile.MaskedReportRows(mask);
            WriteMaskedReport(profile, report_rows, report);
            std::cout << "Report: " << report << '\n';
        }

        return 0;
    } catch (const std::exception& error) {
        std::cerr << "ERROR: " << error.what() << '\n';
        return 1;
    }
}
