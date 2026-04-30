#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QWindow>
#include <QAbstractNativeEventFilter>
#include <QIcon>
#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QLibraryInfo>
#include <QTextStream>
#include <QMutex>
#include <QMutexLocker>
#include <QDateTime>
#include <QQmlError>
#include <QQuickWindow>
#include <QColor>
#include <QScreen>
// WebEngine custom scheme support
#include <QWebEngineUrlScheme>
#include <QWebEngineProfile>
#include <QWebEngineUrlRequestJob>
#include <QWebEngineUrlSchemeHandler>
#include <QMimeDatabase>
#include <QBuffer>

#ifdef Q_OS_WIN
#include <Windows.h>
#include <windowsx.h>
#include <dwmapi.h>
#pragma comment(lib, "dwmapi.lib")
#pragma comment(lib, "user32.lib")

#ifndef DWMWA_WINDOW_CORNER_PREFERENCE
#define DWMWA_WINDOW_CORNER_PREFERENCE 33
#endif

#ifndef DWMWCP_DEFAULT
#define DWMWCP_DEFAULT 0
#define DWMWCP_DONOTROUND 1
#define DWMWCP_ROUND 2
#define DWMWCP_ROUNDSMALL 3
#endif

class WinFramelessFilter : public QAbstractNativeEventFilter {
public:
    HWND hwnd = nullptr;
    bool roundedEnabled = true;
    int minWidth = 0;
    int minHeight = 0;

    void applyRoundedCorners(bool enable) {
        if (!hwnd) {
            return;
        }

        const int preference = enable ? DWMWCP_ROUND : DWMWCP_DONOTROUND;
        DwmSetWindowAttribute(hwnd,
                              DWMWA_WINDOW_CORNER_PREFERENCE,
                              &preference,
                              sizeof(preference));
    }

    void updateRoundedCorners(bool enable) {
        if (roundedEnabled == enable) {
            return;
        }
        roundedEnabled = enable;
        applyRoundedCorners(enable);
    }

