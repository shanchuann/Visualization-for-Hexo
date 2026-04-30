#pragma once

#include <QObject>
#include <QProcess>

class CommandAdapter : public QObject
{
    Q_OBJECT
public:
    explicit CommandAdapter(QObject *parent = nullptr);

    bool isRunning() const;
    void startShellCommand(const QString &workingDirectory, const QString &commandLine);
    void writeLine(const QString &text);
    void stop();

signals:
    void outputReady(const QString &text);
    void commandStarted(const QString &commandLine);
    void commandFinished(int exitCode, bool crashed);

private:
    QProcess m_process;
};
