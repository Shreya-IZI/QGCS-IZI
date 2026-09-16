#include "CustomPlugin.h"
#include "CustomOptions.h"
#include "QGCLoggingCategory.h"
#include "QGCPalette.h"

#include <QtCore/QApplicationStatic>
#include <QtQml/QQmlApplicationEngine>

QGC_LOGGING_CATEGORY(CustomPluginLog, "Company.CustomPlugin")

Q_APPLICATION_STATIC(CustomPlugin, _customPluginInstance);

QGCCorePlugin *CustomPlugin::instance()
{
    return _customPluginInstance();
}

CustomPlugin::CustomPlugin(QObject *parent)
    : QGCCorePlugin(parent)
    , _options(new CustomOptions(this, this))
{
    qCDebug(CustomPluginLog) << "Company CustomPlugin instantiated";
}

CustomPlugin::~CustomPlugin()
{
    qCDebug(CustomPluginLog) << "Company CustomPlugin destroyed";
}

QGCOptions *CustomPlugin::options()
{
    return _options;
}

void CustomPlugin::paletteOverride(const QString &colorName, QGCPalette::PaletteColorInfo_t &colorInfo)
{
    // Professional Dark Ground Control Station Palette Overrides
    if (colorName == QStringLiteral("window")) {
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#0B0E14");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#0B0E14");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#F4F6F9");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#F4F6F9");
    } else if (colorName == QStringLiteral("windowShade")) {
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#151922");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#151922");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#E9ECEF");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#E9ECEF");
    } else if (colorName == QStringLiteral("windowShadeDark")) {
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#07090D");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#07090D");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#DEE2E6");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#DEE2E6");
    } else if (colorName == QStringLiteral("text")) {
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#F0F6FC");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#6E7681");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#1F2328");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#8C959F");
    } else if (colorName == QStringLiteral("button")) {
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#1F2430");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#151922");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#E1E4E8");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#F1F3F5");
    } else if (colorName == QStringLiteral("buttonBorder")) {
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#30363D");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#21262D");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#D0D7DE");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#E1E4E8");
    } else if (colorName == QStringLiteral("buttonHighlight")) {
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#1F6FEB");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#388BFD33");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#0969DA");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#0969DA33");
    } else if (colorName == QStringLiteral("primaryButton")) {
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#238636");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#23863633");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#1A7F37");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#1A7F3733");
    } else if (colorName == QStringLiteral("primaryButtonText")) {
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled]   = QColor("#FFFFFF");
        colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupDisabled]  = QColor("#8B949E");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled]  = QColor("#FFFFFF");
        colorInfo[QGCPalette::Light][QGCPalette::ColorGroupDisabled] = QColor("#8C959F");
    }
}

void CustomPlugin::createRootWindow(QQmlApplicationEngine *qmlEngine)
{
    qCDebug(CustomPluginLog) << "Loading Company GCS Main Window QML";
    qmlEngine->load(QUrl(QStringLiteral("qrc:/qml/Company/UI/MainWindow.qml")));
}
