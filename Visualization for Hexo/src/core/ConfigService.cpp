#include "ConfigService.h"

#include "../adapters/YamlAdapter.h"

#include <QDir>
#include <QFile>

ConfigService::ConfigService(QObject *parent)
    : QObject(parent)
{
}

QVariantMap ConfigService::loadSiteConfig(const QString &projectPath) const
{
    QFile f(QDir(projectPath).filePath("_config.yml"));
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return {};
    }
    return YamlAdapter::parseKeyValueYaml(QString::fromUtf8(f.readAll()));
}

bool ConfigService::saveSiteConfig(const QString &projectPath, const QVariantMap &map) const
{
    QFile f(QDir(projectPath).filePath("_config.yml"));
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        return false;
    }
    f.write(YamlAdapter::dumpKeyValueYaml(map).toUtf8());
    return true;
}

QVariantMap ConfigService::loadThemeConfig(const QString &projectPath, const QString &theme) const
{
    QFile f(QDir(projectPath).filePath(QString("themes/%1/_config.yml").arg(theme)));
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return {};
    }
    return YamlAdapter::parseKeyValueYaml(QString::fromUtf8(f.readAll()));
}

bool ConfigService::saveThemeConfig(const QString &projectPath, const QString &theme, const QVariantMap &map) const
{
    QFile f(QDir(projectPath).filePath(QString("themes/%1/_config.yml").arg(theme)));
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        return false;
    }
    f.write(YamlAdapter::dumpKeyValueYaml(map).toUtf8());
    return true;
}
