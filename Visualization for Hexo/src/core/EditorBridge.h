#pragma once

#include <QObject>
#include <QString>

class EditorBridge : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString content READ content WRITE setContent NOTIFY contentChanged)
public:
    explicit EditorBridge(QObject *parent = nullptr);

    QString content() const;
    void setContent(const QString &content);

    Q_INVOKABLE void notifyContentChangedFromJs(const QString &content);
    Q_INVOKABLE void requestSave();

signals:
    void contentChanged();
    void saveRequested();

private:
    QString m_content;
};
