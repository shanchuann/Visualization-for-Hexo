#pragma once

#include <QObject>
#include <QFileSystemWatcher>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>

class QNetworkAccessManager;

class CommandAdapter;

class AppContext : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString currentProjectPath READ currentProjectPath NOTIFY currentProjectPathChanged)
    Q_PROPERTY(bool taskRunning READ taskRunning NOTIFY taskRunningChanged)
    Q_PROPERTY(QString logText READ logText NOTIFY logTextChanged)
    Q_PROPERTY(QVariantList projects READ projects NOTIFY projectsChanged)
    Q_PROPERTY(QVariantList posts READ posts NOTIFY postsChanged)
    Q_PROPERTY(QVariantList searchResults READ searchResults NOTIFY searchResultsChanged)
    Q_PROPERTY(QVariantMap configMap READ configMap NOTIFY configMapChanged)
    Q_PROPERTY(QVariantList plugins READ plugins NOTIFY pluginsChanged)
    Q_PROPERTY(QStringList allCategories READ allCategories NOTIFY postsChanged)
    Q_PROPERTY(QStringList allTags READ allTags NOTIFY postsChanged)
    Q_PROPERTY(int postSortMode READ postSortMode WRITE setPostSortMode NOTIFY postSortModeChanged)
    Q_PROPERTY(bool autoGenerateEnabled READ autoGenerateEnabled WRITE setAutoGenerateEnabled NOTIFY autoGenerateEnabledChanged)
    Q_PROPERTY(QString openedPostPath READ openedPostPath NOTIFY openedPostPathChanged)
    Q_PROPERTY(QString openedPostTitle READ openedPostTitle NOTIFY openedPostChanged)
    Q_PROPERTY(QString openedPostCategory READ openedPostCategory NOTIFY openedPostChanged)
    Q_PROPERTY(QString openedPostTags READ openedPostTags NOTIFY openedPostChanged)
    Q_PROPERTY(QString openedPostDate READ openedPostDate NOTIFY openedPostChanged)
    Q_PROPERTY(QString openedPostCover READ openedPostCover NOTIFY openedPostChanged)
    Q_PROPERTY(QString openedPostDescription READ openedPostDescription NOTIFY openedPostChanged)
    Q_PROPERTY(QString openedPostBody READ openedPostBody NOTIFY openedPostChanged)
    Q_PROPERTY(bool firstRun READ isFirstRun NOTIFY firstRunChanged)
    Q_PROPERTY(QString aiProvider READ aiProvider WRITE setAiProvider NOTIFY aiProviderChanged)
    Q_PROPERTY(QString aiApiBase READ aiApiBase WRITE setAiApiBase NOTIFY aiApiBaseChanged)
    Q_PROPERTY(QString aiModel READ aiModel WRITE setAiModel NOTIFY aiModelChanged)

