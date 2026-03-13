#include "CommandAdapter.h"

#include <QSysInfo>

CommandAdapter::CommandAdapter(QObject *parent)
    : QObject(parent)
{
    connect(&m_process, &QProcess::readyReadStandardOutput, this, [this]() {
        emit outputReady(QString::fromUtf8(m_process.readAllStandardOutput()));
    });
    connect(&m_process, &QProcess::readyReadStandardError, this, [this]() {
        emit outputReady(QString::fromUtf8(m_process.readAllStandardError()));
    });
    connect(&m_process, qOverload<int, QProcess::ExitStatus>(&QProcess::finished),
            this, [this](int exitCode, QProcess::ExitStatus status) {
        emit commandFinished(exitCode, status == QProcess::CrashExit);
    });
}

bool CommandAdapter::isRunning() const
{
    return m_process.state() != QProcess::NotRunning;
}

void CommandAdapter::startShellCommand(const QString &workingDirectory, const QString &commandLine)
{
    if (isRunning()) {
        return;
    }

    m_process.setWorkingDirectory(workingDirectory);

#ifdef Q_OS_WIN
    QString program = "cmd.exe";
    QStringList args;
    args << "/C" << commandLine;
#else
    QString program = "/bin/sh";
    QStringList args;
    args << "-lc" << commandLine;
#endif

    emit commandStarted(commandLine);
    m_process.start(program, args);
}

void CommandAdapter::writeLine(const QString &text)
{
    if (!isRunning()) {
        return;
    }
    QByteArray payload = text.toLocal8Bit();
    payload.append('\n');
    m_process.write(payload);
    m_process.waitForBytesWritten(100);
}

void CommandAdapter::stop()
{
    if (!isRunning()) {
        return;
    }
    m_process.terminate();
    if (!m_process.waitForFinished(1500)) {
        m_process.kill();
    }
}
