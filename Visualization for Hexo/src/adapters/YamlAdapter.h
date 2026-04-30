#pragma once

#include <QVariantMap>
#include <QString>

class YamlAdapter
{
public:
    static QVariantMap parseKeyValueYaml(const QString &content);
    static QString dumpKeyValueYaml(const QVariantMap &map);
};
