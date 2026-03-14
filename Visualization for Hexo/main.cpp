#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QWindow>
#include <QAbstractNativeEventFilter>
#include <QIcon>

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

    bool nativeEventFilter(const QByteArray &eventType, void *message, qintptr *result) override {
        Q_UNUSED(eventType);
        MSG *msg = static_cast<MSG *>(message);
        if (msg->hwnd && msg->hwnd == hwnd) {
            if (msg->message == WM_NCCALCSIZE && msg->wParam == TRUE) {
                NCCALCSIZE_PARAMS *params = reinterpret_cast<NCCALCSIZE_PARAMS *>(msg->lParam);
                
                // 不调用 DefWindowProc，直接修改当前的新窗口矩形（原本的 rgrc[0] 就是新窗口矩形）
                // 默认将等于整个窗口的尺寸
                if (IsZoomed(msg->hwnd)) {
                    HMONITOR hMonitor = MonitorFromWindow(msg->hwnd, MONITOR_DEFAULTTONEAREST);
                    if (hMonitor) {
                        MONITORINFO mi;
                        mi.cbSize = sizeof(MONITORINFO);
                        GetMonitorInfo(hMonitor, &mi);
                        params->rgrc[0] = mi.rcWork;
                    }
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
                    applyRoundedCorners(false);
                } else if (msg->wParam == SIZE_RESTORED) {
                    applyRoundedCorners(true);
                }
            }
        }
        return false;
    }
};
#endif


#include "src/core/AppContext.h"
#include "src/core/EditorBridge.h"

int main(int argc, char *argv[])
{
#if defined(Q_OS_WIN) && QT_VERSION_CHECK(5, 6, 0) <= QT_VERSION && QT_VERSION < QT_VERSION_CHECK(6, 0, 0)
    QCoreApplication::setAttribute(Qt::AA_EnableHighDpiScaling);
#endif

    qputenv("QT_QUICK_CONTROLS_STYLE", "Basic");

    QGuiApplication app(argc, argv);
    app.setWindowIcon(QIcon(QStringLiteral(":/qt/qml/visualization for hexo/assets/app-icon.png")));

    QQmlApplicationEngine engine;
    AppContext appContext;
    EditorBridge editorBridge;

    QObject::connect(&editorBridge, &EditorBridge::saveRequested, &appContext, [&appContext]() {
        appContext.appendStructuredLog("info", "EDITOR_BRIDGE", "save requested from web editor");
    });

    engine.rootContext()->setContextProperty("appContext", &appContext);
    engine.rootContext()->setContextProperty("editorBridge", &editorBridge);
    engine.load(QUrl(QStringLiteral("qrc:/qt/qml/visualization for hexo/main.qml")));
    if (engine.rootObjects().isEmpty())
        return -1;

#ifdef Q_OS_WIN
    QWindow *window = qobject_cast<QWindow *>(engine.rootObjects().constFirst());
    if (window) {
        HWND hwnd = reinterpret_cast<HWND>(window->winId());

        // 扩展 DWM 边界，保留原生阴影并且骗过系统这是正常窗口
        MARGINS margins = {1, 1, 1, 1};
        DwmExtendFrameIntoClientArea(hwnd, &margins);

        WinFramelessFilter *filter = new WinFramelessFilter();
        filter->hwnd = hwnd;
        qApp->installNativeEventFilter(filter);

        SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
                     SWP_NOZORDER | SWP_NOOWNERZORDER | SWP_NOMOVE | SWP_NOSIZE | SWP_FRAMECHANGED);

        filter->applyRoundedCorners(true);
        window->setProperty("visible", true);
    }
#endif

    return app.exec();
}
