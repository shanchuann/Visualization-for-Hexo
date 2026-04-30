#ifndef PREVIEWSCHEMEHANDLER_H
#define PREVIEWSCHEMEHANDLER_H

#include <QWebEngineUrlSchemeHandler>
#include <QWebEngineUrlRequestJob>
#include <QMimeDatabase>
#include <QBuffer>
#include <QFile>
#include <QUrl>
#include <QDebug>

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

        qDebug() << "[PreviewSchemeHandler] requestStarted:" << job->requestUrl().toString() << "->" << qrcPath;

        QFile f(qrcPath);
        if (!f.open(QIODevice::ReadOnly)) {
            qWarning() << "[PreviewSchemeHandler] file not found:" << qrcPath;
            job->fail(QWebEngineUrlRequestJob::UrlNotFound);
            return;
        }

        const QByteArray data = f.readAll();
        QMimeDatabase db;
        const QString mime = db.mimeTypeForFile(qrcPath).name();

        QBuffer *buf = new QBuffer(job);
        buf->setData(data);
        if (!buf->open(QIODevice::ReadOnly)) {
            qWarning() << "[PreviewSchemeHandler] failed to open buffer for" << qrcPath;
            job->fail(QWebEngineUrlRequestJob::RequestFailed);
            delete buf;
            return;
        }

        qDebug() << "[PreviewSchemeHandler] replying mime=" << mime << " size=" << data.size();
        job->reply(mime.toUtf8(), buf);
    }
};

#endif // PREVIEWSCHEMEHANDLER_H
