#include "AppContext.h"

#include "../adapters/CommandAdapter.h"

#include <QCoreApplication>
#include <QDateTime>
#include <QDir>
#include <QDesktopServices>
#include <QFile>
#include <QFileInfo>
#include <QFont>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QEventLoop>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrl>
#include <QProcess>
#include <QRegularExpression>
#include <QSqlDatabase>
#include <QSqlError>
#include <QSqlQuery>
#include <QStandardPaths>
#include <QSet>
#include <QTextDocument>
#include <QTextStream>
#include <QFutureWatcher>
#include <QtConcurrent/QtConcurrent>

namespace {
QString sanitizeConsoleChunk(const QString &raw)
{
    QString out = raw;
    // Strip ANSI color/control sequences so logs remain readable in TextArea.
    static const QRegularExpression ansiCsi("\\x1B\\[[0-9;?]*[ -/]*[@-~]");
    static const QRegularExpression ansiOsc("\\x1B\\][^\\x07\\x1B]*(\\x07|\\x1B\\\\)");
    out.remove(ansiCsi);
    out.remove(ansiOsc);
    out.replace("\r\n", "\n");
    out.replace('\r', '\n');
    return out;
}

QString buildPreviewHtml(const QString &markdown, int bodyFontPx, qreal lineSpacing)
{
    if (markdown.trimmed().isEmpty()) {
        return QString();
    }

    const int safeBodyFont = qBound(12, bodyFontPx, 36);
    const qreal safeLineSpacing = qBound(1.2, lineSpacing, 2.6);
    const QString bodyFontCss = QString::number(safeBodyFont);
    const QString lineHeightCss = QString::number(safeLineSpacing, 'f', 2);

    QTextDocument doc;
    QFont defaultPreviewFont;
    defaultPreviewFont.setFamilies({"PingFang SC", "Microsoft YaHei UI", "Noto Sans CJK SC", "SimSun"});
    defaultPreviewFont.setPixelSize(safeBodyFont);
    doc.setDefaultFont(defaultPreviewFont);
    doc.setMarkdown(markdown);
    QString html = doc.toHtml();

    // Qt-generated HTML may carry inline pt sizes that override CSS body size.
    static const QRegularExpression inlinePtFontRe("font-size\\s*:\\s*[0-9]+(?:\\.[0-9]+)?pt\\s*;");
    html.replace(inlinePtFontRe, QString("font-size:%1px;").arg(bodyFontCss));

    const QString previewStyle = QStringLiteral(
        "<style>"
        "body{font-family:'PingFang SC','Microsoft YaHei UI','Noto Sans CJK SC','SimSun',sans-serif;"
        "font-size:%1px;line-height:%2;color:#2B261B;letter-spacing:0.01em;}"
        "p,ul,ol,li,td,th{font-size:1em;line-height:%2;margin:0 0 16px 0;}"
        "h1,h2,h3,h4,h5,h6{font-weight:700;line-height:1.35;color:#1F2A44;margin:26px 0 14px 0;}"
        "h1{font-size:1.95em;}"
        "h2{font-size:1.58em;}"
        "h3{font-size:1.34em;}"
        "h4{font-size:1.18em;}"
        "a{color:#1B6EF3;text-decoration:none;}"
        "a:hover{text-decoration:underline;}"
        "img{display:block;margin:12px auto 14px auto;max-width:100%;max-height:340px;height:auto;object-fit:contain;border-radius:6px;}"
        "pre{margin:14px 0;padding:12px 14px;border-radius:8px;background:#F5F7FC;border:1px solid #E1E6F2;overflow:auto;}"
        "code{font-family:'Cascadia Mono','Consolas','Courier New',monospace;font-size:1.08em;}"
        "pre code{font-size:0.97em;line-height:1.7;color:#1E2A44;background:transparent;}"
        "blockquote{margin:14px 0;padding:10px 14px;border-left:4px solid #B8C2D9;background:#F4F7FF;color:#3A4152;}"
        "blockquote p{margin:0 0 8px 0;}"
        "blockquote p:last-child{margin-bottom:0;}"
        "</style>")
        .arg(bodyFontCss, lineHeightCss);

    const QString headCloseTag = QStringLiteral("</head>");
    const int headCloseIndex = html.indexOf(headCloseTag, Qt::CaseInsensitive);
    if (headCloseIndex >= 0) {
        html.insert(headCloseIndex, previewStyle);
    } else {
        html.prepend(previewStyle);
    }

    return html;
}

QString patchSimpleYamlPreserveLayout(const QString &original, const QVariantMap &updates)
{
    QStringList lines = original.split('\n');
    QSet<QString> handledKeys;
    static const QRegularExpression keyValueRe(R"(^\s*([^#:\s][^:]*)\s*:\s*(.*)$)");

    for (QString &line : lines) {
        const QString trimmed = line.trimmed();
        if (trimmed.isEmpty() || trimmed.startsWith('#')) {
            continue;
        }

        const QRegularExpressionMatch m = keyValueRe.match(line);
        if (!m.hasMatch()) {
            continue;
        }

        const QString key = m.captured(1).trimmed();
        if (!updates.contains(key)) {
            continue;
        }

        const QString oldValue = m.captured(2).trimmed();
        const QString newValue = updates.value(key).toString().trimmed();
        if (oldValue == newValue) {
            handledKeys.insert(key);
            continue;
        }

        const int colonIdx = line.indexOf(':');
        if (colonIdx < 0) {
            continue;
        }
        const QString left = line.left(colonIdx + 1);
        line = left + " " + newValue;
        handledKeys.insert(key);
    }

    for (auto it = updates.constBegin(); it != updates.constEnd(); ++it) {
        if (handledKeys.contains(it.key())) {
            continue;
        }
        lines.append(QString("%1: %2").arg(it.key(), it.value().toString().trimmed()));
    }

    return lines.join("\n");
}

QString readDotEnvValue(const QString &filePath, const QString &key)
{
    QFile f(filePath);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return {};
    }

    QTextStream in(&f);
    while (!in.atEnd()) {
        QString line = in.readLine().trimmed();
        if (line.isEmpty() || line.startsWith('#')) {
            continue;
        }
        if (line.startsWith("export ")) {
            line = line.mid(7).trimmed();
        }
        const int idx = line.indexOf('=');
        if (idx <= 0) {
            continue;
        }

        const QString k = line.left(idx).trimmed();
        if (k != key) {
            continue;
        }

        QString v = line.mid(idx + 1).trimmed();
        if ((v.startsWith('"') && v.endsWith('"')) || (v.startsWith('\'') && v.endsWith('\''))) {
            v = v.mid(1, v.size() - 2);
        }
        return v.trimmed();
    }
    return {};
}

#ifdef Q_OS_WIN
QList<qint64> findListeningPidsOnPort(const int port)
{
    QProcess proc;
    proc.start("netstat", {"-ano", "-p", "tcp"});
    if (!proc.waitForStarted(3000)) {
        return {};
    }
    if (!proc.waitForFinished(5000)) {
        proc.kill();
        proc.waitForFinished(1000);
    }

    const QString output = QString::fromLocal8Bit(proc.readAllStandardOutput())
                         + QString::fromLocal8Bit(proc.readAllStandardError());
    const QString portToken = QString(":%1").arg(port);

    QList<qint64> pids;
    for (const QString &rawLine : output.split('\n', Qt::SkipEmptyParts)) {
        const QString line = rawLine.trimmed();
        if (!line.contains(portToken) || !line.contains("LISTENING", Qt::CaseInsensitive)) {
            continue;
        }
        const QStringList cols = line.simplified().split(' ');
        if (cols.size() < 5) {
            continue;
        }
        bool ok = false;
        const qint64 pid = cols.last().toLongLong(&ok);
        if (ok && pid > 0 && !pids.contains(pid)) {
            pids.push_back(pid);
        }
    }
    return pids;
}

