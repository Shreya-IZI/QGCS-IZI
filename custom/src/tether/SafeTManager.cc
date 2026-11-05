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

    // Threshold Alarms:
    // 1. High Tension: > 75 N is Critical, > 62 N is Warning
    const bool prevHighTension = _highTensionAlarm;
    const bool prevPowerCutoff = _powerCutoffAlarm;
    const bool prevLengthLimit = _lengthLimitAlarm;

    _highTensionAlarm = (_tensionN > 70.0f);
    _powerCutoffAlarm = (_stationVoltageV < 320.0f);
    _lengthLimitAlarm = (_tetherLengthM >= 105.0f);

    if (_highTensionAlarm) {
        _alertSeverity = 2;
        _activeAlertMessage = QStringLiteral("CRITICAL: HIGH TETHER LINE TENSION (%1 N)").arg(_tensionN, 0, 'f', 1);
    } else if (_powerCutoffAlarm) {
        _alertSeverity = 2;
        _activeAlertMessage = QStringLiteral("CRITICAL: TETHER POWER VOLTAGE DROP (%1 V)").arg(_stationVoltageV, 0, 'f', 0);
    } else if (_lengthLimitAlarm) {
        _alertSeverity = 1;
        _activeAlertMessage = QStringLiteral("WARNING: TETHER MAX LENGTH REACHED (%1 m)").arg(_tetherLengthM, 0, 'f', 1);
    } else {
        _alertSeverity = 0;
        _activeAlertMessage.clear();
    }

    if (prevHighTension != _highTensionAlarm || prevPowerCutoff != _powerCutoffAlarm || prevLengthLimit != _lengthLimitAlarm) {
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
