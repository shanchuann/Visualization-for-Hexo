#include "YamlAdapter.h"

#include <QStringList>

QStringList splitLines(const QString &content)
{
    return content.split('\n');
}

QVariantMap YamlAdapter::parseKeyValueYaml(const QString &content)
{
    QVariantMap map;
    const QStringList lines = splitLines(content);
    for (const QString &line : lines) {
        const QString t = line.trimmed();
        if (t.isEmpty() || t.startsWith('#')) {
            continue;
        }
        const int idx = line.indexOf(':');
        if (idx <= 0) {
            continue;
        }
        const QString key = line.left(idx).trimmed();
        const QString value = line.mid(idx + 1).trimmed();
        map.insert(key, value);
    }
    return map;
}

QString YamlAdapter::dumpKeyValueYaml(const QVariantMap &map)
{
    QStringList keys = map.keys();
    keys.sort();

    QStringList lines;
    lines.reserve(keys.size());
    for (const QString &k : keys) {
        lines.push_back(QString("%1: %2").arg(k, map.value(k).toString()));
    }
    return lines.join("\n") + "\n";
}