bool killProcessByPid(const qint64 pid)
{
    QProcess killer;
    killer.start("taskkill", {"/PID", QString::number(pid), "/F"});
    if (!killer.waitForStarted(3000)) {
        return false;
    }
    if (!killer.waitForFinished(5000)) {
        killer.kill();
        killer.waitForFinished(1000);
        return false;
    }
    return killer.exitStatus() == QProcess::NormalExit && killer.exitCode() == 0;
}
#endif
}

AppContext::AppContext(QObject *parent)
    : QObject(parent), m_command(new CommandAdapter(this)), m_network(new QNetworkAccessManager(this))
{
    m_debounceGenerate.setSingleShot(true);
    m_debounceGenerate.setInterval(1200);

    connect(&m_debounceGenerate, &QTimer::timeout, this, [this]() {
        if (m_autoGenerateEnabled && !m_taskRunning && !m_currentProjectPath.isEmpty()) {
            runCommand("hexo generate", true);
        }
    });

    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, [this]() {
        if (m_autoGenerateEnabled && !m_currentProjectPath.isEmpty()) {
            m_debounceGenerate.start();
            appendStructuredLog("info", "WATCHER_FILE", "detected file change, debounced generate scheduled");
        }
    });
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this]() {
        if (m_autoGenerateEnabled && !m_currentProjectPath.isEmpty()) {
            m_debounceGenerate.start();
            appendStructuredLog("info", "WATCHER_DIR", "detected directory change, debounced generate scheduled");
        }
    });

    connect(m_command, &CommandAdapter::commandStarted, this, [this](const QString &cmd) {
        m_taskRunning = true;
        emit taskRunningChanged();
        appendLog(QString("$ %1").arg(cmd));
        resetPreviewOpenState(cmd);
    });
    connect(m_command, &CommandAdapter::outputReady, this, [this](const QString &text) {
        appendLog(text);
        handlePreviewOutput(text);
    });
    connect(m_command, &CommandAdapter::commandFinished, this, [this](int exitCode, bool crashed) {
        m_taskRunning = false;
        emit taskRunningChanged();
        appendLog(QString("[task finished] exit=%1 crashed=%2").arg(exitCode).arg(crashed ? "true" : "false"));
        m_pendingPreviewOpen = false;
        m_previewOpened = false;
    });

    loadProjectsFromDisk();
    loadAiConfig();

    m_firstRun = !QFileInfo::exists(firstRunFlagPath());
}

QString AppContext::currentProjectPath() const { return m_currentProjectPath; }
bool AppContext::taskRunning() const { return m_taskRunning; }
QString AppContext::logText() const { return m_logText; }
QVariantList AppContext::projects() const { return m_projects; }
QVariantList AppContext::posts() const { return m_posts; }
QVariantList AppContext::searchResults() const { return m_searchResults; }
QVariantMap AppContext::configMap() const { return m_configMap; }
QVariantList AppContext::plugins() const { return m_plugins; }

QStringList AppContext::allCategories() const {
    QStringList cats;
    for (const QVariant& v : m_posts) {
        QString cat = v.toMap().value("category").toString().trimmed();
        if (!cat.isEmpty() && !cats.contains(cat)) {
            cats.append(cat);
        }
    }
    return cats;
}

QStringList AppContext::allTags() const {
    QStringList allT;
    for (const QVariant& v : m_posts) {
        QString tagsRaw = v.toMap().value("tags").toString();
        // Tags might be comma separated or json array string if complex, assuming common comma or space.
        // Actually typical yaml allows list, so wait... we'll assume comma separated or space separated for simple.
        QStringList tList = tagsRaw.split(QRegularExpression("[\\[\\]\\,]"), Qt::SkipEmptyParts);
        for (QString t : tList) {
            t = t.trimmed();
            if (!t.isEmpty() && !allT.contains(t)) {
                allT.append(t);
            }
        }
    }
    return allT;
}

int AppContext::postSortMode() const { return m_postSortMode; }

bool AppContext::autoGenerateEnabled() const { return m_autoGenerateEnabled; }

QString AppContext::openedPostPath() const { return m_opened.path; }
QString AppContext::openedPostTitle() const { return m_opened.title; }
QString AppContext::openedPostCategory() const { return m_opened.category; }
QString AppContext::openedPostTags() const { return m_opened.tags; }
QString AppContext::openedPostDate() const { return m_opened.date; }
QString AppContext::openedPostCover() const { return m_opened.cover; }
QString AppContext::openedPostDescription() const { return m_opened.description; }
QString AppContext::openedPostBody() const { return m_opened.body; }

QString AppContext::aiProvider() const { return m_aiProvider; }
QString AppContext::aiApiBase() const { return m_aiApiBase; }
QString AppContext::aiModel() const { return m_aiModel; }

QString AppContext::renderMarkdownForPreview(const QString &markdown,
                                             int bodyFontPx,
                                             qreal lineSpacing) const
{
    return buildPreviewHtml(markdown, bodyFontPx, lineSpacing);
}

void AppContext::renderMarkdownForPreviewAsync(const QString &markdown,
                                               int bodyFontPx,
                                               qreal lineSpacing,
                                               int requestId)
{
    const QString trimmed = markdown.trimmed();
    if (trimmed.isEmpty()) {
        emit previewMarkdownReady(QString(), requestId);
        return;
    }

    auto *watcher = new QFutureWatcher<QString>(this);
    connect(watcher, &QFutureWatcher<QString>::finished, this, [this, watcher, requestId]() {
        const QString html = watcher->future().result();
        watcher->deleteLater();
        emit previewMarkdownReady(html, requestId);
    });

    watcher->setFuture(QtConcurrent::run([markdown, bodyFontPx, lineSpacing]() {
        return buildPreviewHtml(markdown, bodyFontPx, lineSpacing);
    }));
}

void AppContext::setAutoGenerateEnabled(bool enabled)
{
    if (m_autoGenerateEnabled == enabled) {
        return;
    }
    m_autoGenerateEnabled = enabled;
    emit autoGenerateEnabledChanged();
}

void AppContext::setPostSortMode(int mode)
{
    const int bounded = qBound(0, mode, 3);
    if (m_postSortMode == bounded) {
        return;
    }
    m_postSortMode = bounded;
    emit postSortModeChanged();
    scanPosts();
}

void AppContext::setAiProvider(const QString &provider)
{
    if (m_aiProvider == provider) {
        return;
    }
    m_aiProvider = provider;
    saveAiConfig();
    emit aiProviderChanged();
}

void AppContext::setAiApiBase(const QString &apiBase)
{
    if (m_aiApiBase == apiBase) {
        return;
    }
    m_aiApiBase = apiBase;
    saveAiConfig();
    emit aiApiBaseChanged();
}

void AppContext::setAiModel(const QString &model)
{
    if (m_aiModel == model) {
        return;
    }
    m_aiModel = model;
    saveAiConfig();
    emit aiModelChanged();
}

