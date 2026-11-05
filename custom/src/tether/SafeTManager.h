#pragma once

#include <QtCore/QLoggingCategory>
#include <QtCore/QObject>
#include <QtCore/QString>
#include <QtCore/QTimer>
#include <QtNetwork/QUdpSocket>

Q_DECLARE_LOGGING_CATEGORY(SafeTManagerLog)

/// Communication worker for Tether Ground Station (SAFE-T).
/// Operates against an internal synthetic test generator until the physical
/// SAFE-T Interface Control Document (ICD) and hardware are verified.
class SafeTManager : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool    isConnected      READ isConnected      NOTIFY connectionChanged)
    Q_PROPERTY(bool    isStale          READ isStale          NOTIFY staleChanged)
    Q_PROPERTY(QString connectionStatus READ connectionStatus NOTIFY connectionChanged)
    Q_PROPERTY(QString linkTransport    READ linkTransport    NOTIFY linkTransportChanged)
    Q_PROPERTY(float   tensionN         READ tensionN         NOTIFY telemetryUpdated)
    Q_PROPERTY(float   tetherLengthM    READ tetherLengthM    NOTIFY telemetryUpdated)
    Q_PROPERTY(float   stationVoltageV  READ stationVoltageV  NOTIFY telemetryUpdated)
    Q_PROPERTY(float   stationCurrentA  READ stationCurrentA  NOTIFY telemetryUpdated)
    Q_PROPERTY(float   drumTempC        READ drumTempC        NOTIFY telemetryUpdated)
    Q_PROPERTY(QString winchStatus      READ winchStatus      NOTIFY telemetryUpdated)
    Q_PROPERTY(bool    highTensionAlarm READ highTensionAlarm NOTIFY alarmsChanged)

public:
    explicit SafeTManager(QObject *parent = nullptr);
    ~SafeTManager() override = default;

    static SafeTManager *instance();

    bool    isConnected() const      { return _isConnected; }
    bool    isStale() const          { return _isStale; }
    QString connectionStatus() const { return _connectionStatus; }
    QString linkTransport() const    { return _linkTransport; }

    float   tensionN() const         { return _tensionN; }
    float   tetherLengthM() const    { return _tetherLengthM; }
    float   stationVoltageV() const  { return _stationVoltageV; }
    float   stationCurrentA() const  { return _stationCurrentA; }
    float   drumTempC() const        { return _drumTempC; }
    QString winchStatus() const      { return _winchStatus; }
    bool    highTensionAlarm() const { return _highTensionAlarm; }

    Q_INVOKABLE void connectLink(const QString &hostOrPort, int port = 0);
    Q_INVOKABLE void disconnectLink();
    Q_INVOKABLE void startSimulation();
    Q_INVOKABLE void stopSimulation();

signals:
    void connectionChanged();
    void staleChanged();
    void linkTransportChanged();
    void telemetryUpdated();
    void alarmsChanged();

private slots:
    void _onSimulationTick();
    void _onWatchdogCheck();

private:
    bool    _isConnected = false;
    bool    _isStale = false;
    QString _connectionStatus = QStringLiteral("STANDBY");
    QString _linkTransport = QStringLiteral("SIMULATOR");

    float   _tensionN = 0.0f;
    float   _tetherLengthM = 0.0f;
    float   _stationVoltageV = 0.0f;
    float   _stationCurrentA = 0.0f;
    float   _drumTempC = 0.0f;
    QString _winchStatus = QStringLiteral("IDLE");
    bool    _highTensionAlarm = false;

    qint64  _lastPacketMs = 0;
    QTimer  _simTimer;
    QTimer  _watchdogTimer;
    float   _simPhase = 0.0f;
};