    bool nativeEventFilter(const QByteArray &eventType, void *message, qintptr *result) override {
        Q_UNUSED(eventType);
        MSG *msg = static_cast<MSG *>(message);
        if (msg->hwnd && msg->hwnd == hwnd) {
            // ---- WM_NCCALCSIZE: suppress native frame drawing ----
            // By returning 0 for WM_NCCALCSIZE, we tell Windows to use the
            // entire window rect as the client area, effectively hiding the
            // native title bar and borders while keeping the window styles
            // that enable Aero Snap, taskbar interactions, etc.
            if (msg->message == WM_NCCALCSIZE) {
                if (msg->wParam == TRUE) {
                    // When maximized, adjust for the auto-hide taskbar and
                    // prevent the window from covering the taskbar.
                    WINDOWPLACEMENT wp = {};
                    wp.length = sizeof(WINDOWPLACEMENT);
                    GetWindowPlacement(hwnd, &wp);
                    if (wp.showCmd == SW_MAXIMIZE) {
                        NCCALCSIZE_PARAMS *params = reinterpret_cast<NCCALCSIZE_PARAMS *>(msg->lParam);
                        HMONITOR hMon = MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST);
                        MONITORINFO mi;
                        mi.cbSize = sizeof(MONITORINFO);
                        if (GetMonitorInfo(hMon, &mi)) {
                            params->rgrc[0] = mi.rcWork;
                        }
                    }
                }
                *result = 0;
                return true;
            }

            if (msg->message == WM_GETMINMAXINFO) {
                MINMAXINFO *mmi = reinterpret_cast<MINMAXINFO *>(msg->lParam);
                HMONITOR hMonitor = MonitorFromWindow(msg->hwnd, MONITOR_DEFAULTTONEAREST);
                if (hMonitor) {
                    MONITORINFO mi;
                    mi.cbSize = sizeof(MONITORINFO);
                    GetMonitorInfo(hMonitor, &mi);
                    RECT work = mi.rcWork;
                    RECT monitor = mi.rcMonitor;
                    mmi->ptMaxPosition.x = work.left - monitor.left;
                    mmi->ptMaxPosition.y = work.top - monitor.top;
                    mmi->ptMaxSize.x = work.right - work.left;
                    mmi->ptMaxSize.y = work.bottom - work.top;
                }
                if (minWidth > 0 && minHeight > 0) {
                    UINT dpi = GetDpiForWindow(msg->hwnd);
                    mmi->ptMinTrackSize.x = MulDiv(minWidth, dpi, 96);
                    mmi->ptMinTrackSize.y = MulDiv(minHeight, dpi, 96);
                }
                *result = 0;
                return true;
            }

            if (msg->message == WM_NCHITTEST) {
                long x = GET_X_LPARAM(msg->lParam);
                long y = GET_Y_LPARAM(msg->lParam);

                RECT winrect;
                GetWindowRect(msg->hwnd, &winrect);

                UINT dpi = GetDpiForWindow(msg->hwnd);
                int frameX = GetSystemMetricsForDpi(SM_CXSIZEFRAME, dpi) + GetSystemMetricsForDpi(SM_CXPADDEDBORDER, dpi);
                int frameY = GetSystemMetricsForDpi(SM_CYSIZEFRAME, dpi) + GetSystemMetricsForDpi(SM_CXPADDEDBORDER, dpi);
                // Expand draggable sensing height so dragging feels smoother.
                int titleHeight = 64 * dpi / 96;

                // When maximized, don't allow edge-resize
                bool maximized = IsZoomed(hwnd);

                bool isLeft   = !maximized && (x >= winrect.left && x < winrect.left + frameX);
                bool isRight  = !maximized && (x < winrect.right && x >= winrect.right - frameX);
                bool isTop    = !maximized && (y >= winrect.top && y < winrect.top + frameY);
                bool isBottom = !maximized && (y < winrect.bottom && y >= winrect.bottom - frameY);

                if (isTop && isLeft) {
                    *result = HTTOPLEFT;
                    return true;
                } else if (isTop && isRight) {
                    *result = HTTOPRIGHT;
                    return true;
                } else if (isBottom && isLeft) {
                    *result = HTBOTTOMLEFT;
                    return true;
                } else if (isBottom && isRight) {
                    *result = HTBOTTOMRIGHT;
                    return true;
                } else if (isLeft) {
                    *result = HTLEFT;
                    return true;
                } else if (isRight) {
                    *result = HTRIGHT;
                    return true;
                } else if (isTop) {
                    *result = HTTOP;
                    return true;
                } else if (isBottom) {
                    *result = HTBOTTOM;
                    return true;
                }

                // 中间区域可拖拽，但要避开左侧三色按钮、右侧操作按钮，以及顶部中央源码/预览切换。
                int leftExclude = 220 * dpi / 96;
                int rightExclude = 320 * dpi / 96;
                int centerExcludeHalf = 100 * dpi / 96;
                int centerX = (winrect.left + winrect.right) / 2;
                bool inCenterControl = (x >= centerX - centerExcludeHalf && x <= centerX + centerExcludeHalf);
                if (y >= winrect.top + (maximized ? 0 : frameY) && y < winrect.top + titleHeight) {
                    // Explicitly keep left/right control zones as client area so
                    // QML MouseArea (traffic lights and right-side toolbar icons)
                    // always receives click events.
                    if (inCenterControl
                        || x < winrect.left + leftExclude
                        || x >= winrect.right - rightExclude) {
                        *result = HTCLIENT;
                        return true;
                    }
                    if (!inCenterControl
                        && x >= winrect.left + leftExclude
                        && x < winrect.right - rightExclude) {
                        *result = HTCAPTION;
                        return true;
                    }
                }

                return false;
            }

            // ---- WM_ACTIVATE: redraw frame on activation to avoid visual glitch ----
            if (msg->message == WM_ACTIVATE) {
                MARGINS m = {0, 0, 0, 1};
                DwmExtendFrameIntoClientArea(hwnd, &m);
                *result = 0;
                // Don't return true – let Qt also process the activation
            }

            if (msg->message == WM_SIZE) {
                if (msg->wParam == SIZE_MAXIMIZED) {
                    updateRoundedCorners(false);
                } else if (msg->wParam == SIZE_RESTORED) {
                    updateRoundedCorners(true);
                }
            }
        }
        return false;
    }
};
#endif


