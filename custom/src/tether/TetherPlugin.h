#pragma once

#include "QGCCorePlugin.h"
#include <QtCore/QLoggingCategory>
#include <QtCore/QPointer>

Q_DECLARE_LOGGING_CATEGORY(TetherPluginLog)

class TetherOptions;
class SafeTManager;

/// Root Core Plugin implementation for IZI Tethered Drone Ground Control Station.
/// Completely decoupled from Chandipur-specific CompanyDataOutput / DRDO broadcasting.
class TetherPlugin : public QGCCorePlugin
{
    Q_OBJECT

public:
    explicit TetherPlugin(QObject *parent = nullptr);
    ~TetherPlugin() override;

    static QGCCorePlugin *instance();

    // QGCCorePlugin overrides
    QGCOptions *options() override;
    void paletteOverride(const QString &colorName, QGCPalette::PaletteColorInfo_t &colorInfo) override;
    void createRootWindow(QQmlApplicationEngine *qmlEngine) override;

private:
    TetherOptions *_options = nullptr;
    SafeTManager  *_safeTManager = nullptr;
};
