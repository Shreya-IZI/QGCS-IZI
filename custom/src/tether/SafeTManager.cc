#include "SafeTManager.h"
#include "SafeTTransport.h"
#include "QGCLoggingCategory.h"
#include "AudioOutput.h"

#include <QtCore/QApplicationStatic>
#include <QtCore/QDateTime>
#include <QtCore/QDir>
#include <QtCore/QStandardPaths>
#include <cmath>

QGC_LOGGING_CATEGORY(SafeTManagerLog, "Company.Tether.SafeT")

Q_APPLICATION_STATIC(SafeTManager, _safeTManagerInstance);

SafeTManager *SafeTManager::instance()
{
    return _safeTManagerInstance();
}

SafeTManager::SafeTManager(QObject *parent)
    : QObject(parent)
{
    connect(&_watchdogTimer, &QTimer::timeout, this, &SafeTManager::_onWatchdogCheck);
    _watchdogTimer.setInterval(1000); // 1 Hz staleness check
    _watchdogTimer.start();

    connect(&_oneSecondTimer, &QTimer::timeout, this, &SafeTManager::_onSecondTimer);
    _oneSecondTimer.setInterval(1000); // 1 Hz periodic ticker for blackbox logging & hover duration
    _oneSecondTimer.start();

    // Default to Mock Transport for bench testing & simulation
    _setupTransport(TransportType::Mock);
    qCDebug(SafeTManagerLog) << "SafeTManager initialized with HAL Mock Transport";
}

SafeTManager::~SafeTManager()
{
    stopLogging();
    if (_transport) {
        _transport->disconnectTransport();
    }
}

void SafeTManager::_setupTransport(TransportType type)
{
    if (_transport) {
        _transport->disconnectTransport();
        _transport.reset();
    }

    _currentType = type;
    switch (type) {
    case TransportType::Ethernet:
        _transport = std::make_unique<SafeTEthernetTransport>(this);
        _linkTransport = QStringLiteral("ETHERNET (UDP)");
        break;
    case TransportType::Serial:
        _transport = std::make_unique<SafeTSerialTransport>(this);
        _linkTransport = QStringLiteral("SERIAL (RS-485)");
        break;
    case TransportType::Mock:
    default:
        _transport = std::make_unique<SafeTMockTransport>(this);
        _linkTransport = QStringLiteral("SIMULATOR");
        break;
    }

    connect(_transport.get(), &SafeTTransport::telemetryPacketReceived,
            this, &SafeTManager::_onTelemetryPacket);
    connect(_transport.get(), &SafeTTransport::connectionStateChanged,
            this, &SafeTManager::_onConnectionStateChanged);
    connect(_transport.get(), &SafeTTransport::transportError,
            this, &SafeTManager::_onTransportError);

    emit linkTransportChanged();

    // If Mock, automatically start simulation
    if (type == TransportType::Mock) {
        _transport->connectTransport(QStringLiteral("SIM"));
    }
}

void SafeTManager::setTransportType(int type)
{
    if (type >= 0 && type <= 2) {
        _setupTransport(static_cast<TransportType>(type));
    }
}

void SafeTManager::connectLink(const QString &hostOrPort, int portOrBaud)
{
    if (!_transport) {
        _setupTransport(_currentType);
    }
    qCDebug(SafeTManagerLog) << "Connecting SafeT link on" << hostOrPort << portOrBaud;
    _transport->connectTransport(hostOrPort, portOrBaud);
}

void SafeTManager::disconnectLink()
{
    if (_transport) {
        _transport->disconnectTransport();
    }
    if (_isLogging) {
        stopLogging();
    }
}

void SafeTManager::startSimulation()
{
    _setupTransport(TransportType::Mock);
}

void SafeTManager::stopSimulation()
{
    if (_currentType == TransportType::Mock && _transport) {
        _transport->disconnectTransport();
    }
}

bool SafeTManager::sendWinchCommand(const QString &commandName)
{
    if (!_transport || !_isConnected) {
        qCWarning(SafeTManagerLog) << "Cannot send winch command" << commandName << ": not connected";
        return false;
    }
    const QByteArray cmdPacket = commandName.toUtf8();
    qCDebug(SafeTManagerLog) << "Dispatching Winch Command via HAL:" << commandName;
    return _transport->sendCommand(cmdPacket);
}

void SafeTManager::setWinchMode(const QString &mode)
{
    _winchStatus = mode;
    sendWinchCommand(QStringLiteral("SET_MODE:%1").arg(mode));
    emit telemetryUpdated();
}

void SafeTManager::autoTension()
{
    setWinchMode(QStringLiteral("AUTO"));
}

