#include "CompanyNetworkSettings.h"

#include <QtCore/QApplicationStatic>
#include <QtCore/QSettings>
#include <QtNetwork/QAbstractSocket>
#include <QtNetwork/QHostAddress>

#include "MavlinkSettings.h"
#include "QGCLoggingCategory.h"
#include "SettingsManager.h"

QGC_LOGGING_CATEGORY(CompanyNetworkSettingsLog, "Company.NetworkSettings")

Q_APPLICATION_STATIC(CompanyNetworkSettings, _companyNetworkSettingsInstance);

CompanyNetworkSettings *CompanyNetworkSettings::instance()
{
    return _companyNetworkSettingsInstance();
}

CompanyNetworkSettings::CompanyNetworkSettings(QObject *parent)
    : QObject(parent)
{
    loadSettings();
    qCDebug(CompanyNetworkSettingsLog) << "CompanyNetworkSettings initialized";
}

QString CompanyNetworkSettings::pmddlStatusText() const
{
    if (_pmddlLinkMode == QStringLiteral("DISABLED")) {
        return QStringLiteral("LINK DISABLED");
    }
    if (_pmddlRemoteIP.isEmpty() || !isValidIPv4(_pmddlRemoteIP)) {
        return QStringLiteral("UNCONFIGURED");
    }
    return QStringLiteral("STANDBY (READY)");
}

bool CompanyNetworkSettings::isValidIPv4(const QString &ip) const
{
    if (ip.isEmpty()) {
        return false;
    }
    QHostAddress addr;
    if (addr.setAddress(ip)) {
        return addr.protocol() == QAbstractSocket::IPv4Protocol;
    }
    return false;
}

bool CompanyNetworkSettings::isValidPort(int port) const
{
    return port >= 1 && port <= 65535;
}

bool CompanyNetworkSettings::isValidHost(const QString &host) const
{
    if (host.isEmpty()) {
        return false;
    }
    if (isValidIPv4(host)) {
        return true;
    }
    // Hostname regex (e.g. localhost, drone-relay.local)
    static const QRegularExpression hostRegex(
        QStringLiteral("^[a-zA-Z0-9]([a-zA-Z0-9\\-]{0,61}[a-zA-Z0-9])?(\\.[a-zA-Z0-9]([a-zA-Z0-9\\-]{0,61}[a-zA-Z0-9])?)*$")
    );
    return hostRegex.match(host).hasMatch();
}

void CompanyNetworkSettings::setThermalVideoUrl(const QString &url)
{
    if (_thermalVideoUrl != url) {
        _thermalVideoUrl = url;
        emit thermalVideoUrlChanged(_thermalVideoUrl);
        saveSettings();
    }
}

void CompanyNetworkSettings::setThermalVideoPort(int port)
{
    if (isValidPort(port) && _thermalVideoPort != port) {
        _thermalVideoPort = port;
        emit thermalVideoPortChanged(_thermalVideoPort);
        saveSettings();
    }
}

void CompanyNetworkSettings::setThermalVideoType(const QString &type)
{
    if (_thermalVideoType != type) {
        _thermalVideoType = type;
        emit thermalVideoTypeChanged(_thermalVideoType);
        saveSettings();
    }
}

void CompanyNetworkSettings::setUdpTelemetryEnabled(bool enabled)
{
    if (_udpTelemetryEnabled != enabled) {
        _udpTelemetryEnabled = enabled;
        emit udpTelemetryEnabledChanged(_udpTelemetryEnabled);
        _syncWithQGCSettings();
        saveSettings();
    }
}

void CompanyNetworkSettings::setUdpTelemetryDestIP(const QString &ip)
{
    if (_udpTelemetryDestIP != ip) {
        _udpTelemetryDestIP = ip;
        emit udpTelemetryDestIPChanged(_udpTelemetryDestIP);
        _syncWithQGCSettings();
        saveSettings();
    }
}

