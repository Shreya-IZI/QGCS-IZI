#pragma once

#include <QtCore/QLoggingCategory>
#include <QtCore/QObject>
#include <QtCore/QSettings>
#include <QtCore/QString>
#include <QtCore/QRegularExpression>

Q_DECLARE_LOGGING_CATEGORY(CompanyNetworkSettingsLog)

/// Centralized network and link settings persistence for Chandipur DRDO evaluation.
/// Stores software-configurable endpoints using standard QSettings, validates IPv4/ports,
/// and synchronizes with existing QGC settings infrastructure.
class CompanyNetworkSettings : public QObject
{
    Q_OBJECT

    // Thermal Video Endpoints (Extending QGC VideoManager capabilities)
    Q_PROPERTY(QString thermalVideoUrl     READ thermalVideoUrl     WRITE setThermalVideoUrl     NOTIFY thermalVideoUrlChanged)
    Q_PROPERTY(int     thermalVideoPort    READ thermalVideoPort    WRITE setThermalVideoPort    NOTIFY thermalVideoPortChanged)
    Q_PROPERTY(QString thermalVideoType    READ thermalVideoType    WRITE setThermalVideoType    NOTIFY thermalVideoTypeChanged)

    // UDP Telemetry Broadcast Output
    Q_PROPERTY(bool    udpTelemetryEnabled READ udpTelemetryEnabled WRITE setUdpTelemetryEnabled NOTIFY udpTelemetryEnabledChanged)
    Q_PROPERTY(QString udpTelemetryDestIP  READ udpTelemetryDestIP  WRITE setUdpTelemetryDestIP  NOTIFY udpTelemetryDestIPChanged)
    Q_PROPERTY(int     udpTelemetryDestPort READ udpTelemetryDestPort WRITE setUdpTelemetryDestPort NOTIFY udpTelemetryDestPortChanged)
    Q_PROPERTY(int     udpTelemetryRateHz  READ udpTelemetryRateHz  WRITE setUdpTelemetryRateHz  NOTIFY udpTelemetryRateHzChanged)

    // PMDDL Interface Boundary Placeholders (No protocol assumption)
    Q_PROPERTY(QString pmddlLinkMode       READ pmddlLinkMode       WRITE setPmddlLinkMode       NOTIFY pmddlLinkModeChanged)
    Q_PROPERTY(QString pmddlRemoteIP       READ pmddlRemoteIP       WRITE setPmddlRemoteIP       NOTIFY pmddlRemoteIPChanged)
    Q_PROPERTY(int     pmddlDataPort       READ pmddlDataPort       WRITE setPmddlDataPort       NOTIFY pmddlDataPortChanged)
    Q_PROPERTY(bool    pmddlEncryptEnabled READ pmddlEncryptEnabled WRITE setPmddlEncryptEnabled NOTIFY pmddlEncryptEnabledChanged)
    Q_PROPERTY(QString pmddlStatusText     READ pmddlStatusText                                  NOTIFY pmddlStatusTextChanged)

    // High-Speed Ethernet Log & Payload Data Offload
    Q_PROPERTY(bool    ethernetLogEnabled      READ ethernetLogEnabled      WRITE setEthernetLogEnabled      NOTIFY ethernetLogEnabledChanged)
    Q_PROPERTY(QString ethernetLogDroneIP      READ ethernetLogDroneIP      WRITE setEthernetLogDroneIP      NOTIFY ethernetLogDroneIPChanged)
    Q_PROPERTY(int     ethernetLogPort         READ ethernetLogPort         WRITE setEthernetLogPort         NOTIFY ethernetLogPortChanged)
    Q_PROPERTY(int     ethernetLogHttpPort     READ ethernetLogHttpPort     WRITE setEthernetLogHttpPort     NOTIFY ethernetLogHttpPortChanged)
    Q_PROPERTY(QString ethernetLogProtocol     READ ethernetLogProtocol     WRITE setEthernetLogProtocol     NOTIFY ethernetLogProtocolChanged)
    Q_PROPERTY(bool    ethernetLogAutoOffload  READ ethernetLogAutoOffload  WRITE setEthernetLogAutoOffload  NOTIFY ethernetLogAutoOffloadChanged)

public:
    explicit CompanyNetworkSettings(QObject *parent = nullptr);
    ~CompanyNetworkSettings() override = default;

    static CompanyNetworkSettings *instance();

    // Getters
    QString thermalVideoUrl() const     { return _thermalVideoUrl; }
    int     thermalVideoPort() const    { return _thermalVideoPort; }
    QString thermalVideoType() const    { return _thermalVideoType; }

    bool    udpTelemetryEnabled() const { return _udpTelemetryEnabled; }
    QString udpTelemetryDestIP() const  { return _udpTelemetryDestIP; }
    int     udpTelemetryDestPort() const{ return _udpTelemetryDestPort; }
    int     udpTelemetryRateHz() const  { return _udpTelemetryRateHz; }

