#pragma once

#include <QtCore/QDateTime>
#include <QtCore/QFile>
#include <QtCore/QLoggingCategory>
#include <QtCore/QObject>
#include <QtCore/QString>
#include <QtCore/QTextStream>
#include <QtCore/QTimer>
#include <memory>

class SafeTTransport;

Q_DECLARE_LOGGING_CATEGORY(SafeTManagerLog)

/// Communication worker and system controller for Tether Ground Station (SAFE-T).
/// Interfaces via the SafeTTransport Hardware Abstraction Layer (HAL).
class SafeTManager : public QObject
{
    Q_OBJECT

    // Connection & Transport State
    Q_PROPERTY(bool    isConnected        READ isConnected        NOTIFY connectionChanged)
    Q_PROPERTY(bool    isStale            READ isStale            NOTIFY staleChanged)
    Q_PROPERTY(QString connectionStatus   READ connectionStatus   NOTIFY connectionChanged)
    Q_PROPERTY(QString linkTransport      READ linkTransport      NOTIFY linkTransportChanged)

    // Telemetry
    Q_PROPERTY(float   tensionN           READ tensionN           NOTIFY telemetryUpdated)
    Q_PROPERTY(float   tetherLengthM      READ tetherLengthM      NOTIFY telemetryUpdated)
    Q_PROPERTY(float   cableSpeedMps      READ cableSpeedMps      NOTIFY telemetryUpdated)
    Q_PROPERTY(float   stationVoltageV    READ stationVoltageV    NOTIFY telemetryUpdated)
    Q_PROPERTY(float   stationCurrentA    READ stationCurrentA    NOTIFY telemetryUpdated)
    Q_PROPERTY(float   stationPowerW      READ stationPowerW      NOTIFY telemetryUpdated)
    Q_PROPERTY(float   stationPowerKW     READ stationPowerKW     NOTIFY telemetryUpdated)
    Q_PROPERTY(float   drumTempC          READ drumTempC          NOTIFY telemetryUpdated)
    Q_PROPERTY(QString winchStatus        READ winchStatus        NOTIFY telemetryUpdated)
    Q_PROPERTY(int     hoverDurationSec   READ hoverDurationSec   NOTIFY hoverDurationChanged)
    Q_PROPERTY(QString hoverDurationStr   READ hoverDurationStr   NOTIFY hoverDurationChanged)

    // Winch & Power Control
    Q_PROPERTY(bool    powerOutputEnabled READ powerOutputEnabled WRITE setPowerOutput    NOTIFY powerOutputChanged)
    Q_PROPERTY(float   motorTorquePct     READ motorTorquePct     WRITE setMotorTorque    NOTIFY motorTorqueChanged)

    // Alarms & Safety System
    Q_PROPERTY(bool    highTensionAlarm   READ highTensionAlarm   NOTIFY alarmsChanged)
    Q_PROPERTY(bool    powerCutoffAlarm   READ powerCutoffAlarm   NOTIFY alarmsChanged)
    Q_PROPERTY(bool    lengthLimitAlarm   READ lengthLimitAlarm   NOTIFY alarmsChanged)
    Q_PROPERTY(bool    slackAlarm         READ slackAlarm         NOTIFY alarmsChanged)
    Q_PROPERTY(QString activeAlertMessage READ activeAlertMessage NOTIFY alarmsChanged)
    Q_PROPERTY(int     alertSeverity      READ alertSeverity      NOTIFY alarmsChanged)
    Q_PROPERTY(bool    voiceAlertsEnabled READ voiceAlertsEnabled WRITE setVoiceAlertsEnabled NOTIFY voiceAlertsChanged)