void CompanyNetworkSettings::setUdpTelemetryDestPort(int port)
{
    if (isValidPort(port) && _udpTelemetryDestPort != port) {
        _udpTelemetryDestPort = port;
        emit udpTelemetryDestPortChanged(_udpTelemetryDestPort);
        _syncWithQGCSettings();
        saveSettings();
    }
}

void CompanyNetworkSettings::setUdpTelemetryRateHz(int rateHz)
{
    if (rateHz < 1) rateHz = 1;
    if (rateHz > 50) rateHz = 50;
    if (_udpTelemetryRateHz != rateHz) {
        _udpTelemetryRateHz = rateHz;
        emit udpTelemetryRateHzChanged(_udpTelemetryRateHz);
        saveSettings();
    }
}

void CompanyNetworkSettings::setPmddlLinkMode(const QString &mode)
{
    if (_pmddlLinkMode != mode) {
        _pmddlLinkMode = mode;
        emit pmddlLinkModeChanged(_pmddlLinkMode);
        emit pmddlStatusTextChanged();
        saveSettings();
    }
}

void CompanyNetworkSettings::setPmddlRemoteIP(const QString &ip)
{
    if (_pmddlRemoteIP != ip) {
        _pmddlRemoteIP = ip;
        emit pmddlRemoteIPChanged(_pmddlRemoteIP);
        emit pmddlStatusTextChanged();
        saveSettings();
    }
}

void CompanyNetworkSettings::setPmddlDataPort(int port)
{
    if (isValidPort(port) && _pmddlDataPort != port) {
        _pmddlDataPort = port;
        emit pmddlDataPortChanged(_pmddlDataPort);
        saveSettings();
    }
}

void CompanyNetworkSettings::setPmddlEncryptEnabled(bool enabled)
{
    if (_pmddlEncryptEnabled != enabled) {
        _pmddlEncryptEnabled = enabled;
        emit pmddlEncryptEnabledChanged(_pmddlEncryptEnabled);
        saveSettings();
    }
}

void CompanyNetworkSettings::setEthernetLogEnabled(bool enabled)
{
    if (_ethernetLogEnabled != enabled) {
        _ethernetLogEnabled = enabled;
        emit ethernetLogEnabledChanged(_ethernetLogEnabled);
        saveSettings();
    }
}

void CompanyNetworkSettings::setEthernetLogDroneIP(const QString &ip)
{
    if (isValidIPv4(ip) && _ethernetLogDroneIP != ip) {
        _ethernetLogDroneIP = ip;
        emit ethernetLogDroneIPChanged(_ethernetLogDroneIP);
        saveSettings();
    }
}

void CompanyNetworkSettings::setEthernetLogPort(int port)
{
    if (isValidPort(port) && _ethernetLogPort != port) {
        _ethernetLogPort = port;
        emit ethernetLogPortChanged(_ethernetLogPort);
        saveSettings();
    }
}

void CompanyNetworkSettings::setEthernetLogHttpPort(int port)
{
    if (isValidPort(port) && _ethernetLogHttpPort != port) {
        _ethernetLogHttpPort = port;
        emit ethernetLogHttpPortChanged(_ethernetLogHttpPort);
        saveSettings();
    }
}

void CompanyNetworkSettings::setEthernetLogProtocol(const QString &protocol)
{
    if (_ethernetLogProtocol != protocol) {
        _ethernetLogProtocol = protocol;
        emit ethernetLogProtocolChanged(_ethernetLogProtocol);
        saveSettings();
    }
}

void CompanyNetworkSettings::setEthernetLogAutoOffload(bool autoOffload)
{
    if (_ethernetLogAutoOffload != autoOffload) {
        _ethernetLogAutoOffload = autoOffload;
        emit ethernetLogAutoOffloadChanged(_ethernetLogAutoOffload);
        saveSettings();
    }
}