void AppContext::applyAiSettings(const QString &provider,
                                 const QString &apiBase,
                                 const QString &model)
{
    const bool providerChanged = (m_aiProvider != provider);
    const bool apiBaseChanged = (m_aiApiBase != apiBase);
    const bool modelChanged = (m_aiModel != model);

    if (!providerChanged && !apiBaseChanged && !modelChanged) {
        return;
    }

    if (providerChanged) {
        m_aiProvider = provider;
    }
    if (apiBaseChanged) {
        m_aiApiBase = apiBase;
    }
    if (modelChanged) {
        m_aiModel = model;
    }

    saveAiConfig();

    if (providerChanged) {
        emit aiProviderChanged();
    }
    if (apiBaseChanged) {
        emit aiApiBaseChanged();
    }
    if (modelChanged) {
        emit aiModelChanged();
    }
}

void AppContext::addProject(const QString &path)
{
    QString clean = QDir(path).absolutePath();
    if (!isHexoProject(clean)) {
        appendLog(QString("[project] invalid hexo project: %1").arg(clean));
        return;
    }

    for (const QVariant &entry : m_projects) {
        if (entry.toMap().value("path").toString() == clean) {
            switchProject(clean);
            return;
        }
    }

    QVariantMap obj;
    obj["name"] = QFileInfo(clean).fileName();
    obj["path"] = clean;
    m_projects.push_back(obj);
    emit projectsChanged();
    saveProjectsToDisk();

    switchProject(clean);
}

void AppContext::switchProject(const QString &path)
{
    QString clean = QDir(path).absolutePath();
    if (m_currentProjectPath == clean) {
        return;
    }
    if (!isHexoProject(clean)) {
        appendLog(QString("[project] switch failed, invalid path: %1").arg(clean));
        return;
    }

    m_currentProjectPath = clean;
    emit currentProjectPathChanged();

    appendLog(QString("[project] switched: %1").arg(clean));
    reloadAllProjectBoundData();
}

void AppContext::removeProject(const QString &path)
{
    QVariantList out;
    for (const QVariant &entry : m_projects) {
        if (entry.toMap().value("path").toString() != QDir(path).absolutePath()) {
            out.push_back(entry);
        }
    }
    m_projects = out;
    emit projectsChanged();
    saveProjectsToDisk();

    if (m_currentProjectPath == QDir(path).absolutePath()) {
        m_currentProjectPath.clear();
        emit currentProjectPathChanged();
        m_posts.clear();
        emit postsChanged();
        clearOpenedPost();
    }
}

bool AppContext::isHexoProject(const QString &path) const
{
    QDir dir(path);
    return dir.exists("_config.yml") && dir.exists("source/_posts");
}

bool AppContext::initializeHexoProject(const QString &path)
{
    const QString clean = QDir(path).absolutePath();
    if (clean.trimmed().isEmpty()) {
        appendLog("[init] empty project path");
        return false;
    }
    if (m_taskRunning || m_command->isRunning()) {
        appendLog("[init] another task is running");
        return false;
    }

    QDir dir(clean);
    if (!dir.exists() && !QDir().mkpath(clean)) {
        appendLog(QString("[init] failed to create directory: %1").arg(clean));
        return false;
    }

    if (isHexoProject(clean)) {
        appendLog(QString("[init] already a hexo project: %1").arg(clean));
        addProject(clean);
        if (!m_taskRunning) {
            runHexoServer();
        }
        return true;
    }

    appendLog(QString("[init] initializing hexo project: %1").arg(clean));

    QProcess initProc;
    initProc.setWorkingDirectory(clean);
    initProc.setProcessChannelMode(QProcess::MergedChannels);

#ifdef Q_OS_WIN
    const QString program = "cmd.exe";
    const QStringList args = {"/C", "hexo", "init", "."};
#else
    const QString program = "/bin/sh";
    const QStringList args = {"-lc", "hexo init ."};
#endif

    initProc.start(program, args);
    if (!initProc.waitForStarted(5000)) {
        appendLog("[init] failed to start 'hexo init' command");
        return false;
    }

    while (initProc.state() != QProcess::NotRunning) {
        initProc.waitForReadyRead(200);
        const QString chunk = sanitizeConsoleChunk(QString::fromLocal8Bit(initProc.readAll()));
        if (!chunk.isEmpty()) {
            appendLog(chunk);
        }
    }
    const QString tail = sanitizeConsoleChunk(QString::fromLocal8Bit(initProc.readAll()));
    if (!tail.isEmpty()) {
        appendLog(tail);
    }

    const bool ok = (initProc.exitStatus() == QProcess::NormalExit)
                 && (initProc.exitCode() == 0)
                 && isHexoProject(clean);
    if (!ok) {
        appendLog(QString("[init] hexo init failed, exit=%1").arg(initProc.exitCode()));
        return false;
    }

    appendLog("[init] hexo project initialized successfully");
    addProject(clean);
    if (!m_taskRunning) {
        runHexoServer();
    }
    return true;
}

void AppContext::runHexoGenerate() { runCommand("hexo generate"); }
void AppContext::runHexoDeploy() { runCommand("hexo deploy"); }
void AppContext::runHexoClean() { runCommand("hexo clean"); }
void AppContext::runHexoServer()
{
#ifdef Q_OS_WIN
    const QList<qint64> pids = findListeningPidsOnPort(4000);
    if (!pids.isEmpty()) {
        for (const qint64 pid : pids) {
            if (killProcessByPid(pid)) {
                appendLog(QString("[task] released port 4000 by killing pid=%1").arg(pid));
            } else {
                appendLog(QString("[task] failed to release port 4000, pid=%1").arg(pid));
            }
        }
    }
#endif
    runCommand("hexo server");
}

void AppContext::stopCurrentTask()
{
    m_command->stop();
    appendLog("[task] stopped by user");
}

void AppContext::submitConsoleInput(const QString &text)
{
    const QString input = text.trimmed();
    if (input.isEmpty()) {
        return;
    }

    if (input.compare("/stop", Qt::CaseInsensitive) == 0
        || input.compare("/ctrl+c", Qt::CaseInsensitive) == 0
        || input.compare("ctrl+c", Qt::CaseInsensitive) == 0
        || input.compare("^c", Qt::CaseInsensitive) == 0) {
        stopCurrentTask();
        return;
    }

    if (m_taskRunning || m_command->isRunning()) {
        appendLog(QString("> %1").arg(input));
        m_command->writeLine(input);
        return;
    }

    runCommand(input, false);
}