    // Configurable operational limits & setpoints
    Q_PROPERTY(float   maxTetherLength    READ maxTetherLength    WRITE setMaxTetherLength    NOTIFY limitsChanged)
    Q_PROPERTY(float   targetTension      READ targetTension      WRITE setTargetTension      NOTIFY limitsChanged)
    Q_PROPERTY(float   highTensionLimit   READ highTensionLimit   WRITE setHighTensionLimit   NOTIFY limitsChanged)
    Q_PROPERTY(float   lengthZeroOffset   READ lengthZeroOffset   NOTIFY telemetryUpdated)

    // Blackbox Data Logging
    Q_PROPERTY(bool    isLogging          READ isLogging          NOTIFY loggingChanged)
    Q_PROPERTY(QString currentLogFile     READ currentLogFile     NOTIFY loggingChanged)
    Q_PROPERTY(int     loggedRecordsCount READ loggedRecordsCount NOTIFY loggingChanged)
    Q_PROPERTY(bool    autoLogOnConnect   READ autoLogOnConnect   WRITE setAutoLogOnConnect   NOTIFY loggingChanged)

public:
    enum class TransportType {
        Mock = 0,
        Ethernet = 1,
        Serial = 2
    };
    Q_ENUM(TransportType)

    explicit SafeTManager(QObject *parent = nullptr);
    ~SafeTManager() override;

    static SafeTManager *instance();

    bool    isConnected() const        { return _isConnected; }
    bool    isStale() const            { return _isStale; }
    QString connectionStatus() const   { return _connectionStatus; }
    QString linkTransport() const      { return _linkTransport; }

    float   tensionN() const           { return _tensionN; }
    float   tetherLengthM() const      { return std::max(0.0f, _tetherLengthM - _lengthZeroOffset); }
    float   cableSpeedMps() const      { return _cableSpeedMps; }
    float   stationVoltageV() const    { return _stationVoltageV; }
    float   stationCurrentA() const    { return _stationCurrentA; }
    float   stationPowerW() const      { return _stationVoltageV * _stationCurrentA; }
    float   stationPowerKW() const     { return (_stationVoltageV * _stationCurrentA) / 1000.0f; }
    float   drumTempC() const          { return _drumTempC; }
    QString winchStatus() const        { return _winchStatus; }
    int     hoverDurationSec() const   { return _hoverDurationSec; }
    QString hoverDurationStr() const;

    bool    powerOutputEnabled() const { return _powerOutputEnabled; }
    float   motorTorquePct() const     { return _motorTorquePct; }

    bool    highTensionAlarm() const   { return _highTensionAlarm; }
    bool    powerCutoffAlarm() const   { return _powerCutoffAlarm; }
    bool    lengthLimitAlarm() const   { return _lengthLimitAlarm; }
    bool    slackAlarm() const         { return _slackAlarm; }
    QString activeAlertMessage() const { return _activeAlertMessage; }
    int     alertSeverity() const      { return _alertSeverity; }
    bool    voiceAlertsEnabled() const { return _voiceAlertsEnabled; }

    float   maxTetherLength() const    { return _maxTetherLength; }
    float   targetTension() const      { return _targetTension; }
    float   highTensionLimit() const   { return _highTensionLimit; }
    float   lengthZeroOffset() const   { return _lengthZeroOffset; }

    bool    isLogging() const          { return _isLogging; }
    QString currentLogFile() const     { return _currentLogFilePath; }
    int     loggedRecordsCount() const { return _loggedRecordsCount; }
    bool    autoLogOnConnect() const   { return _autoLogOnConnect; }

    // Pilot & Technician Command Actions
    Q_INVOKABLE void connectLink(const QString &hostOrPort, int portOrBaud = 0);
    Q_INVOKABLE void disconnectLink();
    Q_INVOKABLE void setTransportType(int type);
    Q_INVOKABLE void startSimulation();
    Q_INVOKABLE void stopSimulation();
    Q_INVOKABLE bool sendWinchCommand(const QString &commandName);
    Q_INVOKABLE void setWinchMode(const QString &mode);
    Q_INVOKABLE void zeroCableLength();
    Q_INVOKABLE void emergencyCutoff();

