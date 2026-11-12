#pragma once

#include <QtCore/QByteArray>
#include <QtCore/QLoggingCategory>
#include <QtCore/QObject>
#include <QtCore/QString>
#include <QtCore/QTimer>
#include <QtNetwork/QUdpSocket>
#include <QtSerialPort/QSerialPort>

Q_DECLARE_LOGGING_CATEGORY(SafeTTransportLog)

/// Abstract base transport layer for communication with the SAFE-T Tether Ground Station.
/// Decouples the GCS telemetry monitoring and alarm state machine from physical I/O.
class SafeTTransport : public QObject
{
    Q_OBJECT

public:
    explicit SafeTTransport(QObject *parent = nullptr) : QObject(parent) {}
    ~SafeTTransport() override = default;

    virtual bool connectTransport(const QString &endpoint, int portOrBaud = 0) = 0;
    virtual void disconnectTransport() = 0;
    virtual bool isConnected() const = 0;
    virtual QString transportName() const = 0;
    virtual bool sendCommand(const QByteArray &command) = 0;

signals:
    void telemetryPacketReceived(float tensionN, float lengthM, float voltageV,
                                 float currentA, float tempC, const QString &winchStatus);
    void rawDataReceived(const QByteArray &data);
    void connectionStateChanged(bool connected, const QString &statusText);
    void transportError(const QString &errorMessage);
};

/// Synthetic simulator transport for bench testing without physical tether hardware.
class SafeTMockTransport : public SafeTTransport
{
    Q_OBJECT

public:
    explicit SafeTMockTransport(QObject *parent = nullptr);
    ~SafeTMockTransport() override;

    bool connectTransport(const QString &endpoint, int portOrBaud = 0) override;
    void disconnectTransport() override;
    bool isConnected() const override { return _isConnected; }
    QString transportName() const override { return QStringLiteral("SIMULATOR"); }
    bool sendCommand(const QByteArray &command) override;
    void setSimulatedFault(const QString &faultType);

private slots:
    void _onTick();

private:
    QTimer  _simTimer;
    bool    _isConnected = false;
    bool    _powerEnabled = true;
    QString _activeFault;
    float   _tensionBase = 48.0f;
    float   _lengthBase = 28.5f;
    float   _voltageBase = 398.0f;
    float   _currentBase = 8.5f;
    float   _tempBase = 38.0f;
    int     _tickCount = 0;
};

/// Ethernet / UDP / TCP socket transport for physical Elistair SAFE-T Station.
class SafeTEthernetTransport : public SafeTTransport
{
    Q_OBJECT

public:
    explicit SafeTEthernetTransport(QObject *parent = nullptr);
    ~SafeTEthernetTransport() override;

    bool connectTransport(const QString &endpoint, int portOrBaud = 0) override;
    void disconnectTransport() override;
    bool isConnected() const override { return _isConnected; }
    QString transportName() const override { return QStringLiteral("ETHERNET"); }
    bool sendCommand(const QByteArray &command) override;

private slots:
    void _onReadyRead();

private:
    QUdpSocket *_udpSocket = nullptr;
    QString     _hostAddress;
    quint16     _port = 0;
    bool        _isConnected = false;
};

/// Serial / RS-485 / Virtual COM transport for physical Elistair SAFE-T Station.
class SafeTSerialTransport : public SafeTTransport
{
    Q_OBJECT

public:
    explicit SafeTSerialTransport(QObject *parent = nullptr);
    ~SafeTSerialTransport() override;

    bool connectTransport(const QString &endpoint, int portOrBaud = 0) override;
    void disconnectTransport() override;
    bool isConnected() const override { return _isConnected; }
    QString transportName() const override { return QStringLiteral("SERIAL"); }
    bool sendCommand(const QByteArray &command) override;

private slots:
    void _onReadyRead();

private:
    QSerialPort *_serialPort = nullptr;
    bool         _isConnected = false;
    QByteArray   _rxBuffer;
};
