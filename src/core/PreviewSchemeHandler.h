#ifndef PREVIEWSCHEMEHANDLER_H
#define PREVIEWSCHEMEHANDLER_H

#include <QWebEngineUrlSchemeHandler>
#include <QWebEngineUrlRequestJob>
#include <QMimeDatabase>
#include <QBuffer>
#include <QFile>
#include <QUrl>

class PreviewSchemeHandler : public QWebEngineUrlSchemeHandler {
    Q_OBJECT
public:
    explicit PreviewSchemeHandler(QObject *parent = nullptr) : QWebEngineUrlSchemeHandler(parent) {}

    void requestStarted(QWebEngineUrlRequestJob *job) override {
        const QUrl url = job->requestUrl();
        QString path = url.path(); // leading '/...'
        if (path.startsWith('/')) path.remove(0, 1);
        if (path.isEmpty()) path = "index.html";
        const QString qrcPath = QStringLiteral(":/preview/%1").arg(path);

        QFile f(qrcPath);
        if (!f.open(QIODevice::ReadOnly)) {
            job->fail(QWebEngineUrlRequestJob::UrlNotFound);
            return;
        }

        const QByteArray data = f.readAll();
        QMimeDatabase db;
        const QString mime = db.mimeTypeForFile(qrcPath).name();

        QBuffer *buf = new QBuffer(job);
        buf->setData(data);
        buf->open(QIODevice::ReadOnly);
        job->reply(mime.toUtf8(), buf);
    }
};

#endif // PREVIEWSCHEMEHANDLER_H
