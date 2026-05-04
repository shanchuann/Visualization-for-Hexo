#include "AiChatService.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QUuid>
#include <QUrl>

AiChatService::AiChatService(QNetworkAccessManager *network,
                             std::function<QString()> apiKeyResolver,
                             std::function<QString()> apiBaseResolver,
                             std::function<QString()> modelResolver,
                             std::function<QString()> providerResolver,
                             std::function<QString()> appDataRootResolver,
                             QObject *parent)
    : QObject(parent)
    , m_network(network)
    , m_apiKeyResolver(std::move(apiKeyResolver))
    , m_apiBaseResolver(std::move(apiBaseResolver))
    , m_modelResolver(std::move(modelResolver))
    , m_providerResolver(std::move(providerResolver))
    , m_appDataRootResolver(std::move(appDataRootResolver))
{
    loadConversationsFromDisk();
    cleanupStaleHistory();
}

QString AiChatService::historyFilePath() const
{
    QString root = m_appDataRootResolver ? m_appDataRootResolver() : QString();
    if (root.isEmpty()) return {};
    return QDir(root).filePath("ai_chat_history.json");
}

void AiChatService::loadConversationsFromDisk()
{
    QString path = historyFilePath();
    if (path.isEmpty()) return;

    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return;

    QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
    f.close();
    if (!doc.isObject()) return;

    QJsonObject root = doc.object();
    int version = root.value("version").toInt(1);

    if (version >= 2) {
        // New format: conversations array
        QJsonArray convs = root.value("conversations").toArray();
        for (const QJsonValue &cv : convs) {
            QJsonObject co = cv.toObject();
            AiConversation conv;
            conv.id = co.value("id").toString();
            conv.title = co.value("title").toString();
            conv.postPath = co.value("postPath").toString();
            conv.createdAt = static_cast<qint64>(co.value("createdAt").toDouble());
            conv.updatedAt = static_cast<qint64>(co.value("updatedAt").toDouble());
            QJsonArray msgs = co.value("messages").toArray();
            for (const QJsonValue &mv : msgs) {
                QJsonObject mo = mv.toObject();
                QVariantMap msg;
                msg["role"] = mo.value("role").toString();
                msg["content"] = mo.value("content").toString();
                msg["ts"] = static_cast<qint64>(mo.value("ts").toDouble());
                conv.messages.append(msg);
            }
            m_conversations.append(conv);
        }
    } else {
        // Legacy format: histories object keyed by postPath
        QJsonObject histories = root.value("histories").toObject();
        for (const QString &key : histories.keys()) {
            QJsonArray arr = histories.value(key).toArray();
            if (arr.isEmpty()) continue;
            AiConversation conv;
            conv.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
            conv.postPath = key;
            conv.createdAt = QDateTime::currentMSecsSinceEpoch();
            conv.updatedAt = conv.createdAt;
            for (const QJsonValue &v : arr) {
                QJsonObject mo = v.toObject();
                QVariantMap msg;
                msg["role"] = mo.value("role").toString();
                msg["content"] = mo.value("content").toString();
                msg["ts"] = static_cast<qint64>(mo.value("ts").toDouble());
                conv.messages.append(msg);
            }
            // Generate title from first user message
            for (const QVariant &v : conv.messages) {
                QVariantMap m = v.toMap();
                if (m.value("role").toString() == "user") {
                    conv.title = generateTitle(m.value("content").toString());
                    break;
                }
            }
            if (conv.title.isEmpty()) conv.title = "历史对话";
            m_conversations.append(conv);
        }
    }
    m_loaded = true;
}

