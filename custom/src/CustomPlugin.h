#pragma once

#include <QtCore/QLoggingCategory>
#include "QGCCorePlugin.h"

class CustomOptions;
class QQmlApplicationEngine;

Q_DECLARE_LOGGING_CATEGORY(CustomPluginLog)

class CustomPlugin : public QGCCorePlugin
{
    Q_OBJECT

public:
    explicit CustomPlugin(QObject *parent = nullptr);
    ~CustomPlugin() override;

    static QGCCorePlugin *instance();

    // Overrides from QGCCorePlugin
    QGCOptions *options() override;
    void paletteOverride(const QString &colorName, QGCPalette::PaletteColorInfo_t &colorInfo) override;
    void createRootWindow(QQmlApplicationEngine *qmlEngine) override;

private:
    CustomOptions *_options = nullptr;
};
