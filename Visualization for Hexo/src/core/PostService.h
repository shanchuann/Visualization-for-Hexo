#pragma once

#include <QObject>
#include <QVariantList>
#include <QString>

#include "../models/Post.h"

class PostService : public QObject
{
    Q_OBJECT
public:
    explicit PostService(QObject *parent = nullptr);

    Q_INVOKABLE QVariantList scanPosts(const QString &projectPath) const;
    Q_INVOKABLE QVariantMap readPost(const QString &filePath) const;

    static Post readMarkdown(const QString &filePath);
};
