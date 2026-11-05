#include "SafeTManager.h"
#include "QGCLoggingCategory.h"

#include <cmath>
#include <QtCore/QApplicationStatic>
#include <QtCore/QDateTime>

QGC_LOGGING_CATEGORY(SafeTManagerLog, "Company.Tether.SafeT")

Q_APPLICATION_STATIC(SafeTManager, _safeTManagerInstance);

SafeTManager *SafeTManager::instance()
{
    return _safeTManagerInstance();
}

SafeTManager::SafeTManager(QObject *parent)
    : QObject(parent)
{
    connect(&_simTimer, &QTimer::timeout, this, &SafeTManager::_onSimulationTick);
    connect(&_watchdogTimer, &QTimer::timeout, this, &SafeTManager::_onWatchdogCheck);

    _watchdogTimer.setInterval(1000); // 1 Hz staleness check
    _watchdogTimer.start();

    // Default to active simulation baseline for early UI/tether testing
    startSimulation();
    qCDebug(SafeTManagerLog) << "SafeTManager instantiated (Simulation mode ready)";
}

void SafeTManager::connectLink(const QString &hostOrPort, int port)
{
    qCDebug(SafeTManagerLog) << "connectLink requested for:" << hostOrPort << port << "(Awaiting physical SAFE-T ICD)";
    _connectionStatus = QStringLiteral("CONNECTING");
    emit connectionChanged();
}

void SafeTManager::disconnectLink()
{
    _isConnected = false;
    _connectionStatus = QStringLiteral("DISCONNECTED");
    emit connectionChanged();
}

void SafeTManager::startSimulation()
{
    _simTimer.setInterval(100); // 10 Hz telemetry update rate
    _simTimer.start();
    _isConnected = true;
    _isStale = false;
    _connectionStatus = QStringLiteral("CONNECTED (SIM)");
    _linkTransport = QStringLiteral("LOOPBACK SIMULATOR");
    emit connectionChanged();
    emit staleChanged();
    emit linkTransportChanged();
}

void SafeTManager::stopSimulation()
{
    _simTimer.stop();
    _isConnected = false;
    _connectionStatus = QStringLiteral("STANDBY");
    emit connectionChanged();
}

void SafeTManager::_onSimulationTick()
{
    _simPhase += 0.05f;
    _lastPacketMs = QDateTime::currentMSecsSinceEpoch();

    // Plausible tether simulation data
    // Tension varies around 45 N with subtle gust dynamics (+/- 12 N)
    _tensionN = 45.0f + 12.0f * std::sin(_simPhase) + 4.0f * std::sin(_simPhase * 2.3f);
    
    // Deployed length gently settling around 102.5 metres
    _tetherLengthM = 102.0f + 0.8f * std::sin(_simPhase * 0.4f);

    // Tether station high-voltage bus (e.g. 380V HVDC generator output)
    _stationVoltageV = 398.5f + 1.2f * std::sin(_simPhase * 0.2f);
    _stationCurrentA = 7.8f + 1.5f * std::sin(_simPhase * 0.8f);

    // Tether winch drum temperature
    _drumTempC = 34.2f + 1.1f * std::sin(_simPhase * 0.05f);

    // Motion state
    _winchStatus = (std::abs(std::sin(_simPhase)) > 0.85f) ? QStringLiteral("PAYING OUT") : QStringLiteral("TENSION HOLD");

    // Dynamic high tension alarm threshold (e.g. > 75 N during excessive gust)
    const bool prevAlarm = _highTensionAlarm;
    _highTensionAlarm = (_tensionN > 75.0f);
    if (prevAlarm != _highTensionAlarm) {
        emit alarmsChanged();
    }

    if (_isStale) {
        _isStale = false;
        emit staleChanged();
    }

    emit telemetryUpdated();
}

void SafeTManager::_onWatchdogCheck()
{
    if (!_isConnected) {
        return;
    }

    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    if (_lastPacketMs > 0 && (now - _lastPacketMs > 1500)) {
        if (!_isStale) {
            _isStale = true;
            qCWarning(SafeTManagerLog) << "SAFE-T Tether Telemetry STALE (No packets for > 1.5s)";
            emit staleChanged();
        }
    }
}