void AiChatService::persistConversations()
{
    QString path = historyFilePath();
    if (path.isEmpty()) return;

    QJsonObject root;
    root["version"] = 2;
    QJsonArray convs;
    for (const AiConversation &conv : m_conversations) {
        QJsonObject co;
        co["id"] = conv.id;
        co["title"] = conv.title;
        co["postPath"] = conv.postPath;
        co["createdAt"] = conv.createdAt;
        co["updatedAt"] = conv.updatedAt;
        QJsonArray msgs;
        for (const QVariant &v : conv.messages) {
            QVariantMap m = v.toMap();
            QJsonObject mo;
            mo["role"] = m.value("role").toString();
            mo["content"] = m.value("content").toString();
            mo["ts"] = m.value("ts").toLongLong();
            msgs.append(mo);
        }
        co["messages"] = msgs;
        convs.append(co);
    }
    root["conversations"] = convs;

    QDir().mkpath(QFileInfo(path).absolutePath());
    QFile f(path);
    if (f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        f.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
    }
}

void AiChatService::cleanupStaleHistory()
{
    bool changed = false;
    for (auto it = m_conversations.begin(); it != m_conversations.end(); ) {
        if (!it->postPath.isEmpty() && !QFileInfo::exists(it->postPath)) {
            it = m_conversations.erase(it);
            changed = true;
        } else {
            ++it;
        }
    }
    if (changed) persistConversations();
}

AiConversation* AiChatService::findConversation(const QString &convId)
{
    for (AiConversation &conv : m_conversations) {
        if (conv.id == convId) return &conv;
    }
    return nullptr;
}

QString AiChatService::generateTitle(const QString &firstMessage) const
{
    QString t = firstMessage.trimmed();
    if (t.isEmpty()) return "新对话";
    if (t.length() <= 20) return t;
    return t.left(20) + "...";
}

QVariantList AiChatService::conversationList()
{
    if (!m_loaded) loadConversationsFromDisk();
    QVariantList result;
    // Sort by updatedAt descending (most recent first)
    QList<AiConversation> sorted = m_conversations;
    std::sort(sorted.begin(), sorted.end(),
        [](const AiConversation &a, const AiConversation &b) {
            return a.updatedAt > b.updatedAt;
        });
    for (const AiConversation &conv : sorted) {
        QVariantMap m;
        m["id"] = conv.id;
        m["title"] = conv.title;
        m["postPath"] = conv.postPath;
        m["createdAt"] = conv.createdAt;
        m["updatedAt"] = conv.updatedAt;
        m["messageCount"] = conv.messages.size();
        result.append(m);
    }
    return result;
}

QString AiChatService::createConversation(const QString &postPath, const QString &postTitle)
{
    if (!m_loaded) loadConversationsFromDisk();
    AiConversation conv;
    conv.id = QUuid::createUuid().toString(QUuid::WithoutBraces);
    conv.title = postTitle.isEmpty() ? "新对话" : postTitle;
    conv.postPath = postPath;
    conv.createdAt = QDateTime::currentMSecsSinceEpoch();
    conv.updatedAt = conv.createdAt;
    m_conversations.append(conv);
    persistConversations();
    return conv.id;
}

void AiChatService::deleteConversation(const QString &convId)
{
    if (!m_loaded) loadConversationsFromDisk();
    for (auto it = m_conversations.begin(); it != m_conversations.end(); ++it) {
        if (it->id == convId) {
            m_conversations.erase(it);
            persistConversations();
            return;
        }
    }
}

void AiChatService::renameConversation(const QString &convId, const QString &title)
{
    if (!m_loaded) loadConversationsFromDisk();
    AiConversation *conv = findConversation(convId);
    if (conv && !title.trimmed().isEmpty()) {
        conv->title = title.trimmed();
        conv->updatedAt = QDateTime::currentMSecsSinceEpoch();
        persistConversations();
    }
}

QVariantList AiChatService::loadConversation(const QString &convId)
{
    if (!m_loaded) loadConversationsFromDisk();
    AiConversation *conv = findConversation(convId);
    if (!conv) return {};
    return conv->messages;
}

void AiChatService::clearConversation(const QString &convId)
{
    if (!m_loaded) loadConversationsFromDisk();
    AiConversation *conv = findConversation(convId);
    if (conv) {
        conv->messages.clear();
        conv->updatedAt = QDateTime::currentMSecsSinceEpoch();
        persistConversations();
    }
}