public:
    explicit AppContext(QObject *parent = nullptr);

    QString currentProjectPath() const;
    bool taskRunning() const;
    QString logText() const;
    QVariantList projects() const;
    QVariantList posts() const;
    QVariantList searchResults() const;
    QVariantMap configMap() const;
    QVariantList plugins() const;
    QStringList allCategories() const;
    QStringList allTags() const;
    int postSortMode() const;
    bool autoGenerateEnabled() const;

    QString openedPostPath() const;
    QString openedPostTitle() const;
    QString openedPostCategory() const;
    QString openedPostTags() const;
    QString openedPostDate() const;
    QString openedPostCover() const;
    QString openedPostDescription() const;
    QString openedPostBody() const;

    QString aiProvider() const;
    QString aiApiBase() const;
    QString aiModel() const;

    void setAutoGenerateEnabled(bool enabled);
    void setPostSortMode(int mode);
    void setAiProvider(const QString &provider);
    void setAiApiBase(const QString &apiBase);
    void setAiModel(const QString &model);

    Q_INVOKABLE void addProject(const QString &path);
    Q_INVOKABLE void switchProject(const QString &path);
    Q_INVOKABLE void removeProject(const QString &path);
    Q_INVOKABLE bool isHexoProject(const QString &path) const;
    Q_INVOKABLE bool initializeHexoProject(const QString &path);

    Q_INVOKABLE void runHexoGenerate();
    Q_INVOKABLE void runHexoDeploy();
    Q_INVOKABLE void runHexoClean();
    Q_INVOKABLE void runHexoServer();
    Q_INVOKABLE void stopCurrentTask();
    Q_INVOKABLE void submitConsoleInput(const QString &text);

    Q_INVOKABLE void scanPosts();
    Q_INVOKABLE void openPost(const QString &filePath);
    Q_INVOKABLE void saveOpenedPost(const QString &title,
                                    const QString &category,
                                    const QString &tags,
                                    const QString &date,
                                    const QString &cover,
                                    const QString &description,
                                    const QString &body);
    Q_INVOKABLE void newPost(const QString &title, const QString &category, const QString &tags);
    Q_INVOKABLE void deletePost(const QString &filePath);

    Q_INVOKABLE void loadSiteConfig();
    Q_INVOKABLE void saveSiteConfig(const QVariantMap &map);
    Q_INVOKABLE void loadThemeConfig();
    Q_INVOKABLE void saveThemeConfig(const QVariantMap &map);

    Q_INVOKABLE void gitStatus();
    Q_INVOKABLE void gitAddAll();
    Q_INVOKABLE void gitCommit(const QString &message);
    Q_INVOKABLE void gitPush();

    Q_INVOKABLE void rebuildSearchIndex();
    Q_INVOKABLE void search(const QString &query);

    Q_INVOKABLE void loadPlugins();
    Q_INVOKABLE void runPlugin(const QString &pluginName);
    Q_INVOKABLE void unloadPlugin(const QString &pluginName);

    Q_INVOKABLE QString importImageToCurrentProject(const QString &sourceFilePath,
                                                    const QString &altText = QString());
    Q_INVOKABLE QString importCoverToCurrentProject(const QString &sourceFilePathOrUrl);
    Q_INVOKABLE QVariantMap diagnosticsReport() const;
    Q_INVOKABLE bool isFirstRun() const;
    Q_INVOKABLE void completeFirstRun();
    Q_INVOKABLE void appendStructuredLog(const QString &level,
                                         const QString &code,
                                         const QString &message);

    Q_INVOKABLE QVariantMap environmentCheck() const;
    Q_INVOKABLE QString suggestTitle(const QString &content) const;
    Q_INVOKABLE QString generateDescriptionText(const QString &title,
                                                const QString &body);
    Q_INVOKABLE QString resolveCoverForPreview(const QString &cover,
                                               const QString &postPath) const;
    Q_INVOKABLE QString renderMarkdownForPreview(const QString &markdown,
                                                 int bodyFontPx = 20,
                                                 qreal lineSpacing = 1.9) const;
    Q_INVOKABLE void applyAiSettings(const QString &provider,
                                     const QString &apiBase,
                                     const QString &model);

signals:
    void currentProjectPathChanged();
    void taskRunningChanged();
    void logTextChanged();
    void projectsChanged();
    void postsChanged();
    void searchResultsChanged();
    void configMapChanged();
    void pluginsChanged();
    void postSortModeChanged();
    void autoGenerateEnabledChanged();
    void openedPostPathChanged();
    void openedPostChanged();
    void firstRunChanged();
    void aiProviderChanged();
    void aiApiBaseChanged();
    void aiModelChanged();

private:
    struct PostData {
        QString path;
        QString title;
        QString category;
        QString tags;
        QString date;
        QString cover;
        QString description;
        QString body;
        int leadingBlankLines = 0;
    };

    QString appDataRoot() const;
    QString projectsFilePath() const;
    QString aiConfigPath() const;
    QString sessionStateFile() const;
    QString firstRunFlagPath() const;
    QString searchDbPath() const;
    void loadProjectsFromDisk();
    void saveProjectsToDisk() const;
    void saveLastOpenedPostState() const;
    QString restoreLastOpenedPostPath() const;
    void appendLog(const QString &line);

    void runCommand(const QString &commandLine, bool silentIfBusy = false);
    void setupWatcher();
    QString postsDirectory() const;
    QString configFile() const;
    QString activeThemeConfigFile() const;

    static PostData readMarkdown(const QString &filePath);
    static bool writeMarkdown(const PostData &post);
    static QString slugify(const QString &title);
    static QVariantMap parseSimpleYaml(const QString &content);
    static QString dumpSimpleYaml(const QVariantMap &map);

    QVariantList querySearchFromDb(const QString &query) const;
    bool rebuildSqliteIndex();

    void setOpenedPost(const PostData &post);
    void clearOpenedPost();
    void reloadAllProjectBoundData();
    void loadAiConfig();
    void saveAiConfig() const;
    QString generateDescriptionWithGlm(const QString &title, const QString &body);
    QString resolveAiApiKey() const;

private:
    CommandAdapter *m_command;
    QNetworkAccessManager *m_network;
    QFileSystemWatcher m_watcher;
    QTimer m_debounceGenerate;

    QString m_currentProjectPath;
    bool m_taskRunning = false;
    QString m_logText;
    QVariantList m_projects;
    QVariantList m_posts;
    QVariantList m_searchResults;
    QVariantMap m_configMap;
    QVariantList m_plugins;
    bool m_autoGenerateEnabled = true;
    int m_postSortMode = 0; // 0: time desc, 1: time asc, 2: title asc, 3: title desc

    PostData m_opened;

    QString m_aiProvider = "none";
    QString m_aiApiBase;
    QString m_aiModel;
    bool m_firstRun = true;
};
