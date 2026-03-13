#pragma once

#include <QObject>
#include <QVariantMap>
#include <QString>

class ConfigService : public QObject
{
    Q_OBJECT
public:
    explicit ConfigService(QObject *parent = nullptr);

    Q_INVOKABLE QVariantMap loadSiteConfig(const QString &projectPath) const;
    Q_INVOKABLE bool saveSiteConfig(const QString &projectPath, const QVariantMap &map) const;

    Q_INVOKABLE QVariantMap loadThemeConfig(const QString &projectPath, const QString &theme) const;
    Q_INVOKABLE bool saveThemeConfig(const QString &projectPath, const QString &theme, const QVariantMap &map) const;
};