void SafeTManager::holdTether()
{
    setWinchMode(QStringLiteral("HOLD"));
}

void SafeTManager::reelIn()
{
    sendWinchCommand(QStringLiteral("CMD:REEL_IN"));
    setWinchMode(QStringLiteral("REEL_IN"));
}

void SafeTManager::reelOut()
{
    sendWinchCommand(QStringLiteral("CMD:REEL_OUT"));
    setWinchMode(QStringLiteral("REEL_OUT"));
}

void SafeTManager::zeroCableLength()
{
    _lengthZeroOffset = _tetherLengthM;
    qCDebug(SafeTManagerLog) << "Tether length zeroed at offset:" << _lengthZeroOffset << "m";
    emit telemetryUpdated();
}

void SafeTManager::setPowerOutput(bool enabled)
{
    if (_powerOutputEnabled != enabled) {
        _powerOutputEnabled = enabled;
        if (enabled) {
            sendWinchCommand(QStringLiteral("CMD:POWER_ON"));
            _speakVoiceAlert(QStringLiteral("Tether high voltage power active"));
        } else {
            sendWinchCommand(QStringLiteral("CMD:POWER_OFF"));
            _speakVoiceAlert(QStringLiteral("Tether high voltage power disabled"));
        }
        emit powerOutputChanged();
    }
}

void SafeTManager::setMotorTorque(float pct)
{
    const float clamped = std::clamp(pct, 0.0f, 100.0f);
    if (!qFuzzyCompare(_motorTorquePct, clamped)) {
        _motorTorquePct = clamped;
        sendWinchCommand(QStringLiteral("SET_TORQUE:%1").arg(clamped, 0, 'f', 1));
        emit motorTorqueChanged();
    }
}

void SafeTManager::emergencyCutoff()
{
    qCCritical(SafeTManagerLog) << "EMERGENCY TETHER POWER CUTOFF INITIATED BY PILOT!";
    _powerOutputEnabled = false;
    _powerCutoffAlarm = true;
    _alertSeverity = 2;
    _activeAlertMessage = QStringLiteral("EMERGENCY POWER CUTOFF ACTIVE");
    sendWinchCommand(QStringLiteral("CMD:EMERGENCY_POWER_CUT"));
    emit powerOutputChanged();
    emit alarmsChanged();
    _speakVoiceAlert(QStringLiteral("Emergency power cutoff active! Prepare to land!"));
}

void SafeTManager::setMaxTetherLength(float maxM)
{
    if (maxM > 5.0f && maxM < 500.0f && !qFuzzyCompare(_maxTetherLength, maxM)) {
        _maxTetherLength = maxM;
        emit limitsChanged();
    }
}

void SafeTManager::setTargetTension(float targetN)
{
    if (targetN > 10.0f && targetN < 200.0f && !qFuzzyCompare(_targetTension, targetN)) {
        _targetTension = targetN;
        sendWinchCommand(QStringLiteral("SET_TARGET_TENSION:%1").arg(targetN));
        emit limitsChanged();
    }
}

void SafeTManager::setHighTensionLimit(float limitN)
{
    if (limitN > 30.0f && limitN < 300.0f && !qFuzzyCompare(_highTensionLimit, limitN)) {
        _highTensionLimit = limitN;
        emit limitsChanged();
    }
}

void SafeTManager::setVoiceAlertsEnabled(bool enabled)
{
    if (_voiceAlertsEnabled != enabled) {
        _voiceAlertsEnabled = enabled;
        emit voiceAlertsChanged();
    }
}

void SafeTManager::testVoiceAlert()
{
    _speakVoiceAlert(QStringLiteral("Tether audio annunciator operational. All systems normal."));
}

void SafeTManager::simulateFault(const QString &faultType)
{
    qCDebug(SafeTManagerLog) << "Simulating tether fault:" << faultType;
    sendWinchCommand(QStringLiteral("SET_FAULT:%1").arg(faultType));
}

void SafeTManager::resetHoverTimer()
{
    _hoverDurationSec = 0;
    emit hoverDurationChanged();
}

QString SafeTManager::hoverDurationStr() const
{
    const int h = _hoverDurationSec / 3600;
    const int m = (_hoverDurationSec % 3600) / 60;
    const int s = _hoverDurationSec % 60;
    return QStringLiteral("%1:%2:%3")
        .arg(h, 2, 10, QLatin1Char('0'))
        .arg(m, 2, 10, QLatin1Char('0'))
        .arg(s, 2, 10, QLatin1Char('0'));
}

