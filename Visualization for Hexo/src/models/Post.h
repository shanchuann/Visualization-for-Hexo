#pragma once

#include <QVariantMap>
#include <QString>

struct Post
{
    QString path;
    QString title;
    QString date;
    QString categories;
    QString tags;
    QString body;
    int views = 0;

    QVariantMap toVariantMap() const
    {
        QVariantMap m;
        m.insert("path", path);
        m.insert("title", title);
        m.insert("date", date);
        m.insert("category", categories);
        m.insert("tags", tags);
        m.insert("body", body);
        m.insert("views", views);
        return m;
    }
};
