#include "HexoService.h"

#include "../adapters/CommandAdapter.h"

HexoService::HexoService(CommandAdapter *adapter, QObject *parent)
    : QObject(parent), m_adapter(adapter)
{
    if (!m_adapter) {
        return;
    }

    connect(m_adapter, &CommandAdapter::outputReady, this, &HexoService::outputReady);
    connect(m_adapter, &CommandAdapter::commandStarted, this, &HexoService::commandStarted);
    connect(m_adapter, &CommandAdapter::commandFinished, this, &HexoService::commandFinished);
}

void HexoService::setWorkingDirectory(const QString &workingDirectory)
{
    m_workingDirectory = workingDirectory;
}

QString HexoService::workingDirectory() const
{
    return m_workingDirectory;
}

void HexoService::generate() { run("npx hexo generate"); }
void HexoService::deploy() { run("npx hexo deploy"); }
void HexoService::clean() { run("npx hexo clean"); }
void HexoService::server() { run("npx hexo server"); }

void HexoService::newPost(const QString &title)
{
    run(QString("npx hexo new post \"%1\"").arg(title));
}

void HexoService::newPage(const QString &title)
{
    run(QString("npx hexo new page \"%1\"").arg(title));
}

void HexoService::run(const QString &commandLine)
{
    if (!m_adapter || m_workingDirectory.isEmpty()) {
        return;
    }
    m_adapter->startShellCommand(m_workingDirectory, commandLine);
}
