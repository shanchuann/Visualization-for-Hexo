#pragma once

#include <QHash>
#include <QString>
#include <QStringList>
#include <QVector>

struct DiffHunk {
    enum Type { Equal, Replace, Insert, Delete };
    Type type;
    int origStart, origEnd; // half-open [start, end) in original lines
    int propStart, propEnd; // half-open [start, end) in proposed lines
    QStringList origLines;
    QStringList propLines;
    int hunkId;
};

class DiffEngine
{
public:
    static QVector<DiffHunk> computeHunks(const QString &original, const QString &proposed);
    static QString rebuildBody(const QString &original,
                               const QVector<DiffHunk> &hunks,
                               const QHash<int, bool> &decisions);

private:
    struct NormLine {
        QString text;      // collapsed text for comparison
        int origIndex;     // index in original lines (-1 if from proposed)
        int propIndex;
    };

    static QStringList splitLines(const QString &text);
    static QVector<NormLine> normalize(const QStringList &lines, bool isOriginal);
    static QVector<DiffHunk> mergeHunks(const QVector<DiffHunk> &raw);
};
