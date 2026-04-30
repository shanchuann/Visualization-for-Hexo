#pragma once

#include <QObject>
#include <QString>

class CommandAdapter;

class GitService : public QObject
{
    Q_OBJECT
public:
    explicit GitService(CommandAdapter *adapter, QObject *parent = nullptr);

    void setWorkingDirectory(const QString &workingDirectory);

    Q_INVOKABLE void status();
    Q_INVOKABLE void addAll();
    Q_INVOKABLE void commit(const QString &message);
    Q_INVOKABLE void push();

signals:
    void outputReady(const QString &text);
    void commandStarted(const QString &commandLine);
    void commandFinished(int exitCode, bool crashed);

private:
    void run(const QString &commandLine);

    CommandAdapter *m_adapter = nullptr;
    QString m_workingDirectory;
};
