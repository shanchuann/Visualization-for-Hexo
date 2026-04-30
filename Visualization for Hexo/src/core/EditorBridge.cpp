#include "EditorBridge.h"

EditorBridge::EditorBridge(QObject *parent)
    : QObject(parent)
{
}

QString EditorBridge::content() const
{
    return m_content;
}

void EditorBridge::setContent(const QString &content)
{
    if (m_content == content) {
        return;
    }
    m_content = content;
    emit contentChanged();
}

void EditorBridge::notifyContentChangedFromJs(const QString &content)
{
    setContent(content);
}

void EditorBridge::requestSave()
{
    emit saveRequested();
}