void AppContext::scanPosts()
{
    m_posts.clear();

    QDir dir(postsDirectory());
    QStringList files = dir.entryList(QStringList() << "*.md", QDir::Files);
    
    QList<PostData> parsedPosts;
    for (const QString &f : files) {
        QString fullPath = dir.filePath(f);
        parsedPosts.append(readMarkdown(fullPath));
    }

    std::sort(parsedPosts.begin(), parsedPosts.end(), [this](const PostData &a, const PostData &b) {
        if (m_postSortMode == 0 || m_postSortMode == 1) {
            // Regex-based parsing handles all combinations of zero-padded / non-padded
            // month and day (e.g. "2026-2-7 12:29:42", "2026-02-4 14:25:26", "2026-03-13 14:36:04").
            // Qt 6 format-string parsing is strict about single-char specifiers, so mixing
            // zero-padded month with non-padded day (or vice-versa) silently fails and falls
            // back to a broken string comparison.
            auto parseDate = [](const QString& d) -> QDateTime {
                static const QRegularExpression re(
                    R"((\d{4})[-/](\d{1,2})[-/](\d{1,2})(?:[T ](\d{1,2}):(\d{2}):(\d{2}))?)"
                );
                const QRegularExpressionMatch m = re.match(d.trimmed());
                if (m.hasMatch()) {
                    const int yr  = m.captured(1).toInt();
                    const int mo  = m.captured(2).toInt();
                    const int dy  = m.captured(3).toInt();
                    const int hr  = m.captured(4).isEmpty() ? 0 : m.captured(4).toInt();
                    const int mn  = m.captured(5).isEmpty() ? 0 : m.captured(5).toInt();
                    const int sc  = m.captured(6).isEmpty() ? 0 : m.captured(6).toInt();
                    return QDateTime(QDate(yr, mo, dy), QTime(hr, mn, sc));
                }
                return QDateTime::fromString(d.trimmed(), Qt::ISODate);
            };
            QDateTime da = parseDate(a.date);
            QDateTime db = parseDate(b.date);
            
            if (da.isValid() && db.isValid()) {
                if (m_postSortMode == 1) return da < db;
                return da > db;
            }
            if (m_postSortMode == 1) return a.date < b.date; // fallback
            return a.date > b.date;
        }
        if (m_postSortMode == 2) return QString::localeAwareCompare(a.title, b.title) < 0;
        if (m_postSortMode == 3) return QString::localeAwareCompare(a.title, b.title) > 0;
        return a.date > b.date; // Default (mode 0)
    });

    for (const PostData &p : parsedPosts) {
        QVariantMap item;
        item["path"] = p.path;
        item["title"] = p.title.isEmpty() ? QFileInfo(p.path).completeBaseName() : p.title;
        item["date"] = p.date;
        item["category"] = p.category;
        item["tags"] = p.tags;
        m_posts.push_back(item);
    }
    emit postsChanged();
}

void AppContext::openPost(const QString &filePath)
{
    if (filePath == m_opened.path) {
        if (m_opened.date.trimmed().isEmpty() || m_opened.title.trimmed().isEmpty()) {
            setOpenedPost(readMarkdown(filePath));
        }
        return;
    }
    if (!QFile::exists(filePath)) {
        appendLog(QString("[post] file not found: %1").arg(filePath));
        return;
    }
    setOpenedPost(readMarkdown(filePath));
}

void AppContext::saveOpenedPost(const QString &title,
                                const QString &category,
                                const QString &tags,
                                const QString &date,
                                const QString &cover,
                                const QString &description,
                                const QString &body)
{
    if (m_opened.path.isEmpty()) {
        appendLog("[post] no opened post");
        return;
    }

    m_opened.title = title;
    m_opened.category = category;
    m_opened.tags = tags;
    m_opened.date = date.trimmed().isEmpty()
        ? QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss")
        : date;
    m_opened.cover = cover.trimmed();
    m_opened.description = description.trimmed();
    m_opened.body = body;
    if (m_opened.description.trimmed().isEmpty() && !m_opened.body.trimmed().isEmpty()) {
        const QString generated = generateDescriptionWithGlm(m_opened.title, m_opened.body);
        if (!generated.isEmpty()) {
            m_opened.description = generated;
            appendStructuredLog("info", "POST_DESC_GEN", "description generated via GLM-4.7-flash");
        }
    }

    if (writeMarkdown(m_opened)) {
        appendLog(QString("[post] saved: %1").arg(m_opened.path));
        scanPosts();
        rebuildSearchIndex();
        if (m_autoGenerateEnabled) {
            runCommand("hexo generate", true);
        }
    } else {
        appendLog(QString("[post] save failed: %1").arg(m_opened.path));
    }
}

void AppContext::newPost(const QString &title, const QString &category, const QString &tags)
{
    if (m_currentProjectPath.isEmpty()) {
        appendLog("[post] please select project first");
        return;
    }

    QString postTitle = title.trimmed().isEmpty() ? "New Post" : title.trimmed();
    QString slug = slugify(postTitle);
    QString date = QDateTime::currentDateTime().toString("yyyy-MM-dd HH:mm:ss");
    QString fileDate = QDateTime::currentDateTime().toString("yyyy-MM-dd");
    QString filePath = QDir(postsDirectory()).filePath(fileDate + "-" + slug + ".md");

    PostData p;
    p.path = filePath;
    p.title = postTitle;
    p.category = category;
    p.tags = tags;
    p.date = date;
    p.body = "";
    p.leadingBlankLines = 0;

    if (writeMarkdown(p)) {
        appendLog(QString("[post] created: %1").arg(filePath));
        scanPosts();
        openPost(filePath);
        rebuildSearchIndex();
    } else {
        appendLog(QString("[post] create failed: %1").arg(filePath));
    }
}

void AppContext::deletePost(const QString &filePath)
{
    QFile f(filePath);
    if (!f.exists()) {
        return;
    }
    if (f.remove()) {
        appendLog(QString("[post] deleted: %1").arg(filePath));
        if (m_opened.path == filePath) {
            clearOpenedPost();
        }
        scanPosts();
        rebuildSearchIndex();
    } else {
        appendLog(QString("[post] failed to delete: %1").arg(filePath));
    }
}

void AppContext::loadSiteConfig()
{
    QFile f(configFile());
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        appendLog("[config] failed to open _config.yml");
        return;
    }
    QString content = QString::fromUtf8(f.readAll());
    m_configMap = parseSimpleYaml(content);
    emit configMapChanged();
}

void AppContext::saveSiteConfig(const QVariantMap &map)
{
    QString original;
    {
        QFile in(configFile());
        if (!in.open(QIODevice::ReadOnly | QIODevice::Text)) {
            appendLog("[config] failed to open _config.yml");
            return;
        }
        original = QString::fromUtf8(in.readAll());
    }

    const QString updated = patchSimpleYamlPreserveLayout(original, map);

    QFile f(configFile());
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        appendLog("[config] failed to write _config.yml");
        return;
    }

    f.write(updated.toUtf8());
    appendLog("[config] _config.yml saved");
    loadSiteConfig();
}

void AppContext::loadThemeConfig()
{
    QString file = activeThemeConfigFile();
    QFile f(file);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        appendLog(QString("[theme] failed to open: %1").arg(file));
        return;
    }
    m_configMap = parseSimpleYaml(QString::fromUtf8(f.readAll()));
    m_configMap["__scope"] = "theme";
    m_configMap["__file"] = file;
    emit configMapChanged();
}

void AppContext::saveThemeConfig(const QVariantMap &map)
{
    QString file = map.value("__file").toString();
    if (file.isEmpty()) {
        file = activeThemeConfigFile();
    }

    QVariantMap clean = map;
    clean.remove("__scope");
    clean.remove("__file");

    QFile f(file);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        appendLog(QString("[theme] failed to write: %1").arg(file));
        return;
    }

    f.write(dumpSimpleYaml(clean).toUtf8());
    appendLog(QString("[theme] config saved: %1").arg(file));
    loadThemeConfig();
}