void AiChatService::appendMessage(const QString &convId, const QString &role,
                                  const QString &content, qint64 ts)
{
    if (convId.isEmpty() || content.trimmed().isEmpty()) return;
    if (!m_loaded) loadConversationsFromDisk();
    AiConversation *conv = findConversation(convId);
    if (!conv) return;

    QVariantMap msg;
    msg["role"] = role;
    msg["content"] = content;
    msg["ts"] = ts;
    conv->messages.append(msg);
    conv->updatedAt = QDateTime::currentMSecsSinceEpoch();

    // Auto-generate title from first user message if still default
    if (conv->title == "新对话" && role == "user") {
        conv->title = generateTitle(content);
    }

    persistConversations();
}

int AiChatService::sendMessage(const QString &convId,
                               const QString &userText,
                               const QString &currentBody,
                               const QVariantList &referencedPostsContext)
{
    cancel();

    const int reqId = ++m_currentRequestId;
    m_currentConvId = convId;
    m_finished = false;

    if (!m_loaded) loadConversationsFromDisk();
    AiConversation *conv = findConversation(convId);
    if (!conv) {
        failRequest("对话不存在");
        return reqId;
    }

    const QString apiKey = m_apiKeyResolver ? m_apiKeyResolver() : QString();
    if (apiKey.trimmed().isEmpty()) {
        failRequest("请先在设置中配置 AI API Key（设置 → AI 服务）");
        return reqId;
    }

    QString provider = m_providerResolver ? m_providerResolver() : QString();
    provider = provider.trimmed();
    if (provider.isEmpty() || provider == "none") {
        provider = "glm";
        QString model = m_modelResolver ? m_modelResolver() : QString();
        QString userApiBase = m_apiBaseResolver ? m_apiBaseResolver() : QString();
        QString baseLower = userApiBase.trimmed().toLower();
        QString modelLower = model.trimmed().toLower();
        if (modelLower.startsWith("deepseek") || baseLower.contains("deepseek")) {
            provider = "deepseek";
        } else if (baseLower.contains("bigmodel") || baseLower.contains("zhipu")
                   || modelLower.startsWith("glm")) {
            provider = "glm";
        } else if (baseLower.contains("openai") || modelLower.startsWith("gpt")) {
            provider = "openai";
        }
    }

    QString model = m_modelResolver ? m_modelResolver() : QString();
    model = model.trimmed();
    if (model.isEmpty()) {
        model = (provider == "deepseek") ? "deepseek-chat" : "glm-4-flash";
    }

    const QString apiBase = resolveApiBase(provider);

    qDebug() << "[AiChatService] sendMessage: provider=" << provider
             << "model=" << model
             << "apiBase=" << apiBase
             << "keyEmpty=" << apiKey.trimmed().isEmpty()
             << "keyPrefix=" << apiKey.left(4) + "..."
             << "reqId=" << reqId;

    // Build messages array
    QJsonArray messages;
    {
        QJsonObject sysMsg;
        sysMsg["role"] = "system";
        sysMsg["content"] = buildSystemPrompt(currentBody, referencedPostsContext);
        messages.append(sysMsg);
    }

    // Add conversation history (last 12 messages to limit token usage)
    const QVariantList &hist = conv->messages;
    int start = qMax(0, hist.size() - 12);
    for (int i = start; i < hist.size(); i++) {
        QVariantMap m = hist[i].toMap();
        QString role = m.value("role").toString();
        if (role != "user" && role != "assistant") continue;
        QJsonObject msg;
        msg["role"] = role;
        msg["content"] = m.value("content").toString();
        messages.append(msg);
    }

    QJsonObject payload;
    payload["model"] = model;
    payload["stream"] = true;
    payload["temperature"] = 0.7;
    payload["messages"] = messages;

    QNetworkRequest request{QUrl(apiBase)};
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    request.setRawHeader("Authorization", QString("Bearer %1").arg(apiKey).toUtf8());
    request.setRawHeader("Accept", "text/event-stream");
    request.setAttribute(QNetworkRequest::Http2AllowedAttribute, false);

    m_sseBuffer.clear();
    m_accumulatedText.clear();

    m_reply = m_network->post(request, QJsonDocument(payload).toJson(QJsonDocument::Compact));

    connect(m_reply, &QNetworkReply::readyRead, this, &AiChatService::onReadyRead);
    connect(m_reply, &QNetworkReply::finished, this, &AiChatService::onFinished);

    emit chatStarted(reqId);
    return reqId;
}

