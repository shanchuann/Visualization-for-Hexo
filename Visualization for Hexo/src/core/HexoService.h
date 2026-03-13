#pragma once

#include <QObject>
#include <QString>

class CommandAdapter;

class HexoService : public QObject
{
    Q_OBJECT
public:
    explicit HexoService(CommandAdapter *adapter, QObject *parent = nullptr);

    void setWorkingDirectory(const QString &workingDirectory);
    QString workingDirectory() const;

    Q_INVOKABLE void generate();
    Q_INVOKABLE void deploy();
    Q_INVOKABLE void clean();
    Q_INVOKABLE void server();
    Q_INVOKABLE void newPost(const QString &title);
    Q_INVOKABLE void newPage(const QString &title);

signals:
    void outputReady(const QString &text);
    void commandStarted(const QString &commandLine);
    void commandFinished(int exitCode, bool crashed);

private:
    void run(const QString &commandLine);

    CommandAdapter *m_adapter = nullptr;
    QString m_workingDirectory;
};
