#pragma once

#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include <functional>

class QNetworkAccessManager;
class QNetworkReply;

struct AiConversation {
    QString id;
    QString title;
    QString postPath;
    qint64 createdAt = 0;
    qint64 updatedAt = 0;
    QVariantList messages; // [{role, content, ts}, ...]
};

class AiChatService : public QObject
{
    Q_OBJECT
public:
    explicit AiChatService(QNetworkAccessManager *network,
                           std::function<QString()> apiKeyResolver,
                           std::function<QString()> apiBaseResolver,
                           std::function<QString()> modelResolver,
                           std::function<QString()> providerResolver,
                           std::function<QString()> appDataRootResolver,
                           QObject *parent = nullptr);

    // Conversation management
    Q_INVOKABLE QVariantList conversationList();
    Q_INVOKABLE QString createConversation(const QString &postPath, const QString &postTitle);
    Q_INVOKABLE void deleteConversation(const QString &convId);
    Q_INVOKABLE void renameConversation(const QString &convId, const QString &title);
    Q_INVOKABLE QVariantList loadConversation(const QString &convId);
    Q_INVOKABLE void clearConversation(const QString &convId);
    Q_INVOKABLE void appendMessage(const QString &convId, const QString &role,
                                   const QString &content, qint64 ts);

    // Send a message in a conversation
    Q_INVOKABLE int sendMessage(const QString &convId,
                                const QString &userText,
                                const QString &currentBody,
                                const QVariantList &referencedPostsContext);
    Q_INVOKABLE void cancel();

signals:
    void chatStarted(int requestId);
    void chatChunk(int requestId, const QString &delta);
    void chatDone(int requestId, const QString &fullText, const QString &proposedBody);
    void chatError(int requestId, const QString &message);

private:
    void onReadyRead();
    void onFinished();
    void parseSseChunk(const QByteArray &eventData);
    void finishRequest(const QString &fullText, const QString &proposedBody);
    void failRequest(const QString &error);
    QString buildSystemPrompt(const QString &currentBody, const QVariantList &refs) const;

    void persistConversations();
    void loadConversationsFromDisk();
    QString historyFilePath() const;
    QString resolveApiBase(const QString &provider) const;
    void cleanupStaleHistory();
    AiConversation* findConversation(const QString &convId);
    QString generateTitle(const QString &firstMessage) const;

    QNetworkAccessManager *m_network;
    QNetworkReply *m_reply = nullptr;
    QByteArray m_sseBuffer;
    QString m_accumulatedText;
    int m_currentRequestId = 0;
    QString m_currentConvId;
    bool m_finished = true;
    QList<AiConversation> m_conversations;
    bool m_loaded = false;

    std::function<QString()> m_apiKeyResolver;
    std::function<QString()> m_apiBaseResolver;
    std::function<QString()> m_modelResolver;
    std::function<QString()> m_providerResolver;
    std::function<QString()> m_appDataRootResolver;
};