void CompanyNetworkSettings::_syncWithQGCSettings()
{
    // Note: Do not mutate core QGC forwardMavlink Fact here because it has
    // rebootRequired=true, which triggers a blocking modal restart dialog.
    // CompanyDataOutput operates dynamically and independently with real-time rate governance.
}

void CompanyNetworkSettings::loadSettings()
{
    QSettings settings;

    // Thermal Video
    settings.beginGroup(QStringLiteral("Company_ThermalVideo"));
    _thermalVideoUrl  = settings.value(QStringLiteral("url"), QStringLiteral("rtsp://127.0.0.1:8554/thermal")).toString();
    _thermalVideoPort = settings.value(QStringLiteral("port"), 8554).toInt();
    _thermalVideoType = settings.value(QStringLiteral("type"), QStringLiteral("RTSP")).toString();
    settings.endGroup();

    // UDP Telemetry Broadcast
    settings.beginGroup(QStringLiteral("Company_UdpTelemetry"));
    _udpTelemetryEnabled  = settings.contains(QStringLiteral("enabled")) ? settings.value(QStringLiteral("enabled")).toBool() : false;
    _udpTelemetryDestIP   = settings.contains(QStringLiteral("destinationIP")) ? settings.value(QStringLiteral("destinationIP")).toString() : settings.value(QStringLiteral("destinationip"), QStringLiteral("127.0.0.1")).toString();
    _udpTelemetryDestPort = settings.contains(QStringLiteral("destinationPort")) ? settings.value(QStringLiteral("destinationPort")).toInt() : settings.value(QStringLiteral("destinationport"), 14445).toInt();
    _udpTelemetryRateHz   = settings.contains(QStringLiteral("rateHz")) ? settings.value(QStringLiteral("rateHz")).toInt() : settings.value(QStringLiteral("ratehz"), 5).toInt();
    settings.endGroup();

    // PMDDL Interface Boundaries
    settings.beginGroup(QStringLiteral("Company_PMDDL"));
    _pmddlLinkMode       = settings.contains(QStringLiteral("linkMode")) ? settings.value(QStringLiteral("linkMode")).toString() : settings.value(QStringLiteral("linkmode"), QStringLiteral("STANDBY")).toString();
    _pmddlRemoteIP       = settings.contains(QStringLiteral("remoteIP")) ? settings.value(QStringLiteral("remoteIP")).toString() : settings.value(QStringLiteral("remoteip"), QStringLiteral("192.168.1.10")).toString();
    _pmddlDataPort       = settings.contains(QStringLiteral("dataPort")) ? settings.value(QStringLiteral("dataPort")).toInt() : settings.value(QStringLiteral("dataport"), 14555).toInt();
    _pmddlEncryptEnabled = settings.contains(QStringLiteral("encryptionEnabled")) ? settings.value(QStringLiteral("encryptionEnabled")).toBool() : settings.value(QStringLiteral("encryptionenabled"), false).toBool();
    settings.endGroup();

    // High-Speed Ethernet Log & Payload Offload
    settings.beginGroup(QStringLiteral("Company_EthernetLog"));
    _ethernetLogEnabled     = settings.contains(QStringLiteral("enabled")) ? settings.value(QStringLiteral("enabled")).toBool() : true;
    _ethernetLogDroneIP     = settings.contains(QStringLiteral("droneIP")) ? settings.value(QStringLiteral("droneIP")).toString() : QStringLiteral("192.168.168.2");
    _ethernetLogPort        = settings.contains(QStringLiteral("port")) ? settings.value(QStringLiteral("port")).toInt() : 14550;
    _ethernetLogHttpPort    = settings.contains(QStringLiteral("httpPort")) ? settings.value(QStringLiteral("httpPort")).toInt() : 8080;
    _ethernetLogProtocol    = settings.contains(QStringLiteral("protocol")) ? settings.value(QStringLiteral("protocol")).toString() : QStringLiteral("MAVLink FTP (UDP)");
    _ethernetLogAutoOffload = settings.contains(QStringLiteral("autoOffload")) ? settings.value(QStringLiteral("autoOffload")).toBool() : true;
    settings.endGroup();

    emit thermalVideoUrlChanged(_thermalVideoUrl);
    emit thermalVideoPortChanged(_thermalVideoPort);
    emit thermalVideoTypeChanged(_thermalVideoType);

    emit udpTelemetryEnabledChanged(_udpTelemetryEnabled);
    emit udpTelemetryDestIPChanged(_udpTelemetryDestIP);
    emit udpTelemetryDestPortChanged(_udpTelemetryDestPort);
    emit udpTelemetryRateHzChanged(_udpTelemetryRateHz);

    emit pmddlLinkModeChanged(_pmddlLinkMode);
    emit pmddlRemoteIPChanged(_pmddlRemoteIP);
    emit pmddlDataPortChanged(_pmddlDataPort);
    emit pmddlEncryptEnabledChanged(_pmddlEncryptEnabled);
    emit pmddlStatusTextChanged();

    emit ethernetLogEnabledChanged(_ethernetLogEnabled);
    emit ethernetLogDroneIPChanged(_ethernetLogDroneIP);
    emit ethernetLogPortChanged(_ethernetLogPort);
    emit ethernetLogHttpPortChanged(_ethernetLogHttpPort);
    emit ethernetLogProtocolChanged(_ethernetLogProtocol);
    emit ethernetLogAutoOffloadChanged(_ethernetLogAutoOffload);

    qCDebug(CompanyNetworkSettingsLog) << "Loaded CompanyNetworkSettings from QSettings";
}

