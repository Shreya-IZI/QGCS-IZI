#include "SafeTTransport.h"
#include "QGCLoggingCategory.h"

#include <QtCore/QDateTime>
#include <QtCore/QRandomGenerator>
#include <QtNetwork/QHostAddress>
#include <cmath>

QGC_LOGGING_CATEGORY(SafeTTransportLog, "Company.SafeTTransport")

// ============================================================================
// SafeTMockTransport (Synthetic Simulator)
// ============================================================================

SafeTMockTransport::SafeTMockTransport(QObject *parent)
    : SafeTTransport(parent)
{
    _simTimer.setInterval(100); // 10 Hz telemetry loop
    connect(&_simTimer, &QTimer::timeout, this, &SafeTMockTransport::_onTick);
}

SafeTMockTransport::~SafeTMockTransport()
{
    disconnectTransport();
}

bool SafeTMockTransport::connectTransport(const QString &endpoint, int portOrBaud)
{
    Q_UNUSED(endpoint);
    Q_UNUSED(portOrBaud);
    _isConnected = true;
    _tickCount = 0;
    _simTimer.start();
    qCDebug(SafeTTransportLog) << "SafeTMockTransport started at 10 Hz";
    emit connectionStateChanged(true, QStringLiteral("CONNECTED (SIM)"));
    return true;
}

void SafeTMockTransport::disconnectTransport()
{
    if (_isConnected) {
        _simTimer.stop();
        _isConnected = false;
        qCDebug(SafeTTransportLog) << "SafeTMockTransport stopped";
        emit connectionStateChanged(false, QStringLiteral("STANDBY"));
    }
}

bool SafeTMockTransport::sendCommand(const QByteArray &command)
{
    const QString cmdStr = QString::fromUtf8(command);
    qCDebug(SafeTTransportLog) << "Mock Transport received command:" << cmdStr;

    if (cmdStr.contains(QStringLiteral("EMERGENCY_POWER_CUT")) || cmdStr.contains(QStringLiteral("POWER_OFF"))) {
        _powerEnabled = false;
    } else if (cmdStr.contains(QStringLiteral("POWER_ON"))) {
        _powerEnabled = true;
    } else if (cmdStr.startsWith(QStringLiteral("SET_FAULT:"))) {
        setSimulatedFault(cmdStr.section(u':', 1));
    }
    return true;
}

void SafeTMockTransport::setSimulatedFault(const QString &faultType)
{
    _activeFault = faultType;
    qCDebug(SafeTTransportLog) << "Simulated fault injected:" << faultType;
}

void SafeTMockTransport::_onTick()
{
    if (!_isConnected) return;
    _tickCount++;

    float tension = _tensionBase;
    float length = _lengthBase;
    float voltage = _powerEnabled ? _voltageBase : 0.0f;
    float current = _powerEnabled ? _currentBase : 0.0f;
    float temp = _tempBase + static_cast<float>(_tickCount % 500) * 0.01f;
    QString status = QStringLiteral("AUTO");

    if (_activeFault == QStringLiteral("HIGH_TENSION")) {
        tension = 138.0f + static_cast<float>(QRandomGenerator::global()->bounded(20) - 10) / 5.0f;
        status = QStringLiteral("HIGH_TENSION");
    } else if (_activeFault == QStringLiteral("SLACK")) {
        tension = 8.0f + static_cast<float>(QRandomGenerator::global()->bounded(10)) / 5.0f;
        status = QStringLiteral("SLACK");
    } else if (_activeFault == QStringLiteral("POWER_DROP")) {
        voltage = 280.0f; // Critical sag below 320V
        current = 3.1f;
        status = QStringLiteral("VOLTAGE_SAG");
    } else if (_activeFault == QStringLiteral("OVERHEAT")) {
        temp = 72.5f;
        status = QStringLiteral("TEMP_WARNING");
    } else {
        // Normal realistic oscillation
        const float tensionNoise = static_cast<float>(std::sin(_tickCount * 0.05)) * 3.5f +
                                   static_cast<float>(QRandomGenerator::global()->bounded(100) - 50) / 50.0f;
        tension = std::max(5.0f, _tensionBase + tensionNoise);

        const float lengthNoise = static_cast<float>(std::sin(_tickCount * 0.02)) * 0.4f;
        length = std::max(0.0f, _lengthBase + lengthNoise);

        if (_powerEnabled) {
            voltage = _voltageBase + static_cast<float>(QRandomGenerator::global()->bounded(40) - 20) / 10.0f;
            current = _currentBase + static_cast<float>(QRandomGenerator::global()->bounded(30) - 15) / 20.0f;
        }
    }

    emit telemetryPacketReceived(tension, length, voltage, current, temp, status);
}

// ============================================================================
// SafeTEthernetTransport (UDP / IP Socket)
// ============================================================================

SafeTEthernetTransport::SafeTEthernetTransport(QObject *parent)
    : SafeTTransport(parent)
{
}

SafeTEthernetTransport::~SafeTEthernetTransport()
{
    disconnectTransport();
}

