#include "GitService.h"

#include "../adapters/CommandAdapter.h"

GitService::GitService(CommandAdapter *adapter, QObject *parent)
    : QObject(parent), m_adapter(adapter)
{
    if (!m_adapter) {
        return;
    }

    connect(m_adapter, &CommandAdapter::outputReady, this, &GitService::outputReady);
    connect(m_adapter, &CommandAdapter::commandStarted, this, &GitService::commandStarted);
    connect(m_adapter, &CommandAdapter::commandFinished, this, &GitService::commandFinished);
}

void GitService::setWorkingDirectory(const QString &workingDirectory)
{
    m_workingDirectory = workingDirectory;
}

void GitService::status() { run("git status"); }
void GitService::addAll() { run("git add ."); }

void GitService::commit(const QString &message)
{
    QString msg = message;
    msg.replace('"', '\'');
    run(QString("git commit -m \"%1\"").arg(msg));
}

void GitService::push() { run("git push"); }

void GitService::run(const QString &commandLine)
{
    if (!m_adapter || m_workingDirectory.isEmpty()) {
        return;
    }
    m_adapter->startShellCommand(m_workingDirectory, commandLine);
}