void AiChatService::cancel()
{
    m_finished = true;
    if (m_reply) {
        QNetworkReply *r = m_reply;
        m_reply = nullptr;
        r->disconnect(this);
        r->abort();
        r->deleteLater();
    }
    m_sseBuffer.clear();
    m_accumulatedText.clear();
}

static QString extractServerError(const QByteArray &body)
{
    if (body.isEmpty()) return {};
    QJsonParseError err;
    QJsonDocument doc = QJsonDocument::fromJson(body, &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) return {};
    QJsonObject obj = doc.object();
    if (obj.contains("error") && obj.value("error").isObject()) {
        QString msg = obj.value("error").toObject().value("message").toString();
        if (!msg.isEmpty()) return msg;
        msg = obj.value("error").toObject().value("code").toString();
        if (!msg.isEmpty()) return msg;
    }
    QString msg = obj.value("message").toString();
    if (!msg.isEmpty()) return msg;
    return {};
}

void AiChatService::onReadyRead()
{
    if (!m_reply || m_finished) return;

    QByteArray chunk = m_reply->readAll();
    m_sseBuffer.append(chunk);

    while (!m_finished) {
        int idx = m_sseBuffer.indexOf("\n\n");
        if (idx < 0) {
            idx = m_sseBuffer.indexOf("\r\n\r\n");
            if (idx < 0) break;
            QByteArray event = m_sseBuffer.left(idx);
            m_sseBuffer.remove(0, idx + 4);
            parseSseChunk(event);
        } else {
            QByteArray event = m_sseBuffer.left(idx);
            m_sseBuffer.remove(0, idx + 2);
            parseSseChunk(event);
        }
    }
}

void AiChatService::parseSseChunk(const QByteArray &eventData)
{
    if (m_finished) return;

    const QList<QByteArray> lines = eventData.split('\n');
    for (const QByteArray &line : lines) {
        if (m_finished) return;
        if (line.startsWith(':')) continue;
        if (!line.startsWith("data:")) continue;

        QByteArray data = line.mid(5).trimmed();
        if (data == "[DONE]") {
            finishRequest(m_accumulatedText, QString());
            return;
        }

        QJsonParseError err;
        QJsonDocument doc = QJsonDocument::fromJson(data, &err);
        if (err.error != QJsonParseError::NoError || !doc.isObject()) continue;

        QJsonObject obj = doc.object();
        QJsonArray choices = obj.value("choices").toArray();
        if (choices.isEmpty()) continue;

        QJsonObject choice = choices.first().toObject();
        QJsonObject delta = choice.value("delta").toObject();
        QString content = delta.value("content").toString();

        if (!content.isEmpty()) {
            m_accumulatedText += content;
            emit chatChunk(m_currentRequestId, content);
        }
    }
}

void AiChatService::onFinished()
{
    if (!m_reply) return;

    QNetworkReply *r = m_reply;

    const int httpStatus = r->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QByteArray respBody = r->readAll();
    qDebug() << "[AiChatService] onFinished: reqId=" << m_currentRequestId
             << "error=" << r->error()
             << "errorString=" << r->errorString()
             << "httpStatus=" << httpStatus
             << "respBodySize=" << respBody.size()
             << "respBody=" << respBody.left(500);

    if (r->error() != QNetworkReply::NoError
        && r->error() != QNetworkReply::OperationCanceledError) {
        if (!m_finished) {
            QString detail = extractServerError(respBody);
            failRequest(detail.isEmpty() ? r->errorString() : detail);
        }
        if (m_reply == r) m_reply = nullptr;
        r->deleteLater();
        return;
    }

    if (!m_finished && !m_sseBuffer.isEmpty()) {
        parseSseChunk(m_sseBuffer);
        m_sseBuffer.clear();
    }

    if (!m_finished && !m_accumulatedText.isEmpty()) {
        finishRequest(m_accumulatedText, QString());
    }

    if (m_reply == r) m_reply = nullptr;
    r->deleteLater();
}