void AppContext::gitStatus() { runCommand("git status"); }
void AppContext::gitAddAll() { runCommand("git add ."); }
void AppContext::gitCommit(const QString &message)
{
    QString msg = message;
    if (msg.trimmed().isEmpty()) {
        appendLog("[git] commit message is empty");
        return;
    }
    msg.replace('"', '\'');
    runCommand(QString("git commit -m \"%1\"").arg(msg));
}
void AppContext::gitPush() { runCommand("git push"); }

void AppContext::rebuildSearchIndex()
{
    if (!rebuildSqliteIndex()) {
        QVariantList index;
        for (const QVariant &p : m_posts) {
            QVariantMap item = p.toMap();
            QFile f(item.value("path").toString());
            QString body;
            if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
                body = QString::fromUtf8(f.readAll());
            }
            item["_searchBlob"] = (item.value("title").toString() + "\n"
                                    + item.value("category").toString() + "\n"
                                    + item.value("tags").toString() + "\n"
                                    + body)
                                   .toLower();
            index.push_back(item);
        }
        m_searchResults = index;
        emit searchResultsChanged();
        return;
    }

    m_searchResults = querySearchFromDb(QString());
    emit searchResultsChanged();
}

void AppContext::search(const QString &query)
{
    const QString q = query.toLower().trimmed();

    const QVariantList sqlResults = querySearchFromDb(q);
    if (!sqlResults.isEmpty() || q.isEmpty()) {
        m_searchResults = sqlResults;
        emit searchResultsChanged();
        return;
    }

    QVariantList out;
    for (const QVariant &v : m_searchResults) {
        const QVariantMap item = v.toMap();
        if (item.value("_searchBlob").toString().contains(q)) {
            out.push_back(item);
        }
    }
    m_searchResults = out;
    emit searchResultsChanged();
}

void AppContext::loadPlugins()
{
    m_plugins.clear();
    if (m_currentProjectPath.isEmpty()) {
        emit pluginsChanged();
        return;
    }

    QDir pluginDir(QDir(m_currentProjectPath).filePath("plugins"));
    if (!pluginDir.exists()) {
        emit pluginsChanged();
        return;
    }

    QStringList files = pluginDir.entryList(QStringList() << "*.json", QDir::Files);
    for (const QString &file : files) {
        QFile f(pluginDir.filePath(file));
        if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
            continue;
        }
        QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
        if (!doc.isObject()) {
            continue;
        }
        QJsonObject o = doc.object();
        QVariantMap m;
        m["name"] = o.value("name").toString(file);
        m["description"] = o.value("description").toString();
        m["command"] = o.value("command").toString();
        m["onLoad"] = o.value("onLoad").toString();
        m["onUnload"] = o.value("onUnload").toString();
        m["state"] = "unloaded";
        m_plugins.push_back(m);
    }
    emit pluginsChanged();
}

void AppContext::runPlugin(const QString &pluginName)
{
    for (int i = 0; i < m_plugins.size(); ++i) {
        QVariantMap p = m_plugins[i].toMap();
        if (p.value("name").toString() == pluginName) {
            if (p.value("state").toString() != "loaded") {
                const QString onLoad = p.value("onLoad").toString();
                if (!onLoad.isEmpty()) {
                    runCommand(onLoad);
                }
                p["state"] = "loaded";
                m_plugins[i] = p;
                emit pluginsChanged();
            }
            QString cmd = p.value("command").toString();
            if (!cmd.isEmpty()) {
                runCommand(cmd);
            }
            return;
        }
    }
}

void AppContext::unloadPlugin(const QString &pluginName)
{
    for (int i = 0; i < m_plugins.size(); ++i) {
        QVariantMap p = m_plugins[i].toMap();
        if (p.value("name").toString() == pluginName) {
            const QString onUnload = p.value("onUnload").toString();
            if (!onUnload.isEmpty()) {
                runCommand(onUnload);
            }
            p["state"] = "unloaded";
            m_plugins[i] = p;
            emit pluginsChanged();
            return;
        }
    }
}

QString AppContext::importImageToCurrentProject(const QString &sourceFilePath, const QString &altText)
{
    if (m_currentProjectPath.isEmpty()) {
        appendStructuredLog("warn", "IMAGE_NO_PROJECT", "cannot import image without selected project");
        return {};
    }

    const QString source = QDir::fromNativeSeparators(sourceFilePath.trimmed());
    if (source.isEmpty() || !QFileInfo::exists(source)) {
        appendStructuredLog("warn", "IMAGE_NOT_FOUND", QString("image not found: %1").arg(source));
        return {};
    }

    QDir imagesDir(QDir(m_currentProjectPath).filePath("source/images"));
    if (!imagesDir.exists()) {
        QDir().mkpath(imagesDir.path());
    }

    const QFileInfo srcInfo(source);
    const QString stampedName = QDateTime::currentDateTime().toString("yyyyMMdd-HHmmss-") + srcInfo.fileName();
    const QString targetPath = imagesDir.filePath(stampedName);
    if (!QFile::copy(source, targetPath)) {
        appendStructuredLog("error", "IMAGE_COPY_FAIL", QString("copy failed: %1 -> %2").arg(source, targetPath));
        return {};
    }

    const QString alt = altText.trimmed().isEmpty() ? srcInfo.completeBaseName() : altText.trimmed();
    const QString md = QString("![%1](/images/%2)").arg(alt, stampedName);
    appendStructuredLog("info", "IMAGE_IMPORTED", QString("imported image: %1").arg(stampedName));
    return md;
}

QString AppContext::importCoverToCurrentProject(const QString &sourceFilePathOrUrl)
{
    QString source = sourceFilePathOrUrl.trimmed();
    if (source.isEmpty()) {
        return {};
    }

    QUrl url(source);
    if (url.isValid() && url.isLocalFile()) {
        source = url.toLocalFile();
    }

    const QString md = importImageToCurrentProject(source, QStringLiteral("cover"));
    if (md.isEmpty()) {
        return {};
    }

    const int left = md.indexOf('(');
    const int right = md.lastIndexOf(')');
    if (left >= 0 && right > left) {
        return md.mid(left + 1, right - left - 1).trimmed();
    }
    return {};
}

QVariantMap AppContext::diagnosticsReport() const
{
    QVariantMap report = environmentCheck();
    report["appDataRoot"] = appDataRoot();
    report["currentProjectPath"] = m_currentProjectPath;
    report["projectCount"] = m_projects.size();
    report["postCount"] = m_posts.size();
    report["pluginCount"] = m_plugins.size();
    report["searchDbPath"] = searchDbPath();
    report["searchDbExists"] = QFileInfo::exists(searchDbPath());
    report["watchFileCount"] = m_watcher.files().size();
    report["watchDirectoryCount"] = m_watcher.directories().size();
    report["firstRun"] = m_firstRun;
    report["webEditorSupported"] = true;
    return report;
}

bool AppContext::isFirstRun() const
{
    return m_firstRun;
}

void AppContext::completeFirstRun()
{
    QFile f(firstRunFlagPath());
    if (f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        f.write("initialized\n");
    }
    if (m_firstRun) {
        m_firstRun = false;
        emit firstRunChanged();
    }
}

void AppContext::appendStructuredLog(const QString &level, const QString &code, const QString &message)
{
    appendLog(QString("[%1][%2] %3").arg(level.toUpper(), code, message));
}