    QString pmddlLinkMode() const       { return _pmddlLinkMode; }
    QString pmddlRemoteIP() const       { return _pmddlRemoteIP; }
    int     pmddlDataPort() const       { return _pmddlDataPort; }
    bool    pmddlEncryptEnabled() const { return _pmddlEncryptEnabled; }
    QString pmddlStatusText() const;

    bool    ethernetLogEnabled() const     { return _ethernetLogEnabled; }
    QString ethernetLogDroneIP() const     { return _ethernetLogDroneIP; }
    int     ethernetLogPort() const        { return _ethernetLogPort; }
    int     ethernetLogHttpPort() const    { return _ethernetLogHttpPort; }
    QString ethernetLogProtocol() const    { return _ethernetLogProtocol; }
    bool    ethernetLogAutoOffload() const { return _ethernetLogAutoOffload; }

    // Setters
    Q_INVOKABLE void setThermalVideoUrl(const QString &url);
    Q_INVOKABLE void setThermalVideoPort(int port);
    Q_INVOKABLE void setThermalVideoType(const QString &type);

    Q_INVOKABLE void setUdpTelemetryEnabled(bool enabled);
    Q_INVOKABLE void setUdpTelemetryDestIP(const QString &ip);
    Q_INVOKABLE void setUdpTelemetryDestPort(int port);
    Q_INVOKABLE void setUdpTelemetryRateHz(int rateHz);

    Q_INVOKABLE void setPmddlLinkMode(const QString &mode);
    Q_INVOKABLE void setPmddlRemoteIP(const QString &ip);
    Q_INVOKABLE void setPmddlDataPort(int port);
    Q_INVOKABLE void setPmddlEncryptEnabled(bool enabled);

    Q_INVOKABLE void setEthernetLogEnabled(bool enabled);
    Q_INVOKABLE void setEthernetLogDroneIP(const QString &ip);
    Q_INVOKABLE void setEthernetLogPort(int port);
    Q_INVOKABLE void setEthernetLogHttpPort(int port);
    Q_INVOKABLE void setEthernetLogProtocol(const QString &protocol);
    Q_INVOKABLE void setEthernetLogAutoOffload(bool autoOffload);

    // Validation Helpers
    Q_INVOKABLE bool isValidIPv4(const QString &ip) const;
    Q_INVOKABLE bool isValidPort(int port) const;
    Q_INVOKABLE bool isValidHost(const QString &host) const;

    // Persistence
    Q_INVOKABLE void loadSettings();
    Q_INVOKABLE void saveSettings();

signals:
    void thermalVideoUrlChanged(const QString &url);
    void thermalVideoPortChanged(int port);
    void thermalVideoTypeChanged(const QString &type);

    void udpTelemetryEnabledChanged(bool enabled);
    void udpTelemetryDestIPChanged(const QString &ip);
    void udpTelemetryDestPortChanged(int port);
    void udpTelemetryRateHzChanged(int rateHz);

    void pmddlLinkModeChanged(const QString &mode);
    void pmddlRemoteIPChanged(const QString &ip);
    void pmddlDataPortChanged(int port);
    void pmddlEncryptEnabledChanged(bool enabled);
    void pmddlStatusTextChanged();

    void ethernetLogEnabledChanged(bool enabled);
    void ethernetLogDroneIPChanged(const QString &ip);
    void ethernetLogPortChanged(int port);
    void ethernetLogHttpPortChanged(int port);
    void ethernetLogProtocolChanged(const QString &protocol);
    void ethernetLogAutoOffloadChanged(bool autoOffload);

private:
    void _syncWithQGCSettings();

    // Thermal Video
    QString _thermalVideoUrl     = QStringLiteral("rtsp://127.0.0.1:8554/thermal");
    int     _thermalVideoPort    = 8554;
    QString _thermalVideoType    = QStringLiteral("RTSP");

    // UDP Telemetry Broadcast
    bool    _udpTelemetryEnabled = false;
    QString _udpTelemetryDestIP  = QStringLiteral("127.0.0.1");
    int     _udpTelemetryDestPort= 14445;
    int     _udpTelemetryRateHz  = 5;

    // PMDDL Interface Boundaries
    QString _pmddlLinkMode       = QStringLiteral("STANDBY");
    QString _pmddlRemoteIP       = QStringLiteral("192.168.1.10");
    int     _pmddlDataPort       = 14555;
    bool    _pmddlEncryptEnabled = false;

    // High-Speed Ethernet Log & Payload Offload
    bool    _ethernetLogEnabled     = true;
    QString _ethernetLogDroneIP     = QStringLiteral("192.168.168.2");
    int     _ethernetLogPort        = 14550;
    int     _ethernetLogHttpPort    = 8080;
    QString _ethernetLogProtocol    = QStringLiteral("MAVLink FTP (UDP)");
    bool    _ethernetLogAutoOffload = true;
};
