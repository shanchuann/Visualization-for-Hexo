#include "PostService.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QTextStream>

PostService::PostService(QObject *parent)
    : QObject(parent)
{
}

QVariantList PostService::scanPosts(const QString &projectPath) const
{
    QVariantList out;
    const QString postsDir = QDir(projectPath).filePath("source/_posts");
    QDir dir(postsDir);
    const QStringList files = dir.entryList(QStringList() << "*.md", QDir::Files);
    for (const QString &f : files) {
        out.push_back(readMarkdown(dir.filePath(f)).toVariantMap());
    }
    return out;
}

QVariantMap PostService::readPost(const QString &filePath) const
{
    return readMarkdown(filePath).toVariantMap();
}

Post PostService::readMarkdown(const QString &filePath)
{
    Post p;
    p.path = filePath;

    QFile f(filePath);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return p;
    }

    QString text = QString::fromUtf8(f.readAll());
    QTextStream stream(&text, QIODevice::ReadOnly);

    bool inFrontMatter = false;
    bool frontStarted = false;
    QStringList bodyLines;

    while (!stream.atEnd()) {
        const QString line = stream.readLine();
        if (!frontStarted && line.trimmed() == "---") {
            inFrontMatter = true;
            frontStarted = true;
            continue;
        }
        if (inFrontMatter && line.trimmed() == "---") {
            inFrontMatter = false;
            continue;
        }

        if (inFrontMatter) {
            const int idx = line.indexOf(':');
            if (idx > 0) {
                const QString k = line.left(idx).trimmed();
                const QString v = line.mid(idx + 1).trimmed();
                if (k == "title") p.title = v;
                else if (k == "date") p.date = v;
                else if (k == "categories") p.categories = v;
                else if (k == "tags") p.tags = v;
            }
        } else {
            bodyLines.push_back(line);
        }
    }

    p.body = bodyLines.join("\n");
    if (p.title.isEmpty()) {
        p.title = QFileInfo(filePath).completeBaseName();
    }

    return p;
}
