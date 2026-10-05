#pragma once

#include <QtCore/QLoggingCategory>
#include <QtCore/QObject>
#include <QtCore/QString>
#include <QtCore/QTimer>
#include <QtNetwork/QUdpSocket>

Q_DECLARE_LOGGING_CATEGORY(CompanyDataOutputLog)

class Vehicle;
class CompanyNetworkSettings;

/// Software-side UDP telemetry broadcast output for Chandipur DRDO evaluation.
/// Transmits rate-governed (1, 2, 5, 10 Hz) unified telemetry datagrams to the
/// configured target IP and port. Reuses decoded values from CompanyCsvLogger
/// without duplicate MAVLink decoding.
///
/// NOTE: Uses a clearly labeled evaluation test schema ("IZI_TEST_TELEMETRY_V1")
/// pending final production DRDO ICD specification.
class CompanyDataOutput : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool    isStreaming      READ isStreaming                           NOTIFY streamingChanged)
    Q_PROPERTY(quint64 packetsSent      READ packetsSent                           NOTIFY metricsChanged)
    Q_PROPERTY(quint64 bytesSent        READ bytesSent                             NOTIFY metricsChanged)
    Q_PROPERTY(int     currentRateHz    READ currentRateHz                         NOTIFY currentRateHzChanged)
    Q_PROPERTY(QString destinationIP    READ destinationIP                         NOTIFY destinationChanged)
    Q_PROPERTY(int     destinationPort  READ destinationPort                       NOTIFY destinationChanged)
    Q_PROPERTY(QString lastError        READ lastError                             NOTIFY lastErrorChanged)
    Q_PROPERTY(QString lastPacketSample READ lastPacketSample                      NOTIFY lastPacketSampleChanged)

public:
    explicit CompanyDataOutput(QObject *parent = nullptr);
    ~CompanyDataOutput() override = default;

    static CompanyDataOutput *instance();

    bool    isStreaming() const      { return _isStreaming; }
    quint64 packetsSent() const      { return _packetsSent; }
    quint64 bytesSent() const        { return _bytesSent; }
    int     currentRateHz() const    { return _currentRateHz; }
    QString destinationIP() const    { return _destinationIP; }
    int     destinationPort() const  { return _destinationPort; }
    QString lastError() const        { return _lastError; }
    QString lastPacketSample() const { return _lastPacketSample; }

    Q_INVOKABLE void startOutput();
    Q_INVOKABLE void stopOutput();
    Q_INVOKABLE void sendSinglePacket();

signals:
    void streamingChanged(bool streaming);
    void metricsChanged();
    void currentRateHzChanged(int rateHz);
    void destinationChanged();
    void lastErrorChanged(const QString &error);
    void lastPacketSampleChanged(const QString &sample);

private slots:
    void _onPeriodicTimeout();
    void _onSettingsChanged();
    void _onActiveVehicleChanged(Vehicle *vehicle);

private:
    void       _updateTimerRate(int rateHz);
    QByteArray _buildTelemetryPayload(Vehicle *vehicle);
    void       _transmitPacket();

    QUdpSocket _udpSocket;
    QTimer     _timer;

    bool       _isStreaming = false;
    quint64    _packetsSent = 0;
    quint64    _bytesSent = 0;
    quint64    _sequenceNumber = 0;

    int        _currentRateHz = 5;
    QString    _destinationIP;
    int        _destinationPort = 14445;
    QString    _lastError;
    QString    _lastPacketSample;

    Vehicle*   _activeVehicle = nullptr;
    CompanyNetworkSettings* _networkSettings = nullptr;
};