QVariantMap AppContext::environmentCheck() const
{
    QVariantMap out;
    auto exists = [](const QString &bin) {
#ifdef Q_OS_WIN
        int code = QProcess::execute("cmd.exe", QStringList() << "/C" << "where" << bin);
#else
        int code = QProcess::execute("/bin/sh", QStringList() << "-lc" << ("command -v " + bin));
#endif
        return code == 0;
    };

    out["node"] = exists("node");
    out["hexo"] = exists("hexo");
    out["git"] = exists("git");
    out["project"] = !m_currentProjectPath.isEmpty() && isHexoProject(m_currentProjectPath);
    return out;
}

QString AppContext::suggestTitle(const QString &content) const
{
    QString c = content.trimmed();
    if (c.isEmpty()) {
        return "Hexo New Post";
    }

    QString firstLine = c.section('\n', 0, 0).trimmed();
    firstLine.remove(QRegularExpression("^[#\\-*\\s]+"));
    if (firstLine.length() > 42) {
        firstLine = firstLine.left(42);
    }
    if (firstLine.isEmpty()) {
        return "Hexo Insight " + QDate::currentDate().toString("yyyyMMdd");
    }
    return firstLine;
}

QString AppContext::generateDescriptionText(const QString &title,
                                            const QString &body)
{
    return generateDescriptionWithGlm(title, body);
}

QString AppContext::resolveCoverForPreview(const QString &cover,
                                           const QString &postPath) const
{
    const QString raw = cover.trimmed();
    if (raw.isEmpty()) {
        return {};
    }

    const QUrl direct(raw);
    if (direct.isValid() && !direct.scheme().isEmpty()) {
        return direct.toString();
    }

    if (m_currentProjectPath.isEmpty()) {
        return raw;
    }

    if (raw.startsWith('/')) {
        const QString local = QDir(m_currentProjectPath).filePath("source" + raw);
        return QUrl::fromLocalFile(QDir::cleanPath(local)).toString();
    }

    if (raw.startsWith("images/")) {
        const QString local = QDir(m_currentProjectPath).filePath("source/" + raw);
        return QUrl::fromLocalFile(QDir::cleanPath(local)).toString();
    }

    QFileInfo postInfo(postPath);
    const QString baseDir = postInfo.absolutePath().isEmpty()
        ? postsDirectory()
        : postInfo.absolutePath();
    const QString local = QDir(baseDir).filePath(raw);
    return QUrl::fromLocalFile(QDir::cleanPath(local)).toString();
}

QString AppContext::appDataRoot() const
{
    QString base = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    QDir().mkpath(base);
    return base;
}

QString AppContext::projectsFilePath() const
{
    return QDir(appDataRoot()).filePath("projects.json");
}

QString AppContext::aiConfigPath() const
{
    return QDir(appDataRoot()).filePath("ai_config.json");
}

QString AppContext::sessionStateFile() const
{
    return QDir(appDataRoot()).filePath("session_state.json");
}

QString AppContext::firstRunFlagPath() const
{
    return QDir(appDataRoot()).filePath("first_run.flag");
}

QString AppContext::searchDbPath() const
{
    return QDir(appDataRoot()).filePath("search_index.sqlite");
}

void AppContext::loadProjectsFromDisk()
{
    QFile f(projectsFilePath());
    if (!f.exists() || !f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return;
    }

    QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
    if (!doc.isArray()) {
        return;
    }

    m_projects.clear();
    for (const QJsonValue &v : doc.array()) {
        QJsonObject o = v.toObject();
        QString path = o.value("path").toString();
        if (isHexoProject(path)) {
            QVariantMap m;
            m["name"] = o.value("name").toString(QFileInfo(path).fileName());
            m["path"] = path;
            m_projects.push_back(m);
        }
    }
    emit projectsChanged();

    if (!m_projects.isEmpty()) {
        switchProject(m_projects.first().toMap().value("path").toString());
    }
}

void AppContext::saveProjectsToDisk() const
{
    QJsonArray arr;
    for (const QVariant &v : m_projects) {
        QVariantMap m = v.toMap();
        QJsonObject o;
        o.insert("name", m.value("name").toString());
        o.insert("path", m.value("path").toString());
        arr.push_back(o);
    }

    QFile f(projectsFilePath());
    if (f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        f.write(QJsonDocument(arr).toJson(QJsonDocument::Indented));
    }
}

void AppContext::saveLastOpenedPostState() const
{
    if (m_currentProjectPath.trimmed().isEmpty()) {
        return;
    }

    QJsonObject root;
    QFile in(sessionStateFile());
    if (in.exists() && in.open(QIODevice::ReadOnly | QIODevice::Text)) {
        const QJsonDocument doc = QJsonDocument::fromJson(in.readAll());
        if (doc.isObject()) {
            root = doc.object();
        }
    }

    QJsonObject byProject = root.value("lastOpenedByProject").toObject();
    if (m_opened.path.trimmed().isEmpty()) {
        byProject.remove(m_currentProjectPath);
    } else {
        byProject.insert(m_currentProjectPath, m_opened.path);
    }

    root.insert("lastProjectPath", m_currentProjectPath);
    root.insert("lastOpenedByProject", byProject);

    QFile out(sessionStateFile());
    if (out.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        out.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
    }
}

QString AppContext::restoreLastOpenedPostPath() const
{
    QFile f(sessionStateFile());
    if (!f.exists() || !f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return {};
    }

    const QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
    if (!doc.isObject()) {
        return {};
    }

    const QJsonObject root = doc.object();
    const QJsonObject byProject = root.value("lastOpenedByProject").toObject();
    const QString candidate = byProject.value(m_currentProjectPath).toString();
    if (!candidate.isEmpty() && QFileInfo::exists(candidate)) {
        return candidate;
    }
    return {};
}

void AppContext::appendLog(const QString &line)
{
    const QString cleaned = sanitizeConsoleChunk(line);
    if (cleaned.isEmpty()) {
        return;
    }
    if (!m_logText.isEmpty() && !m_logText.endsWith('\n')) {
        m_logText += '\n';
    }
    m_logText += cleaned;
    if (!m_logText.endsWith('\n')) {
        m_logText += '\n';
    }
    if (m_logText.size() > 200000) {
        m_logText = m_logText.right(200000);
    }
    emit logTextChanged();
}

void AppContext::resetPreviewOpenState(const QString &commandLine)
{
    static const QRegularExpression hexoServerRe(R"(\bhexo\s+server\b)", QRegularExpression::CaseInsensitiveOption);
    if (hexoServerRe.match(commandLine).hasMatch()) {
        m_pendingPreviewOpen = true;
        m_previewOpened = false;
        m_lastPreviewUrl.clear();
        return;
    }

    m_pendingPreviewOpen = false;
    m_previewOpened = false;
}

void AppContext::handlePreviewOutput(const QString &text)
{
    if (!m_pendingPreviewOpen || m_previewOpened) {
        return;
    }

    const QString cleaned = sanitizeConsoleChunk(text);
    static const QRegularExpression urlRe(R"(https?://[^\s]+)");
    const QRegularExpressionMatch match = urlRe.match(cleaned);
    if (!match.hasMatch()) {
        return;
    }

    QString url = match.captured(0).trimmed();
    while (url.endsWith('.') || url.endsWith(',') || url.endsWith(')')) {
        url.chop(1);
    }

    if (url.isEmpty()) {
        return;
    }

    m_lastPreviewUrl = url;
    m_previewOpened = true;
    m_pendingPreviewOpen = false;
    QDesktopServices::openUrl(QUrl(url));
    appendStructuredLog("info", "PREVIEW_OPEN", QString("opened preview %1").arg(url));
}