void SafeTManager::_speakVoiceAlert(const QString &message)
{
    emit voiceAlertTriggered(message);
    if (!_voiceAlertsEnabled) {
        return;
    }
    if (AudioOutput::instance()) {
        AudioOutput::instance()->say(message);
    }
}

// ============================================================================
// Blackbox Data Logging Implementation
// ============================================================================

void SafeTManager::setAutoLogOnConnect(bool enabled)
{
    if (_autoLogOnConnect != enabled) {
        _autoLogOnConnect = enabled;
        emit loggingChanged();
    }
}

void SafeTManager::startLogging()
{
    if (_isLogging) {
        return;
    }

    QString baseDir = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    if (baseDir.isEmpty() || baseDir == QStringLiteral("/")) {
        baseDir = QDir::homePath();
        if (baseDir.isEmpty() || baseDir == QStringLiteral("/")) {
            baseDir = QDir::tempPath();
        }
    }
    const QString tetherLogDir = baseDir + QStringLiteral("/QGroundControl/TetherLogs");
    QDir().mkpath(tetherLogDir);

    const QString timeStamp = QDateTime::currentDateTimeUtc().toString(QStringLiteral("yyyyMMdd_hhmmss"));
    _currentLogFilePath = QStringLiteral("%1/TetherLog_%2.csv").arg(tetherLogDir, timeStamp);

    _logFile.setFileName(_currentLogFilePath);
    if (!_logFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qCWarning(SafeTManagerLog) << "Failed to open tether log file:" << _currentLogFilePath;
        _currentLogFilePath.clear();
        return;
    }

    _logStream.setDevice(&_logFile);
    // Write CSV Header
    _logStream << "Timestamp_ISO,Elapsed_Sec,Tension_N,TetherLength_M,CableSpeed_mps,"
               << "StationVoltage_V,StationCurrent_A,StationPower_W,StationPower_kW,"
               << "DrumTemp_C,WinchMode,PowerOutput,AlertSeverity,ActiveAlert\n";
    _logStream.flush();

    _isLogging = true;
    _loggedRecordsCount = 0;
    qCDebug(SafeTManagerLog) << "Started Tether Blackbox Log:" << _currentLogFilePath;
    emit loggingChanged();
}

void SafeTManager::stopLogging()
{
    if (!_isLogging) {
        return;
    }

    if (_logFile.isOpen()) {
        _logStream.flush();
        _logFile.close();
    }
    _isLogging = false;
    qCDebug(SafeTManagerLog) << "Stopped Tether Blackbox Log. Records written:" << _loggedRecordsCount;
    emit loggingChanged();
}

void SafeTManager::_writeLogRecord()
{
    if (!_isLogging || !_logFile.isOpen()) {
        return;
    }

    const QString nowIso = QDateTime::currentDateTimeUtc().toString(Qt::ISODateWithMs);
    const float effLength = tetherLengthM();

    _logStream << nowIso << ','
               << _hoverDurationSec << ','
               << QString::number(_tensionN, 'f', 1) << ','
               << QString::number(effLength, 'f', 2) << ','
               << QString::number(_cableSpeedMps, 'f', 2) << ','
               << QString::number(_stationVoltageV, 'f', 1) << ','
               << QString::number(_stationCurrentA, 'f', 2) << ','
               << QString::number(stationPowerW(), 'f', 0) << ','
               << QString::number(stationPowerKW(), 'f', 2) << ','
               << QString::number(_drumTempC, 'f', 1) << ','
               << _winchStatus << ','
               << (_powerOutputEnabled ? "ON" : "OFF") << ','
               << _alertSeverity << ','
               << '"' << _activeAlertMessage << "\"\n";

    _loggedRecordsCount++;
    if (_loggedRecordsCount % 10 == 0) {
        _logStream.flush();
    }
    emit loggingChanged();
}

// ============================================================================
// Telemetry & Periodic Processing
// ============================================================================

void SafeTManager::_onTelemetryPacket(float tensionN, float lengthM, float voltageV,
                                      float currentA, float tempC, const QString &winchStatus)
{
    _tensionN = tensionN;
    _tetherLengthM = lengthM;
    _stationVoltageV = voltageV;
    _stationCurrentA = currentA;
    _drumTempC = tempC;
    _winchStatus = winchStatus;

    // Cable Payout Speed Calculation (dL / dt) with EMA filter
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    if (_lastSpeedCalcMs > 0 && (now - _lastSpeedCalcMs >= 200)) {
        const float dt = static_cast<float>(now - _lastSpeedCalcMs) / 1000.0f;
        const float dL = lengthM - _lastRawLengthM;
        const float instantSpeed = dL / dt;
        _cableSpeedMps = (0.7f * _cableSpeedMps) + (0.3f * instantSpeed);
        _lastRawLengthM = lengthM;
        _lastSpeedCalcMs = now;
    } else if (_lastSpeedCalcMs == 0) {
        _lastRawLengthM = lengthM;
        _lastSpeedCalcMs = now;
    }

    _lastPacketMs = now;

    if (_isStale) {
        _isStale = false;
        emit staleChanged();
    }

    _evaluateAlarms();
    emit telemetryUpdated();
}

