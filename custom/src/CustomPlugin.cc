#include "CustomPlugin.h"
#include "CompanyCsvLogger.h"
#include "CompanyDataOutput.h"
#include "CompanyFlightLogManager.h"
#include "CompanyNetworkSettings.h"
#include "CompanyPayloadInterface.h"
#include "CustomOptions.h"
#include "QGCLoggingCategory.h"
#include "QGCMapEngineManager.h"
#include "QGCPalette.h"
#include "SettingsManager.h"
#include "SimulatedPayloadAdapter.h"
#include "VideoSettings.h"

#include <QtCore/QApplicationStatic>
#include <QtCore/QCoreApplication>
#include <QtGui/QGuiApplication>
#include <QtGui/QIcon>
#include <QtQml/QQmlApplicationEngine>
#include <QtQml/QQmlContext>
#include <QtQuick/QQuickWindow>

QGC_LOGGING_CATEGORY(CustomPluginLog, "Company.CustomPlugin")

Q_APPLICATION_STATIC(CustomPlugin, _customPluginInstance);

QGCCorePlugin *CustomPlugin::instance()
{
    return _customPluginInstance();
}

CustomPlugin::CustomPlugin(QObject *parent)
    : QGCCorePlugin(parent)
    , _options(new CustomOptions(this, this))
    , _payloadAdapter(new SimulatedPayloadAdapter(this))
{
    CompanyPayloadInterface::setInstance(_payloadAdapter);
    qCDebug(CustomPluginLog) << "Company CustomPlugin instantiated with SimulatedPayloadAdapter";
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
    (void) qmlRegisterUncreatableType<QGCMapEngineManager>("QGroundControl.QGCMapEngineManager", 1, 0, "QGCMapEngineManager", "Reference only");
    (void) QGCMapEngineManager::instance();
    qmlRegisterSingletonInstance("Company.UI", 1, 0, "CompanyCsvLogger", CompanyCsvLogger::instance());
    qmlRegisterSingletonInstance("Company.UI", 1, 0, "CompanyFlightLogManager", CompanyFlightLogManager::instance());
    qmlRegisterSingletonInstance("Company.UI", 1, 0, "CompanyNetworkSettings", CompanyNetworkSettings::instance());
    qmlRegisterSingletonInstance("Company.UI", 1, 0, "CompanyDataOutput", CompanyDataOutput::instance());
    qmlRegisterSingletonInstance("Company.UI", 1, 0, "CompanyPayloadInterface", CompanyPayloadInterface::instance());
    qmlEngine->rootContext()->setContextProperty(QStringLiteral("companyCsvLogger"), CompanyCsvLogger::instance());
    qmlEngine->rootContext()->setContextProperty(QStringLiteral("companyFlightLogManager"), CompanyFlightLogManager::instance());
    qmlEngine->rootContext()->setContextProperty(QStringLiteral("companyNetworkSettings"), CompanyNetworkSettings::instance());
    qmlEngine->rootContext()->setContextProperty(QStringLiteral("companyDataOutput"), CompanyDataOutput::instance());
    qmlEngine->rootContext()->setContextProperty(QStringLiteral("companyPayload"), CompanyPayloadInterface::instance());

    // Ensure video stream source is initialized and configured if currently disabled
    VideoSettings *videoSettings = SettingsManager::instance()->videoSettings();
    if (videoSettings) {
        Fact *videoSourceFact = videoSettings->videoSource();
        if (videoSourceFact) {
            const QString currentSource = videoSourceFact->rawValue().toString();
            if (currentSource.isEmpty() || currentSource == QStringLiteral("videoDisabled") || currentSource == VideoSettings::videoDisabled) {
                videoSourceFact->setRawValue(QStringLiteral("RTSP Video Stream"));
            }
        }
        Fact *streamEnabledFact = videoSettings->streamEnabled();
        if (streamEnabledFact && !streamEnabledFact->rawValue().toBool()) {
            streamEnabledFact->setRawValue(true);
        }
    }

    QGuiApplication::setApplicationDisplayName(QStringLiteral("IZI GCS"));
    qmlEngine->load(QUrl(QStringLiteral("qrc:/qml/Company/UI/MainWindow.qml")));

    QIcon appIcon;
    appIcon.addFile(QStringLiteral(":/res/icons/izi_icon.png"));
    appIcon.addFile(QStringLiteral(":/res/icons/izi_icon.svg"));
    appIcon.addFile(QStringLiteral(":/res/qgroundcontrol.png"));
    appIcon.addFile(QStringLiteral(":/res/qgroundcontrol.ico"));
    appIcon.addFile(QStringLiteral(":/res/izi_icon.svg"));
    if (!appIcon.isNull()) {
        QGuiApplication::setWindowIcon(appIcon);
    }

    const auto rootObjects = qmlEngine->rootObjects();
    for (QObject *obj : rootObjects) {
        auto *window = qobject_cast<QQuickWindow*>(obj);
        if (window) {
            if (!appIcon.isNull()) {
                window->setIcon(appIcon);
            }
            // Register root window as context property so all nested loaders and views can access mainWindow
            qmlEngine->rootContext()->setContextProperty(QStringLiteral("mainWindow"), window);

            // Connect QML engine quit and last window closed signals to guarantee the application event
            // loop terminates properly across all platforms (preventing background zombie instances on Windows).
            (void) QObject::connect(qmlEngine, &QQmlEngine::quit, qGuiApp, [window]() {
                if (window) {
                    window->setProperty("_forceClose", true);
                }
                QCoreApplication::quit();
            });

            (void) QObject::connect(qGuiApp, &QGuiApplication::lastWindowClosed, qGuiApp, [window]() {
                if (window) {
                    window->setProperty("_forceClose", true);
                }
                QCoreApplication::quit();
            });

            (void) QObject::connect(window, &QQuickWindow::closing, qGuiApp, [window]() {
                if (window->property("_forceClose").toBool()) {
                    QCoreApplication::quit();
                }
            });
        }
    }
}