void CompanyNetworkSettings::saveSettings()
{
    QSettings settings;

    // Thermal Video
    settings.beginGroup(QStringLiteral("Company_ThermalVideo"));
    settings.setValue(QStringLiteral("url"), _thermalVideoUrl);
    settings.setValue(QStringLiteral("port"), _thermalVideoPort);
    settings.setValue(QStringLiteral("type"), _thermalVideoType);
    settings.endGroup();

    // UDP Telemetry Broadcast
    settings.beginGroup(QStringLiteral("Company_UdpTelemetry"));
    settings.setValue(QStringLiteral("enabled"), _udpTelemetryEnabled);
    settings.setValue(QStringLiteral("destinationIP"), _udpTelemetryDestIP);
    settings.setValue(QStringLiteral("destinationPort"), _udpTelemetryDestPort);
    settings.setValue(QStringLiteral("rateHz"), _udpTelemetryRateHz);
    settings.endGroup();

    // PMDDL Interface Boundaries
    settings.beginGroup(QStringLiteral("Company_PMDDL"));
    settings.setValue(QStringLiteral("linkMode"), _pmddlLinkMode);
    settings.setValue(QStringLiteral("remoteIP"), _pmddlRemoteIP);
    settings.setValue(QStringLiteral("dataPort"), _pmddlDataPort);
    settings.setValue(QStringLiteral("encryptionEnabled"), _pmddlEncryptEnabled);
    settings.endGroup();

    // High-Speed Ethernet Log & Payload Offload
    settings.beginGroup(QStringLiteral("Company_EthernetLog"));
    settings.setValue(QStringLiteral("enabled"), _ethernetLogEnabled);
    settings.setValue(QStringLiteral("droneIP"), _ethernetLogDroneIP);
    settings.setValue(QStringLiteral("port"), _ethernetLogPort);
    settings.setValue(QStringLiteral("httpPort"), _ethernetLogHttpPort);
    settings.setValue(QStringLiteral("protocol"), _ethernetLogProtocol);
    settings.setValue(QStringLiteral("autoOffload"), _ethernetLogAutoOffload);
    settings.endGroup();

    settings.sync();
    qCDebug(CompanyNetworkSettingsLog) << "Saved CompanyNetworkSettings to QSettings";
}

