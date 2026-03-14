#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QWindow>
#include <QAbstractNativeEventFilter>
#include <QIcon>
#include <QCoreApplication>
#include <QDir>
#include <QFile>
#include <QTextStream>
#include <QQmlError>
#include <QQuickWindow>
#include <QColor>

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
                // 顶部标题栏高度（用于拖动），52px 为我们在 QML 中定义的高度，按 DPI 缩放
                int titleHeight = 52 * dpi / 96;

                bool isLeft = (x >= winrect.left && x < winrect.left + frameX);
                bool isRight = (x < winrect.right && x >= winrect.right - frameX);
                bool isTop = (y >= winrect.top && y < winrect.top + frameY);
                bool isBottom = (y < winrect.bottom && y >= winrect.bottom - frameY);

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
                int leftExclude = 280 * dpi / 96;
                int rightExclude = 430 * dpi / 96;
                int centerExcludeHalf = 90 * dpi / 96;
                int centerX = (winrect.left + winrect.right) / 2;
                bool inCenterControl = (x >= centerX - centerExcludeHalf && x <= centerX + centerExcludeHalf);
                if (y >= winrect.top + frameY && y < winrect.top + titleHeight) {
                    if (!inCenterControl
                        && x >= winrect.left + leftExclude
                        && x < winrect.right - rightExclude) {
                        *result = HTCAPTION;
                        return true;
                    }
                }
                
                return false;
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

int main(int argc, char *argv[])
{
#if defined(Q_OS_WIN) && QT_VERSION_CHECK(5, 6, 0) <= QT_VERSION && QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
#endif

    qputenv("QT_QUICK_CONTROLS_STYLE", "Basic");
    qputenv("QSG_RENDER_LOOP", "threaded");
    qputenv("QSG_RHI_BACKEND", "direct3d11");

    QGuiApplication app(argc, argv);
    app.setWindowIcon(QIcon(QStringLiteral(":/qt/qml/visualization for hexo/assets/app-icon.png")));

    QQmlApplicationEngine engine;
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

        WinFramelessFilter *filter = new WinFramelessFilter();
        filter->hwnd = hwnd;
        const QSize minSize = window->minimumSize();
        filter->minWidth = minSize.width() > 0 ? minSize.width() : 1100;
        filter->minHeight = minSize.height() > 0 ? minSize.height() : 700;
        qApp->installNativeEventFilter(filter);

        filter->applyRoundedCorners(true);
        SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
                     SWP_NOZORDER | SWP_NOOWNERZORDER | SWP_NOMOVE | SWP_NOSIZE | SWP_FRAMECHANGED);

        window->setProperty("visible", true);
    }
#endif

    return app.exec();
}