bool SafeTEthernetTransport::connectTransport(const QString &endpoint, int portOrBaud)
{
    disconnectTransport();

    _hostAddress = endpoint.isEmpty() ? QStringLiteral("192.168.1.150") : endpoint;
    _port = (portOrBaud > 0) ? static_cast<quint16>(portOrBaud) : 50000;

    _udpSocket = new QUdpSocket(this);
    if (!_udpSocket->bind(QHostAddress::AnyIPv4, _port, QUdpSocket::ShareAddress | QUdpSocket::ReuseAddressHint)) {
        qCWarning(SafeTTransportLog) << "Failed to bind SafeT UDP socket on port" << _port
                                     << ":" << _udpSocket->errorString();
        emit transportError(_udpSocket->errorString());
        return false;
    }

    connect(_udpSocket, &QUdpSocket::readyRead, this, &SafeTEthernetTransport::_onReadyRead);
    _isConnected = true;
    qCDebug(SafeTTransportLog) << "SafeTEthernetTransport bound to UDP port" << _port;
    emit connectionStateChanged(true, QStringLiteral("CONNECTED (ETH)"));
    return true;
}

void SafeTEthernetTransport::disconnectTransport()
{
    if (_udpSocket) {
        _udpSocket->close();
        _udpSocket->deleteLater();
        _udpSocket = nullptr;
    }
    if (_isConnected) {
        _isConnected = false;
        qCDebug(SafeTTransportLog) << "SafeTEthernetTransport disconnected";
        emit connectionStateChanged(false, QStringLiteral("DISCONNECTED"));
    }
}

bool SafeTEthernetTransport::sendCommand(const QByteArray &command)
{
    if (!_udpSocket || !_isConnected) {
        qCWarning(SafeTTransportLog) << "Cannot send command: Ethernet transport not connected";
        return false;
    }
    const qint64 written = _udpSocket->writeDatagram(command, QHostAddress(_hostAddress), _port);
    return written == command.size();
}

void SafeTEthernetTransport::_onReadyRead()
{
    if (!_udpSocket) return;

    while (_udpSocket->hasPendingDatagrams()) {
        QByteArray datagram;
        datagram.resize(static_cast<qsizetype>(_udpSocket->pendingDatagramSize()));
        QHostAddress sender;
        quint16 senderPort = 0;
        _udpSocket->readDatagram(datagram.data(), datagram.size(), &sender, &senderPort);

        emit rawDataReceived(datagram);

        // Frame decoder hook: will parse physical SAFE-T binary frame once ICD is finalized.
        // If datagram has minimum 20 bytes (header + tension + length + V + I + temp + status)
        if (datagram.size() >= 24) {
            // Placeholder: unpack binary IEEE-754 floats
            // Emits telemetryPacketReceived once ICD layout is mapped
        }
    }
}

// ============================================================================
// SafeTSerialTransport (RS-485 / Virtual COM Port)
// ============================================================================

SafeTSerialTransport::SafeTSerialTransport(QObject *parent)
    : SafeTTransport(parent)
{
}

SafeTSerialTransport::~SafeTSerialTransport()
{
    disconnectTransport();
}

bool SafeTSerialTransport::connectTransport(const QString &endpoint, int portOrBaud)
{
    disconnectTransport();

    const QString portName = endpoint.isEmpty() ? QStringLiteral("/dev/ttyUSB0") : endpoint;
    const qint32 baudRate = (portOrBaud > 0) ? portOrBaud : 115200;

    _serialPort = new QSerialPort(this);
    _serialPort->setPortName(portName);
    _serialPort->setBaudRate(baudRate);
    _serialPort->setDataBits(QSerialPort::Data8);
    _serialPort->setParity(QSerialPort::NoParity);
    _serialPort->setStopBits(QSerialPort::OneStop);
    _serialPort->setFlowControl(QSerialPort::NoFlowControl);

    if (!_serialPort->open(QIODevice::ReadWrite)) {
        qCWarning(SafeTTransportLog) << "Failed to open serial port" << portName
                                     << ":" << _serialPort->errorString();
        emit transportError(_serialPort->errorString());
        return false;
    }

    connect(_serialPort, &QSerialPort::readyRead, this, &SafeTSerialTransport::_onReadyRead);
    _isConnected = true;
    _rxBuffer.clear();
    qCDebug(SafeTTransportLog) << "SafeTSerialTransport opened" << portName << "at" << baudRate;
    emit connectionStateChanged(true, QStringLiteral("CONNECTED (SERIAL)"));
    return true;
}

void SafeTSerialTransport::disconnectTransport()
{
    if (_serialPort) {
        if (_serialPort->isOpen()) {
            _serialPort->close();
        }
        _serialPort->deleteLater();
        _serialPort = nullptr;
    }
    if (_isConnected) {
        _isConnected = false;
        qCDebug(SafeTTransportLog) << "SafeTSerialTransport disconnected";
        emit connectionStateChanged(false, QStringLiteral("DISCONNECTED"));
    }
}

bool SafeTSerialTransport::sendCommand(const QByteArray &command)
{
    if (!_serialPort || !_serialPort->isOpen()) {
        qCWarning(SafeTTransportLog) << "Cannot send command: Serial port not open";
        return false;
    }
    const qint64 written = _serialPort->write(command);
    return written == command.size();
}

void SafeTSerialTransport::_onReadyRead()
{
    if (!_serialPort) return;
    const QByteArray incoming = _serialPort->readAll();
    if (!incoming.isEmpty()) {
        _rxBuffer.append(incoming);
        emit rawDataReceived(incoming);

        // Frame decoder hook: delimiter-based or fixed-length packet processing
        // once physical ICD baud rate and frame delimiters are received
    }
}