#include "src/core/AppContext.h"
#include "src/core/EditorBridge.h"

static void WriteStartupLog(const QStringList &lines)
{
    if (lines.isEmpty()) {
        return;
    }

    const QString logPath = QDir(QCoreApplication::applicationDirPath()).filePath("startup.log");
    QFile file(logPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate | QIODevice::Text)) {
        return;
    }

    QTextStream out(&file);
    for (const auto &line : lines) {
        out << line << "\n";
    }
}

static void ConfigureWebEngineRuntimePaths()
{
    const QString appDir = QCoreApplication::applicationDirPath();
    const QString libexecDir = QLibraryInfo::path(QLibraryInfo::LibraryExecutablesPath);
    const QString dataDir = QLibraryInfo::path(QLibraryInfo::DataPath);
    const QString translationDir = QLibraryInfo::path(QLibraryInfo::TranslationsPath);

    auto setEnvIfMissing = [](const char *name, const QString &path) {
        if (!qEnvironmentVariableIsEmpty(name) || path.isEmpty()) {
            return;
        }
        qputenv(name, QDir::toNativeSeparators(path).toUtf8());
    };

    auto findFirstExistingFile = [](const QStringList &dirs, const QStringList &names) -> QString {
        for (const auto &dirPath : dirs) {
            if (dirPath.isEmpty()) {
                continue;
            }
            for (const auto &name : names) {
                const QString candidate = QDir(dirPath).filePath(name);
                if (QFileInfo::exists(candidate)) {
                    return QDir::cleanPath(candidate);
                }
            }
        }
        return {};
    };

    auto findFirstExistingDirectory = [](const QStringList &dirs) -> QString {
        for (const auto &dirPath : dirs) {
            if (dirPath.isEmpty()) {
                continue;
            }
            if (QDir(dirPath).exists()) {
                return QDir::cleanPath(dirPath);
            }
        }
        return {};
    };

#if defined(QT_DEBUG)
    const QStringList processNames = {
        QStringLiteral("QtWebEngineProcessd.exe"),
        QStringLiteral("QtWebEngineProcess.exe")
    };
#else
    const QStringList processNames = {
        QStringLiteral("QtWebEngineProcess.exe"),
        QStringLiteral("QtWebEngineProcessd.exe")
    };
#endif

    const QString webEngineProcessPath = findFirstExistingFile({
        appDir,
        QDir(appDir).filePath("bin"),
        QDir(appDir).filePath("libexec"),
        libexecDir
    }, processNames);
    setEnvIfMissing("QTWEBENGINEPROCESS_PATH", webEngineProcessPath);

    QString resourcesPath = findFirstExistingDirectory({
        QDir(appDir).filePath("resources"),
        QDir(dataDir).filePath("resources")
    });
    if (!resourcesPath.isEmpty()
        && !QFileInfo::exists(QDir(resourcesPath).filePath("qtwebengine_resources.pak"))) {
        resourcesPath.clear();
    }
    setEnvIfMissing("QTWEBENGINE_RESOURCES_PATH", resourcesPath);

    const QString localesPath = findFirstExistingDirectory({
        resourcesPath.isEmpty() ? QString() : QDir(resourcesPath).filePath("qtwebengine_locales"),
        QDir(appDir).filePath("resources/qtwebengine_locales"),
        QDir(appDir).filePath("translations/qtwebengine_locales"),
        QDir(translationDir).filePath("qtwebengine_locales"),
        QDir(dataDir).filePath("translations/qtwebengine_locales")
    });
    setEnvIfMissing("QTWEBENGINE_LOCALES_PATH", localesPath);
}