void AppContext::runCommand(const QString &commandLine, bool silentIfBusy)
{
    if (m_currentProjectPath.isEmpty()) {
        appendLog("[task] no selected project");
        return;
    }
    if (m_taskRunning || m_command->isRunning()) {
        if (silentIfBusy) {
            return;
        }
        appendLog("[task] another task is running, stopping it first");
        m_command->stop();
        m_taskRunning = false;
        emit taskRunningChanged();
    }
    m_command->startShellCommand(m_currentProjectPath, commandLine);
}

void AppContext::setupWatcher()
{
    if (!m_watcher.files().isEmpty())
        m_watcher.removePaths(m_watcher.files());
    if (!m_watcher.directories().isEmpty())
        m_watcher.removePaths(m_watcher.directories());

    if (m_currentProjectPath.isEmpty()) {
        return;
    }

    QString postDir = postsDirectory();
    QString cfg = configFile();
    QString themesDir = QDir(m_currentProjectPath).filePath("themes");

    if (QFileInfo(postDir).exists()) {
        m_watcher.addPath(postDir);
    }
    if (QFileInfo(cfg).exists()) {
        m_watcher.addPath(cfg);
    }
    if (QFileInfo(themesDir).exists()) {
        m_watcher.addPath(themesDir);
    }
}

QString AppContext::postsDirectory() const
{
    return QDir(m_currentProjectPath).filePath("source/_posts");
}

QString AppContext::configFile() const
{
    return QDir(m_currentProjectPath).filePath("_config.yml");
}

QString AppContext::activeThemeConfigFile() const
{
    QString theme = m_configMap.value("theme").toString();
    if (theme.isEmpty()) {
        theme = "landscape";
    }
    return QDir(m_currentProjectPath).filePath("themes/" + theme + "/_config.yml");
}

AppContext::PostData AppContext::readMarkdown(const QString &filePath)
{
    PostData p;
    p.path = filePath;

    QFile f(filePath);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return p;
    }

    QString text = QString::fromUtf8(f.readAll());
    QTextStream stream(&text);

    bool inFrontMatter = false;
    bool frontStarted = false;
    QStringList bodyLines;

    while (!stream.atEnd()) {
        QString line = stream.readLine();
        if (!frontStarted && line.trimmed() == "---") {
            inFrontMatter = true;
            frontStarted = true;
            continue;
        }
        if (inFrontMatter && line.trimmed() == "---") {
            inFrontMatter = false;
            continue;
        }

        if (inFrontMatter) {
            int idx = line.indexOf(':');
            if (idx > 0) {
                QString k = line.left(idx).trimmed();
                QString v = line.mid(idx + 1).trimmed();
                if (k == "title") p.title = v;
                else if (k == "date") p.date = v;
                else if (k == "categories") p.category = v;
                else if (k == "tags") p.tags = v;
                else if (k == "cover") p.cover = v;
                else if (k == "description") p.description = v;
            }
        } else {
            bodyLines.push_back(line);
        }
    }

    int leadingBlankLines = 0;
    while (leadingBlankLines < bodyLines.size() && bodyLines[leadingBlankLines].trimmed().isEmpty()) {
        ++leadingBlankLines;
    }
    p.leadingBlankLines = leadingBlankLines;
    p.body = (leadingBlankLines < bodyLines.size())
        ? bodyLines.mid(leadingBlankLines).join("\n")
        : QString();
    if (p.title.isEmpty()) {
        p.title = QFileInfo(filePath).completeBaseName();
    }
    if (p.date.isEmpty()) {
        p.date = QFileInfo(filePath).lastModified().date().toString("yyyy-MM-dd");
    }

    return p;
}

bool AppContext::writeMarkdown(const PostData &post)
{
    QDir().mkpath(QFileInfo(post.path).absolutePath());

    QFile f(post.path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        return false;
    }

    QString out;
    out += "---\n";
    out += "title: " + post.title + "\n";
    out += "date: " + post.date + "\n";
    out += "categories: " + post.category + "\n";
    out += "tags: " + post.tags + "\n";
    out += "cover: " + post.cover + "\n";
    out += "description: " + post.description + "\n";
    out += "---\n\n";
    if (post.leadingBlankLines > 0) {
        out += QString(post.leadingBlankLines, QLatin1Char('\n'));
    }
    out += post.body;
    if (!out.endsWith('\n')) {
        out += '\n';
    }

    f.write(out.toUtf8());
    return true;
}

QString AppContext::slugify(const QString &title)
{
    QString s = title.toLower();
    s.replace(QRegularExpression("[^a-z0-9\\u4e00-\\u9fa5]+"), "-");
    s.replace(QRegularExpression("-+"), "-");
    s = s.trimmed();
    if (s.startsWith('-')) s.remove(0, 1);
    if (s.endsWith('-')) s.chop(1);
    if (s.isEmpty()) {
        s = "post";
    }
    return s;
}

QVariantMap AppContext::parseSimpleYaml(const QString &content)
{
    QVariantMap map;
    QStringList lines = content.split('\n');
    for (const QString &line : lines) {
        QString t = line.trimmed();
        if (t.isEmpty() || t.startsWith('#')) {
            continue;
        }
        int idx = line.indexOf(':');
        if (idx <= 0) {
            continue;
        }
        QString key = line.left(idx).trimmed();
        QString value = line.mid(idx + 1).trimmed();
        map[key] = value;
    }
    return map;
}

QString AppContext::dumpSimpleYaml(const QVariantMap &map)
{
    QStringList lines;
    QStringList keys = map.keys();
    keys.sort();
    for (const QString &k : keys) {
        lines << QString("%1: %2").arg(k, map.value(k).toString());
    }
    return lines.join("\n") + "\n";
}

QVariantList AppContext::querySearchFromDb(const QString &query) const
{
    QVariantList out;
    const QString dbFile = searchDbPath();
    if (!QFileInfo::exists(dbFile)) {
        return out;
    }

    const QString connName = QStringLiteral("search_read_conn");
    {
        QSqlDatabase db = QSqlDatabase::addDatabase("QSQLITE", connName);
        db.setDatabaseName(dbFile);
        if (!db.open()) {
            QSqlDatabase::removeDatabase(connName);
            return out;
        }

        QSqlQuery q(db);
        if (query.isEmpty()) {
            q.prepare("SELECT path, title, category, tags, body FROM posts ORDER BY rowid DESC");
        } else {
            q.prepare("SELECT path, title, category, tags, body FROM posts WHERE lower(title || '\\n' || category || '\\n' || tags || '\\n' || body) LIKE ? ORDER BY rowid DESC");
            q.addBindValue(QString("%%1%").arg(query));
        }

        if (q.exec()) {
            while (q.next()) {
                QVariantMap item;
                item["path"] = q.value(0).toString();
                item["title"] = q.value(1).toString();
                item["category"] = q.value(2).toString();
                item["tags"] = q.value(3).toString();
                item["_searchBlob"] = (q.value(1).toString() + "\n"
                                       + q.value(2).toString() + "\n"
                                       + q.value(3).toString() + "\n"
                                       + q.value(4).toString()).toLower();
                out.push_back(item);
            }
        }
        db.close();
    }
    QSqlDatabase::removeDatabase(connName);
    return out;
}