void AiChatService::finishRequest(const QString &fullText, const QString & /*proposedBody*/)
{
    if (m_finished) return;
    m_finished = true;

    QString proposed;
    QString displayText = fullText;

    static QRegularExpression markerRe(
        QStringLiteral("<<<ARTICLE_BEGIN>>>(.*)<<<ARTICLE_END>>>"),
        QRegularExpression::DotMatchesEverythingOption);

    QRegularExpressionMatch match = markerRe.match(fullText);
    if (match.hasMatch()) {
        proposed = match.captured(1).trimmed();
        static QRegularExpression fmRe(QStringLiteral("^---\\n.*?\\n---\\n"));
        proposed.remove(fmRe);
        displayText = fullText;
        displayText.replace(match.capturedStart(), match.capturedLength(),
                            QStringLiteral("✨ 已生成修改建议"));
    }

    m_sseBuffer.clear();
    m_accumulatedText.clear();

    emit chatDone(m_currentRequestId, displayText, proposed);
}

void AiChatService::failRequest(const QString &error)
{
    if (m_finished) return;
    m_finished = true;

    m_sseBuffer.clear();
    m_accumulatedText.clear();

    if (m_reply) {
        QNetworkReply *r = m_reply;
        m_reply = nullptr;
        r->disconnect(this);
        r->deleteLater();
    }

    emit chatError(m_currentRequestId, error);
}

QString AiChatService::resolveApiBase(const QString &provider) const
{
    QString base = m_apiBaseResolver ? m_apiBaseResolver() : QString();
    base = base.trimmed();

    if (base.isEmpty()) {
        if (provider == "deepseek") {
            base = "https://api.deepseek.com/chat/completions";
        } else {
            base = "https://open.bigmodel.cn/api/paas/v4/chat/completions";
        }
    } else if (!base.endsWith("/chat/completions", Qt::CaseInsensitive)) {
        if (base.endsWith("/")) {
            base += "chat/completions";
        } else {
            base += "/chat/completions";
        }
    }
    return base;
}

QString AiChatService::buildSystemPrompt(const QString &currentBody, const QVariantList &refs) const
{
    QString prompt = QStringLiteral(
        "你是一位 Hexo 博客编辑助手,帮用户基于其指令修改当前文章。\n\n"
        "工作规则:\n"
        "1. 只修改用户在最新一条消息中要求修改的部分,保持其他内容原样。\n"
        "2. 保持原文的换行与段落结构(不要把多行段落合并成一行)。\n"
        "3. 不要输出 frontmatter(--- 之间的元数据)。\n"
        "4. 回复中不要使用表情符号(emoji),用朴素的文字表达。\n\n"
        "输出格式:\n"
        "- 当你要修改文章时,**严格用以下标记包裹完整的修改后正文**:\n"
        "<<<ARTICLE_BEGIN>>>\n"
        "（这里是修改后的完整正文）\n"
        "<<<ARTICLE_END>>>\n"
        "- 标记之外可以写一两句简短说明。\n"
        "- 当用户只是闲聊或询问而不需要改文章时,**不要输出标记**,只用自然语言回复。\n\n"
        "【当前文章正文】\n"
        "%1\n").arg(currentBody);

    if (!refs.isEmpty()) {
        QString refsBlock = QStringLiteral("\n\n【用户引用的参考文章】\n");
        for (const QVariant &rv : refs) {
            QVariantMap ref = rv.toMap();
            refsBlock += QStringLiteral("\n---\n标题：%1\n描述：%2\n")
                .arg(ref.value("title").toString(),
                     ref.value("description").toString());
            QVariantList headings = ref.value("headings").toList();
            if (!headings.isEmpty()) {
                refsBlock += QStringLiteral("标题结构：\n");
                for (const QVariant &hv : headings) {
                    refsBlock += hv.toString() + "\n";
                }
            }
        }
        prompt += refsBlock;
    }

    return prompt;
}