    // Dedicated Winch & Power Controls
    Q_INVOKABLE void setPowerOutput(bool enabled);
    Q_INVOKABLE void setMotorTorque(float pct);
    Q_INVOKABLE void autoTension();
    Q_INVOKABLE void holdTether();
    Q_INVOKABLE void reelIn();
    Q_INVOKABLE void reelOut();

    // Setpoint adjustments
    Q_INVOKABLE void setMaxTetherLength(float maxM);
    Q_INVOKABLE void setTargetTension(float targetN);
    Q_INVOKABLE void setHighTensionLimit(float limitN);

    // Audio & Annunciator Controls
    Q_INVOKABLE void setVoiceAlertsEnabled(bool enabled);
    Q_INVOKABLE void testVoiceAlert();

    // Blackbox Logging
    Q_INVOKABLE void startLogging();
    Q_INVOKABLE void stopLogging();
    Q_INVOKABLE void setAutoLogOnConnect(bool enabled);

    // Simulation Fault Injection & Bench Testing
    Q_INVOKABLE void simulateFault(const QString &faultType);
    Q_INVOKABLE void resetHoverTimer();

signals:
    void connectionChanged();
    void staleChanged();
    void linkTransportChanged();
    void telemetryUpdated();
    void hoverDurationChanged();
    void powerOutputChanged();
    void motorTorqueChanged();
    void alarmsChanged();
    void limitsChanged();
    void voiceAlertsChanged();
    void loggingChanged();
    void voiceAlertTriggered(const QString &message);

private slots:
    void _onTelemetryPacket(float tensionN, float lengthM, float voltageV,
                            float currentA, float tempC, const QString &winchStatus);
    void _onConnectionStateChanged(bool connected, const QString &statusText);
    void _onTransportError(const QString &errorMessage);
    void _onWatchdogCheck();
    void _onSecondTimer();

private:
    void _setupTransport(TransportType type);
    void _evaluateAlarms();
    void _speakVoiceAlert(const QString &message);
    void _writeLogRecord();

    std::unique_ptr<SafeTTransport> _transport;
    TransportType _currentType = TransportType::Mock;

    bool    _isConnected = false;
    bool    _isStale = false;
    QString _connectionStatus = QStringLiteral("STANDBY");
    QString _linkTransport = QStringLiteral("SIMULATOR");

    float   _tensionN = 0.0f;
    float   _tetherLengthM = 0.0f;
    float   _lastRawLengthM = 0.0f;
    float   _cableSpeedMps = 0.0f;
    float   _stationVoltageV = 0.0f;
    float   _stationCurrentA = 0.0f;
    float   _drumTempC = 0.0f;
    QString _winchStatus = QStringLiteral("IDLE");
    int     _hoverDurationSec = 0;

    bool    _powerOutputEnabled = true;
    float   _motorTorquePct = 100.0f;

    bool    _highTensionAlarm = false;
    bool    _powerCutoffAlarm = false;
    bool    _lengthLimitAlarm = false;
    bool    _slackAlarm = false;
    QString _activeAlertMessage;
    int     _alertSeverity = 0; // 0: None, 1: Warning, 2: Critical
    bool    _voiceAlertsEnabled = true;

    // Configurable thresholds
    float   _maxTetherLength = 50.0f;
    float   _targetTension = 45.0f;
    float   _highTensionLimit = 120.0f;
    float   _lengthZeroOffset = 0.0f;

    // Blackbox Logging
    bool        _isLogging = false;
    bool        _autoLogOnConnect = true;
    QString     _currentLogFilePath;
    int         _loggedRecordsCount = 0;
    QFile       _logFile;
    QTextStream _logStream;

    qint64  _lastPacketMs = 0;
    qint64  _lastSpeedCalcMs = 0;
    qint64  _lastVoiceAlertMs = 0;
    QTimer  _watchdogTimer;
    QTimer  _oneSecondTimer;
};