// Preview scheme handler moved to header to allow proper moc processing
#include "src/core/PreviewSchemeHandler.h"


int main(int argc, char *argv[])
{
#if QT_VERSION >= QT_VERSION_CHECK(6, 0, 0)
    // Register custom 'app' scheme before WebEngine profiles are created.
    QWebEngineUrlScheme appScheme("app");
    appScheme.setFlags(QWebEngineUrlScheme::SecureScheme
                       | QWebEngineUrlScheme::LocalScheme
                       | QWebEngineUrlScheme::LocalAccessAllowed);
    appScheme.setSyntax(QWebEngineUrlScheme::Syntax::Path);
    QWebEngineUrlScheme::registerScheme(appScheme);
#endif
#if defined(Q_OS_WIN) && QT_VERSION_CHECK(5, 6, 0) <= QT_VERSION && QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
#endif
    QCoreApplication::setAttribute(Qt::AA_ShareOpenGLContexts);

    qputenv("QT_QUICK_CONTROLS_STYLE", "Basic");
    qputenv("QSG_RENDER_LOOP", "threaded");
    qputenv("QSG_RHI_BACKEND", "direct3d11");
    if (qEnvironmentVariableIsEmpty("QTWEBENGINE_CHROMIUM_FLAGS")) {
        // Improve stability on some Windows GPU drivers for embedded WebEngine previews.
        qputenv("QTWEBENGINE_CHROMIUM_FLAGS", "--disable-gpu");
    }

    QGuiApplication app(argc, argv);
    ConfigureWebEngineRuntimePaths();
    // Install a global Qt message handler to capture qDebug/qWarning/qCritical
    static QMutex _logMutex;
    auto qtMsgHandler = [](QtMsgType type, const QMessageLogContext &context, const QString &msg){
        Q_UNUSED(context);
        QMutexLocker locker(&_logMutex);
        const QString logPath = QDir(QCoreApplication::applicationDirPath()).filePath("runtime.log");
        QFile out(logPath);
        if (out.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
            QTextStream ts(&out);
            const QString time = QDateTime::currentDateTime().toString(Qt::ISODateWithMs);
            QString level;
            switch (type) {
            case QtDebugMsg: level = "DEBUG"; break;
            case QtInfoMsg: level = "INFO"; break;
            case QtWarningMsg: level = "WARN"; break;
            case QtCriticalMsg: level = "CRIT"; break;
            case QtFatalMsg: level = "FATAL"; break;
            }
            ts << time << " [" << level << "] " << msg << "\n";
            out.close();
        }
        if (type == QtFatalMsg) {
            abort();
        }
    };
    qInstallMessageHandler(qtMsgHandler);
    app.setWindowIcon(QIcon(QStringLiteral(":/qt/qml/visualization for hexo/assets/app-icon.png")));

    QQmlApplicationEngine engine;
    // Install preview scheme handler so QML WebEngineView can load app://preview/*
    QWebEngineProfile::defaultProfile()->installUrlSchemeHandler("app", new PreviewSchemeHandler(QWebEngineProfile::defaultProfile()));
    AppContext appContext;
    EditorBridge editorBridge;
    QStringList qmlWarnings;

    QObject::connect(&editorBridge, &EditorBridge::saveRequested, &appContext, [&appContext]() {
        appContext.appendStructuredLog("info", "EDITOR_BRIDGE", "save requested from web editor");
    });

    engine.rootContext()->setContextProperty("appContext", &appContext);
    engine.rootContext()->setContextProperty("editorBridge", &editorBridge);
    engine.addImportPath(QCoreApplication::applicationDirPath() + "/qml");
    QObject::connect(&engine, &QQmlEngine::warnings, &engine, [&qmlWarnings](const QList<QQmlError> &warnings) {
        for (const auto &warning : warnings) {
            qmlWarnings << warning.toString();
        }
    });
    engine.load(QUrl(QStringLiteral("qrc:/qt/qml/visualization for hexo/main.qml")));
    if (engine.rootObjects().isEmpty()) {
        WriteStartupLog(qmlWarnings);
#ifdef Q_OS_WIN
        const QString details = qmlWarnings.isEmpty() ? QStringLiteral("Unknown QML load error.") : qmlWarnings.join("\n");
        const QString message = QStringLiteral("Failed to load UI.\n\n") + details +
                                QStringLiteral("\n\nA startup.log file has been written next to the executable.");
        MessageBoxW(nullptr, reinterpret_cast<LPCWSTR>(message.utf16()),
                    L"Visualization for Hexo", MB_OK | MB_ICONERROR);
#endif
        return -1;
    }

#ifdef Q_OS_WIN
    QWindow *window = qobject_cast<QWindow *>(engine.rootObjects().constFirst());
    if (window) {
        if (auto *quickWindow = qobject_cast<QQuickWindow *>(window)) {
            quickWindow->setPersistentSceneGraph(true);
            quickWindow->setColor(QColor(0xFF, 0xFF, 0xFF));
        }

        HWND hwnd = reinterpret_cast<HWND>(window->winId());

        // --- Enable native window styles for proper Windows integration ---
        // Adding WS_THICKFRAME enables Aero Snap (drag-to-edge maximize/tile).
        // WS_MINIMIZEBOX / WS_MAXIMIZEBOX enable taskbar minimize/restore.
        // WS_CAPTION | WS_SYSMENU enable the system menu (right-click taskbar).
        // We keep Qt.FramelessWindowHint in QML so Qt doesn't draw its own
        // decorations, and handle WM_NCCALCSIZE to suppress the native frame.
        LONG_PTR style = GetWindowLongPtr(hwnd, GWL_STYLE);
        style |= WS_THICKFRAME | WS_MINIMIZEBOX | WS_MAXIMIZEBOX | WS_CAPTION | WS_SYSMENU;
        SetWindowLongPtr(hwnd, GWL_STYLE, style);

        // Extend a tiny (1px) frame into the client area so DWM still
        // provides the drop shadow around the frameless window.
        MARGINS shadow = {0, 0, 0, 1};
        DwmExtendFrameIntoClientArea(hwnd, &shadow);

        WinFramelessFilter *filter = new WinFramelessFilter();
        filter->hwnd = hwnd;
        const QSize minSize = window->minimumSize();
        filter->minWidth = minSize.width() > 0 ? minSize.width() : 1100;
        filter->minHeight = minSize.height() > 0 ? minSize.height() : 700;
        qApp->installNativeEventFilter(filter);

        filter->applyRoundedCorners(true);
        // SWP_FRAMECHANGED forces Windows to re-evaluate the frame after our
        // style changes and WM_NCCALCSIZE handler take effect.
        SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
                     SWP_NOZORDER | SWP_NOOWNERZORDER | SWP_NOMOVE | SWP_NOSIZE | SWP_FRAMECHANGED);

        QScreen *screen = window->screen();
        if (!screen) {
            const auto screens = QGuiApplication::screens();
            if (!screens.isEmpty()) {
                screen = screens.constFirst();
            }
        }
        if (screen) {
            const QRect available = screen->availableGeometry();
            const int centeredX = available.x() + (available.width() - window->width()) / 2;
            const int centeredY = available.y() + (available.height() - window->height()) / 2;
            window->setPosition(centeredX, centeredY);
        }

        window->setProperty("visible", true);
    }
#endif

    return app.exec();
}