bool AppContext::rebuildSqliteIndex()
{
    const QString connName = QStringLiteral("search_write_conn");
    {
        QSqlDatabase db = QSqlDatabase::addDatabase("QSQLITE", connName);
        db.setDatabaseName(searchDbPath());
        if (!db.open()) {
            appendStructuredLog("warn", "SQLITE_OPEN_FAIL", db.lastError().text());
            QSqlDatabase::removeDatabase(connName);
            return false;
        }

        QSqlQuery q(db);
        if (!q.exec("CREATE TABLE IF NOT EXISTS posts(path TEXT PRIMARY KEY, title TEXT, category TEXT, tags TEXT, body TEXT)")) {
            appendStructuredLog("warn", "SQLITE_SCHEMA_FAIL", q.lastError().text());
            db.close();
            QSqlDatabase::removeDatabase(connName);
            return false;
        }
        q.exec("DELETE FROM posts");

        QSqlQuery ins(db);
        ins.prepare("INSERT OR REPLACE INTO posts(path, title, category, tags, body) VALUES(?, ?, ?, ?, ?)");
        for (const QVariant &p : m_posts) {
            const QVariantMap item = p.toMap();
            QFile f(item.value("path").toString());
            QString body;
            if (f.open(QIODevice::ReadOnly | QIODevice::Text)) {
                body = QString::fromUtf8(f.readAll());
            }
            ins.addBindValue(item.value("path").toString());
            ins.addBindValue(item.value("title").toString());
            ins.addBindValue(item.value("category").toString());
            ins.addBindValue(item.value("tags").toString());
            ins.addBindValue(body);
            if (!ins.exec()) {
                appendStructuredLog("warn", "SQLITE_INSERT_FAIL", ins.lastError().text());
            }
        }
        db.close();
    }
    QSqlDatabase::removeDatabase(connName);
    return true;
}

void AppContext::setOpenedPost(const PostData &post)
{
    m_opened = post;
    emit openedPostPathChanged();
    emit openedPostChanged();
    saveLastOpenedPostState();
}

void AppContext::clearOpenedPost()
{
    m_opened = PostData();
    emit openedPostPathChanged();
    emit openedPostChanged();
    saveLastOpenedPostState();
}

void AppContext::reloadAllProjectBoundData()
{
    setupWatcher();
    scanPosts();
    loadSiteConfig();
    loadPlugins();
    rebuildSearchIndex();

    const QString lastOpenedPath = restoreLastOpenedPostPath();
    if (!lastOpenedPath.isEmpty()) {
        openPost(lastOpenedPath);
    } else if (!m_posts.isEmpty()) {
        openPost(m_posts.first().toMap().value("path").toString());
    } else {
        clearOpenedPost();
    }

    if (m_autoGenerateEnabled) {
        m_debounceGenerate.start();
    }
}

void AppContext::loadAiConfig()
{
    QFile f(aiConfigPath());
    if (!f.exists() || !f.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return;
    }

    QJsonDocument doc = QJsonDocument::fromJson(f.readAll());
    if (!doc.isObject()) {
        return;
    }

    QJsonObject o = doc.object();
    m_aiProvider = o.value("provider").toString("none");
    m_aiApiBase = o.value("apiBase").toString();
    m_aiModel = o.value("model").toString();
}

void AppContext::saveAiConfig() const
{
    QJsonObject o;
    o.insert("provider", m_aiProvider);
    o.insert("apiBase", m_aiApiBase);
    o.insert("model", m_aiModel);

    QFile f(aiConfigPath());
    if (f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        f.write(QJsonDocument(o).toJson(QJsonDocument::Indented));
    }
}

QString AppContext::resolveAiApiKey() const
{
    QString key = qEnvironmentVariable("GLM_API_KEY");
    if (key.trimmed().isEmpty()) {
        key = qEnvironmentVariable("ZHIPUAI_API_KEY");
    }
    if (key.trimmed().isEmpty()) {
        key = qEnvironmentVariable("OPENAI_API_KEY");
    }

    if (!key.trimmed().isEmpty()) {
        return key.trimmed();
    }

    const QStringList keys = {
        QStringLiteral("GLM_API_KEY"),
        QStringLiteral("ZHIPUAI_API_KEY"),
        QStringLiteral("OPENAI_API_KEY")
    };
    const QStringList candidates = {
        QDir::current().filePath(".env"),
        QDir(QCoreApplication::applicationDirPath()).filePath(".env"),
        QDir(QCoreApplication::applicationDirPath()).filePath("../.env")
    };
    for (const QString &envFile : candidates) {
        for (const QString &k : keys) {
            key = readDotEnvValue(envFile, k);
            if (!key.trimmed().isEmpty()) {
                return key.trimmed();
            }
        }
    }
    return key.trimmed();
}

QString AppContext::generateDescriptionWithGlm(const QString &title, const QString &body)
{
    const QString apiKey = resolveAiApiKey();
    if (apiKey.isEmpty()) {
        appendStructuredLog("warn", "AI_KEY_MISSING", "missing GLM API key, skip description generation");
        return {};
    }

    QString promptBody = body.trimmed();
    if (promptBody.size() > 1800) {
        promptBody = promptBody.left(1800);
    }

    QJsonObject payload;
    payload.insert("model", m_aiModel.trimmed().isEmpty() ? "glm-4.7-flash" : m_aiModel.trimmed());
    payload.insert("temperature", 0.3);

    QJsonArray messages;
    QJsonObject systemMsg;
    systemMsg.insert("role", "system");
    systemMsg.insert("content", "你是博客编辑助手。请生成一段简洁自然的中文文章描述，不超过80字，不要使用引号，不要分点。仅返回描述文本。");
    messages.append(systemMsg);

    QJsonObject userMsg;
    userMsg.insert("role", "user");
    userMsg.insert("content", QString("标题：%1\n正文：\n%2").arg(title, promptBody));
    messages.append(userMsg);
    payload.insert("messages", messages);

    QString apiBase = m_aiApiBase.trimmed();
    if (apiBase.isEmpty()) {
        apiBase = "https://open.bigmodel.cn/api/paas/v4/chat/completions";
    }

    QNetworkRequest request{QUrl(apiBase)};
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    request.setRawHeader("Authorization", QString("Bearer %1").arg(apiKey).toUtf8());

    QNetworkReply *reply = m_network->post(request, QJsonDocument(payload).toJson(QJsonDocument::Compact));
    QEventLoop loop;
    connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    loop.exec();

    const QByteArray respBytes = reply->readAll();
    const QNetworkReply::NetworkError err = reply->error();
    reply->deleteLater();

    if (err != QNetworkReply::NoError) {
        appendStructuredLog("warn", "AI_REQUEST_FAIL", QString::fromUtf8(respBytes));
        return {};
    }

    const QJsonDocument respDoc = QJsonDocument::fromJson(respBytes);
    if (!respDoc.isObject()) {
        appendStructuredLog("warn", "AI_RESPONSE_INVALID", "invalid JSON response from AI service");
        return {};
    }

    const QJsonArray choices = respDoc.object().value("choices").toArray();
    if (choices.isEmpty() || !choices.first().isObject()) {
        return {};
    }

    const QJsonObject msgObj = choices.first().toObject().value("message").toObject();
    QString content = msgObj.value("content").toString().trimmed();
    content.remove('\n');
    if (content.size() > 120) {
        content = content.left(120).trimmed();
    }
    return content;
}
