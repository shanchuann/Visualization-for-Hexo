#include "DiffEngine.h"

#include <QRegularExpression>

namespace {

// Markdown structural prefixes that should NOT be merged with previous line
bool isStructuralLine(const QString &line)
{
    static const QRegularExpression re(
        QStringLiteral("^(#{1,6}\\s|[-*+]\\s|\\d+\\.\\s|>|\\|\\s*|```|---|\\*\\*\\*|~~~)"));
    return re.match(line).hasMatch();
}

} // anonymous namespace

QStringList DiffEngine::splitLines(const QString &text)
{
    if (text.isEmpty()) return {};
    QStringList lines = text.split('\n');
    return lines;
}

QVector<DiffEngine::NormLine> DiffEngine::normalize(const QStringList &lines, bool isOriginal)
{
    QVector<NormLine> result;
    for (int i = 0; i < lines.size(); i++) {
        NormLine nl;
        nl.text = lines[i].trimmed();
        if (isOriginal) {
            nl.origIndex = i;
            nl.propIndex = -1;
        } else {
            nl.origIndex = -1;
            nl.propIndex = i;
        }
        result.append(nl);
    }
    return result;
}

QVector<DiffHunk> DiffEngine::computeHunks(const QString &original, const QString &proposed)
{
    QStringList origLines = splitLines(original);
    QStringList propLines = splitLines(proposed);

    QVector<NormLine> normOrig = normalize(origLines, true);
    QVector<NormLine> normProp = normalize(propLines, false);

    int n = normOrig.size();
    int m = normProp.size();

    // LCS DP
    QVector<QVector<int>> dp(n + 1, QVector<int>(m + 1, 0));
    for (int i = 1; i <= n; i++) {
        for (int j = 1; j <= m; j++) {
            if (normOrig[i - 1].text == normProp[j - 1].text) {
                dp[i][j] = dp[i - 1][j - 1] + 1;
            } else {
                dp[i][j] = qMax(dp[i - 1][j], dp[i][j - 1]);
            }
        }
    }

    // Backtrack to get edit operations
    struct Op {
        enum { Keep, Del, Ins } type;
        int origIdx; // index in normOrig (-1 for insert)
        int propIdx; // index in normProp (-1 for delete)
    };
    QVector<Op> ops;
    {
        int i = n, j = m;
        while (i > 0 || j > 0) {
            if (i > 0 && j > 0 && normOrig[i - 1].text == normProp[j - 1].text) {
                ops.append({Op::Keep, i - 1, j - 1});
                i--; j--;
            } else if (j > 0 && (i == 0 || dp[i][j - 1] >= dp[i - 1][j])) {
                ops.append({Op::Ins, -1, j - 1});
                j--;
            } else {
                ops.append({Op::Del, i - 1, -1});
                i--;
            }
        }
    }
    // Reverse to chronological order
    for (int i = 0, sz = ops.size(); i < sz / 2; i++) {
        ops.swapItemsAt(i, sz - 1 - i);
    }

    // Group consecutive ops into hunks
    QVector<DiffHunk> rawHunks;
    int hunkId = 0;
    int oi = 0;
    while (oi < ops.size()) {
        if (ops[oi].type == Op::Keep) {
            // Equal hunk: collect all consecutive keeps
            DiffHunk h;
            h.type = DiffHunk::Equal;
            h.hunkId = hunkId++;
            h.origStart = normOrig[ops[oi].origIdx].origIndex;
            h.propStart = normProp[ops[oi].propIdx].propIndex;
            int oStart = ops[oi].origIdx;
            int pStart = ops[oi].propIdx;
            while (oi < ops.size() && ops[oi].type == Op::Keep) {
                oi++;
            }
            int oEnd = (oi > 0 && ops[oi - 1].type == Op::Keep) ? ops[oi - 1].origIdx + 1 : oStart + 1;
            int pEnd = (oi > 0 && ops[oi - 1].type == Op::Keep) ? ops[oi - 1].propIdx + 1 : pStart + 1;
            h.origEnd = normOrig[oEnd - 1].origIndex + 1;
            h.propEnd = normProp[pEnd - 1].propIndex + 1;
            // Collect original lines for this equal range
            for (int k = h.origStart; k < h.origEnd; k++) {
                h.origLines.append(origLines[k]);
            }
            h.propLines = h.origLines;
            rawHunks.append(h);
        } else {
            // Change hunk: collect consecutive non-keep ops
            DiffHunk h;
            h.hunkId = hunkId++;
            int oMin = INT_MAX, oMax = -1;
            int pMin = INT_MAX, pMax = -1;
            bool hasDel = false, hasIns = false;
            while (oi < ops.size() && ops[oi].type != Op::Keep) {
                if (ops[oi].type == Op::Del) {
                    hasDel = true;
                    int idx = normOrig[ops[oi].origIdx].origIndex;
                    oMin = qMin(oMin, idx);
                    oMax = qMax(oMax, idx);
                } else {
                    hasIns = true;
                    int idx = normProp[ops[oi].propIdx].propIndex;
                    pMin = qMin(pMin, idx);
                    pMax = qMax(pMax, idx);
                }
                oi++;
            }
            if (hasDel && hasIns) {
                h.type = DiffHunk::Replace;
            } else if (hasDel) {
                h.type = DiffHunk::Delete;
            } else {
                h.type = DiffHunk::Insert;
            }
            if (hasDel) {
                h.origStart = oMin;
                h.origEnd = oMax + 1;
                for (int k = h.origStart; k < h.origEnd; k++) {
                    h.origLines.append(origLines[k]);
                }
            } else {
                h.origStart = h.origEnd = (oMin == INT_MAX ? 0 : oMin);
            }
            if (hasIns) {
                h.propStart = pMin;
                h.propEnd = pMax + 1;
                for (int k = h.propStart; k < h.propEnd; k++) {
                    h.propLines.append(propLines[k]);
                }
            } else {
                h.propStart = h.propEnd = (pMin == INT_MAX ? 0 : pMin);
            }
            rawHunks.append(h);
        }
    }

    return rawHunks;
}

QVector<DiffHunk> DiffEngine::mergeHunks(const QVector<DiffHunk> &raw)
{
    // Merge adjacent small Equal hunks with neighboring changes
    // For now, return as-is — the normalized diff already produces good hunks
    return raw;
}

QString DiffEngine::rebuildBody(const QString &original,
                                const QVector<DiffHunk> &hunks,
                                const QHash<int, bool> &decisions)
{
    QStringList result;
    for (const DiffHunk &h : hunks) {
        if (h.type == DiffHunk::Equal) {
            result.append(h.origLines);
        } else {
            auto it = decisions.find(h.hunkId);
            if (it != decisions.end() && *it) {
                // Accepted: use proposed lines
                result.append(h.propLines);
            } else {
                // Rejected or undecided: keep original lines
                result.append(h.origLines);
            }
        }
    }
    QString body = result.join('\n');
    // Preserve trailing newline from original
    if (original.endsWith('\n') && !body.endsWith('\n')) {
        body += '\n';
    }
    return body;
}