void SafeTManager::_onConnectionStateChanged(bool connected, const QString &statusText)
{
    _isConnected = connected;
    _connectionStatus = statusText;
    emit connectionChanged();

    if (_isConnected) {
        if (_autoLogOnConnect && !_isLogging) {
            startLogging();
        }
    } else {
        if (_isLogging) {
            stopLogging();
        }
    }
}

void SafeTManager::_onTransportError(const QString &errorMessage)
{
    qCWarning(SafeTManagerLog) << "Transport Error:" << errorMessage;
    _connectionStatus = QStringLiteral("ERROR: %1").arg(errorMessage);
    emit connectionChanged();
}

void SafeTManager::_evaluateAlarms()
{
    const bool prevHighTension = _highTensionAlarm;
    const bool prevPowerCutoff = _powerCutoffAlarm;
    const bool prevLengthLimit = _lengthLimitAlarm;
    const bool prevSlack = _slackAlarm;

    const float effectiveLength = tetherLengthM();

    // Dynamic operational limit checks
    _highTensionAlarm = (_tensionN > _highTensionLimit);
    _powerCutoffAlarm = (_stationVoltageV < 320.0f && _stationVoltageV > 10.0f);
    _lengthLimitAlarm = (effectiveLength >= (_maxTetherLength - 2.0f));
    _slackAlarm = (_tensionN < 15.0f && effectiveLength > 3.0f);

    if (_highTensionAlarm) {
        _alertSeverity = 2; // Critical
        _activeAlertMessage = QStringLiteral("CRITICAL: HIGH TETHER TENSION (%1 N)").arg(_tensionN, 0, 'f', 1);
    } else if (_powerCutoffAlarm) {
        _alertSeverity = 2; // Critical
        _activeAlertMessage = QStringLiteral("CRITICAL: TETHER VOLTAGE DROP (%1 V)").arg(_stationVoltageV, 0, 'f', 0);
    } else if (_lengthLimitAlarm) {
        _alertSeverity = 1; // Warning
        _activeAlertMessage = QStringLiteral("WARNING: MAX TETHER LENGTH REACHED (%1 m)").arg(effectiveLength, 0, 'f', 1);
    } else if (_slackAlarm) {
        _alertSeverity = 1; // Warning
        _activeAlertMessage = QStringLiteral("WARNING: TETHER SLACK DETECTED (%1 N)").arg(_tensionN, 0, 'f', 1);
    } else if (_drumTempC > 65.0f) {
        _alertSeverity = 1;
        _activeAlertMessage = QStringLiteral("WARNING: DRUM TEMPERATURE HIGH (%1 °C)").arg(_drumTempC, 0, 'f', 1);
    } else {
        _alertSeverity = 0;
        _activeAlertMessage.clear();
    }

    if (prevHighTension != _highTensionAlarm || prevPowerCutoff != _powerCutoffAlarm ||
        prevLengthLimit != _lengthLimitAlarm || prevSlack != _slackAlarm) {
        emit alarmsChanged();

        // Rate-limit voice alerts to at most once per 6 seconds
        const qint64 now = QDateTime::currentMSecsSinceEpoch();
        if (now - _lastVoiceAlertMs > 6000) {
            _lastVoiceAlertMs = now;
            if (_highTensionAlarm) {
                _speakVoiceAlert(QStringLiteral("Warning: High tether tension!"));
            } else if (_powerCutoffAlarm) {
                _speakVoiceAlert(QStringLiteral("Emergency: Tether power lost! Land immediately!"));
            } else if (_lengthLimitAlarm) {
                _speakVoiceAlert(QStringLiteral("Warning: Tether maximum length reached!"));
            } else if (_slackAlarm) {
                _speakVoiceAlert(QStringLiteral("Caution: Tether slack detected!"));
            }
        }
    }
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

void SafeTManager::_onSecondTimer()
{
    if (_isConnected && (_stationVoltageV > 50.0f || _tensionN > 10.0f)) {
        _hoverDurationSec++;
        emit hoverDurationChanged();
    }

    if (_isLogging) {
        _writeLogRecord();
    }
}
