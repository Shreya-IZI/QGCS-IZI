#include "CompanyDataOutput.h"

#include <cmath>

#include <QtCore/QApplicationStatic>
#include <QtCore/QDateTime>
#include <QtCore/QJsonDocument>
#include <QtCore/QJsonObject>
#include <QtCore/QJsonValue>
#include <QtNetwork/QHostAddress>

#include "CompanyCsvLogger.h"
#include "CompanyNetworkSettings.h"
#include "CompanyPayloadInterface.h"
#include "Gimbal.h"
#include "GimbalController.h"
#include "MultiVehicleManager.h"
#include "QGCLoggingCategory.h"
#include "Vehicle.h"
#include "VehicleGPSFactGroup.h"
#include "VideoManager.h"

QGC_LOGGING_CATEGORY(CompanyDataOutputLog, "Company.DataOutput")

Q_APPLICATION_STATIC(CompanyDataOutput, _companyDataOutputInstance);

CompanyDataOutput *CompanyDataOutput::instance()
{
    return _companyDataOutputInstance();
}

CompanyDataOutput::CompanyDataOutput(QObject *parent)
    : QObject(parent)
{
    _networkSettings = CompanyNetworkSettings::instance();

    // Connect to network settings changes
    if (_networkSettings) {
        connect(_networkSettings, &CompanyNetworkSettings::udpTelemetryEnabledChanged,
                this, &CompanyDataOutput::_onSettingsChanged);
        connect(_networkSettings, &CompanyNetworkSettings::udpTelemetryDestIPChanged,
                this, &CompanyDataOutput::_onSettingsChanged);
        connect(_networkSettings, &CompanyNetworkSettings::udpTelemetryDestPortChanged,
                this, &CompanyDataOutput::_onSettingsChanged);
        connect(_networkSettings, &CompanyNetworkSettings::udpTelemetryRateHzChanged,
                this, &CompanyDataOutput::_onSettingsChanged);
    }

    // Connect to vehicle lifecycle
    MultiVehicleManager *mvm = MultiVehicleManager::instance();
    if (mvm) {
        connect(mvm, &MultiVehicleManager::activeVehicleChanged,
                this, &CompanyDataOutput::_onActiveVehicleChanged);
        _activeVehicle = mvm->activeVehicle();
    }

    // Configure periodic transmission timer
    connect(&_timer, &QTimer::timeout, this, &CompanyDataOutput::_onPeriodicTimeout);

    _onSettingsChanged();
    qCDebug(CompanyDataOutputLog) << "CompanyDataOutput initialized";
}

void CompanyDataOutput::_onActiveVehicleChanged(Vehicle *vehicle)
{
    _activeVehicle = vehicle;
    qCDebug(CompanyDataOutputLog) << "Active vehicle changed to:" << (vehicle ? vehicle->id() : 0);
}

void CompanyDataOutput::_onSettingsChanged()
{
    if (!_networkSettings) {
        return;
    }

    const QString newIP = _networkSettings->udpTelemetryDestIP();
    const int newPort = _networkSettings->udpTelemetryDestPort();
    const int newRate = _networkSettings->udpTelemetryRateHz();
    const bool shouldStream = _networkSettings->udpTelemetryEnabled();

    if (_destinationIP != newIP || _destinationPort != newPort) {
        _destinationIP = newIP;
        _destinationPort = newPort;
        emit destinationChanged();
    }

    if (_currentRateHz != newRate) {
        _currentRateHz = newRate;
        _updateTimerRate(_currentRateHz);
        emit currentRateHzChanged(_currentRateHz);
    }

    if (shouldStream && !_isStreaming) {
        startOutput();
    } else if (!shouldStream && _isStreaming) {
        stopOutput();
    }
}

void CompanyDataOutput::_updateTimerRate(int rateHz)
{
    if (rateHz < 1) rateHz = 1;
    if (rateHz > 50) rateHz = 50;

    const int intervalMs = 1000 / rateHz;
    _timer.setInterval(intervalMs);
    qCDebug(CompanyDataOutputLog) << "Timer rate updated to" << rateHz << "Hz (" << intervalMs << "ms)";
}

void CompanyDataOutput::startOutput()
{
    if (!_networkSettings) {
        return;
    }

    // Validate settings before arming broadcast
    if (!_networkSettings->isValidIPv4(_destinationIP)) {
        _lastError = QStringLiteral("Invalid destination IPv4 address: %1").arg(_destinationIP);
        emit lastErrorChanged(_lastError);
        qCWarning(CompanyDataOutputLog) << _lastError;
        return;
    }

    if (!_networkSettings->isValidPort(_destinationPort)) {
        _lastError = QStringLiteral("Invalid destination UDP port: %1").arg(_destinationPort);
        emit lastErrorChanged(_lastError);
        qCWarning(CompanyDataOutputLog) << _lastError;
        return;
    }

    _updateTimerRate(_currentRateHz);
    _timer.start();
    _isStreaming = true;
    _lastError.clear();
    emit lastErrorChanged(_lastError);
    emit streamingChanged(true);

    qCDebug(CompanyDataOutputLog) << "Started UDP telemetry output to"
                                 << _destinationIP << ":" << _destinationPort
                                 << "at" << _currentRateHz << "Hz";
}

void CompanyDataOutput::stopOutput()
{
    _timer.stop();
    _isStreaming = false;
    emit streamingChanged(false);

    qCDebug(CompanyDataOutputLog) << "Stopped UDP telemetry output";
}

void CompanyDataOutput::sendSinglePacket()
{
    _transmitPacket();
}

void CompanyDataOutput::_onPeriodicTimeout()
{
    if (!_isStreaming) {
        return;
    }

    _transmitPacket();
}

void CompanyDataOutput::_transmitPacket()
{
    if (!_networkSettings || !_networkSettings->udpTelemetryEnabled()) {
        return;
    }

    if (!_networkSettings->isValidIPv4(_destinationIP) || !_networkSettings->isValidPort(_destinationPort)) {
        _lastError = QStringLiteral("Validation failure: cannot transmit to %1:%2").arg(_destinationIP).arg(_destinationPort);
        emit lastErrorChanged(_lastError);
        return;
    }

    Vehicle *vehicle = _activeVehicle;
    if (!vehicle) {
        MultiVehicleManager *mvm = MultiVehicleManager::instance();
        if (mvm) {
            vehicle = mvm->activeVehicle();
            _activeVehicle = vehicle;
        }
    }

    const QByteArray datagram = _buildTelemetryPayload(vehicle);
    if (datagram.isEmpty()) {
        return;
    }

    const qint64 bytesWritten = _udpSocket.writeDatagram(
        datagram,
        QHostAddress(_destinationIP),
        static_cast<quint16>(_destinationPort)
    );

    if (bytesWritten > 0) {
        _packetsSent++;
        _bytesSent += bytesWritten;
        _lastPacketSample = QString::fromUtf8(datagram);
        _lastError.clear();

        emit metricsChanged();
        emit lastPacketSampleChanged(_lastPacketSample);
        emit lastErrorChanged(_lastError);
    } else {
        _lastError = _udpSocket.errorString();
        emit lastErrorChanged(_lastError);
        qCWarning(CompanyDataOutputLog) << "Failed to send UDP datagram:" << _lastError;
    }
}

QByteArray CompanyDataOutput::_buildTelemetryPayload(Vehicle *vehicle)
{
    CompanyCsvLogger *csv = CompanyCsvLogger::instance();

    QJsonObject rootObj;

    // 1. Packet Protocol Header (Explicitly labeled as test format pending DRDO ICD)
    QJsonObject headerObj;
    headerObj[QStringLiteral("protocol")]        = QStringLiteral("IZI_TEST_TELEMETRY_V1");
    headerObj[QStringLiteral("icd_status")]      = QStringLiteral("PENDING_DRDO_ICD_SPECIFICATION");
    headerObj[QStringLiteral("timestamp_utc")]   = QDateTime::currentDateTimeUtc().toString(QStringLiteral("yyyy-MM-ddTHH:mm:ss.zzzZ"));
    headerObj[QStringLiteral("sequence_number")] = static_cast<qint64>(_sequenceNumber++);
    headerObj[QStringLiteral("system_id")]       = vehicle ? vehicle->id() : 0;
    rootObj[QStringLiteral("header")] = headerObj;

    // 2. GPS Navigation (Latitude, Longitude, Altitude, Satellites, DOP)
    QJsonObject gpsObj;
    if (vehicle) {
        const QGeoCoordinate coord = vehicle->coordinate();
        const bool hasCoord = coord.isValid() && (std::abs(coord.latitude()) > 0.000001 || std::abs(coord.longitude()) > 0.000001);
        gpsObj[QStringLiteral("valid")]         = hasCoord;
        gpsObj[QStringLiteral("latitude_deg")]  = hasCoord ? coord.latitude() : 0.0;
        gpsObj[QStringLiteral("longitude_deg")] = hasCoord ? coord.longitude() : 0.0;

        const double amsl = vehicle->altitudeAMSL() ? vehicle->altitudeAMSL()->rawValue().toDouble() : 0.0;
        const double rel  = vehicle->altitudeRelative() ? vehicle->altitudeRelative()->rawValue().toDouble() : 0.0;
        gpsObj[QStringLiteral("alt_amsl_m")]    = amsl;
        gpsObj[QStringLiteral("alt_rel_m")]     = rel;

        int sats = 0;
        double hdop = 99.0;
        double vdop = 99.0;
        VehicleGPSFactGroup *gpsGroup = qobject_cast<VehicleGPSFactGroup*>(vehicle->gpsFactGroup());
        if (gpsGroup) {
            if (gpsGroup->count()) sats = gpsGroup->count()->rawValue().toInt();
            if (gpsGroup->hdop())  hdop = gpsGroup->hdop()->rawValue().toDouble();
            if (gpsGroup->vdop())  vdop = gpsGroup->vdop()->rawValue().toDouble();
        }
        gpsObj[QStringLiteral("satellites")]    = sats;
        gpsObj[QStringLiteral("hdop")]          = (hdop < 90.0) ? hdop : 0.0;
        gpsObj[QStringLiteral("vdop")]          = (vdop < 90.0) ? vdop : 0.0;
    } else {
        gpsObj[QStringLiteral("valid")]         = false;
        gpsObj[QStringLiteral("latitude_deg")]  = 0.0;
        gpsObj[QStringLiteral("longitude_deg")] = 0.0;
        gpsObj[QStringLiteral("alt_amsl_m")]    = 0.0;
        gpsObj[QStringLiteral("alt_rel_m")]     = 0.0;
        gpsObj[QStringLiteral("satellites")]    = 0;
        gpsObj[QStringLiteral("hdop")]          = 0.0;
        gpsObj[QStringLiteral("vdop")]          = 0.0;
    }
    rootObj[QStringLiteral("gps")] = gpsObj;

    // 3. Autopilot Attitude & State (Pitch, Roll, Yaw, Mode, Armed)
    QJsonObject apObj;
    if (vehicle) {
        apObj[QStringLiteral("pitch_deg")]   = vehicle->pitch() ? vehicle->pitch()->rawValue().toDouble() : 0.0;
        apObj[QStringLiteral("roll_deg")]    = vehicle->roll() ? vehicle->roll()->rawValue().toDouble() : 0.0;
        apObj[QStringLiteral("yaw_deg")]     = vehicle->heading() ? vehicle->heading()->rawValue().toDouble() : 0.0;
        apObj[QStringLiteral("flight_mode")] = vehicle->flightMode();
        apObj[QStringLiteral("armed")]       = vehicle->armed();
    } else {
        apObj[QStringLiteral("pitch_deg")]   = 0.0;
        apObj[QStringLiteral("roll_deg")]    = 0.0;
        apObj[QStringLiteral("yaw_deg")]     = 0.0;
        apObj[QStringLiteral("flight_mode")] = QStringLiteral("STANDBY");
        apObj[QStringLiteral("armed")]       = false;
    }
    rootObj[QStringLiteral("autopilot")] = apObj;

    // 4. Gimbal Attitude (Pitch, Roll, Yaw)
    QJsonObject gimbalObj;
    CompanyPayloadInterface *payload = CompanyPayloadInterface::instance();
    if (csv && csv->hasGimbalAttitude()) {
        gimbalObj[QStringLiteral("available")] = true;
        gimbalObj[QStringLiteral("pitch_deg")] = csv->lastGimbalPitch();
        gimbalObj[QStringLiteral("roll_deg")]  = csv->lastGimbalRoll();
        gimbalObj[QStringLiteral("yaw_deg")]   = csv->lastGimbalYaw();
    } else if (vehicle && vehicle->gimbalController() && vehicle->gimbalController()->activeGimbal()) {
        Gimbal *gimbal = vehicle->gimbalController()->activeGimbal();
        const double gp = (gimbal->absolutePitch() && !std::isnan(gimbal->absolutePitch()->rawValue().toDouble())) ? gimbal->absolutePitch()->rawValue().toDouble() : 0.0;
        const double gr = (gimbal->absoluteRoll() && !std::isnan(gimbal->absoluteRoll()->rawValue().toDouble())) ? gimbal->absoluteRoll()->rawValue().toDouble() : 0.0;
        const double gy = (gimbal->absoluteYaw() && !std::isnan(gimbal->absoluteYaw()->rawValue().toDouble())) ? gimbal->absoluteYaw()->rawValue().toDouble() : 0.0;
        gimbalObj[QStringLiteral("available")] = true;
        gimbalObj[QStringLiteral("pitch_deg")] = gp;
        gimbalObj[QStringLiteral("roll_deg")]  = gr;
        gimbalObj[QStringLiteral("yaw_deg")]   = gy;
    } else if (payload) {
        gimbalObj[QStringLiteral("available")] = true;
        gimbalObj[QStringLiteral("pitch_deg")] = payload->pitch();
        gimbalObj[QStringLiteral("roll_deg")]  = payload->roll();
        gimbalObj[QStringLiteral("yaw_deg")]   = payload->yaw();
    } else {
        gimbalObj[QStringLiteral("available")] = false;
        gimbalObj[QStringLiteral("pitch_deg")] = 0.0;
        gimbalObj[QStringLiteral("roll_deg")]  = 0.0;
        gimbalObj[QStringLiteral("yaw_deg")]   = 0.0;
    }
    rootObj[QStringLiteral("gimbal")] = gimbalObj;

    // 5. Laser Rangefinder (LRF Distance)
    QJsonObject lrfObj;
    if (payload && payload->lrfValid() && payload->lrfDistance() > 0.01f) {
        lrfObj[QStringLiteral("available")]  = true;
        lrfObj[QStringLiteral("distance_m")] = payload->lrfDistance();
    } else if (csv && csv->hasLrfDistance() && csv->lastLrfDistance() > 0.01) {
        lrfObj[QStringLiteral("available")]  = true;
        lrfObj[QStringLiteral("distance_m")] = csv->lastLrfDistance();
    } else if (vehicle && vehicle->rangeFinderDist() && vehicle->rangeFinderDist()->rawValue().toDouble() > 0.01) {
        lrfObj[QStringLiteral("available")]  = true;
        lrfObj[QStringLiteral("distance_m")] = vehicle->rangeFinderDist()->rawValue().toDouble();
    } else {
        lrfObj[QStringLiteral("available")]  = false;
        lrfObj[QStringLiteral("distance_m")] = 0.0;
    }
    rootObj[QStringLiteral("lrf")] = lrfObj;

    // 6. Barometer (Pressure & Relative Altitude)
    QJsonObject baroObj;
    if (csv && csv->hasBaroPressure()) {
        baroObj[QStringLiteral("available")]    = true;
        baroObj[QStringLiteral("pressure_hpa")] = csv->lastBaroPressure();
    } else {
        baroObj[QStringLiteral("available")]    = false;
        baroObj[QStringLiteral("pressure_hpa")] = 0.0;
    }
    baroObj[QStringLiteral("altitude_m")] = (vehicle && vehicle->altitudeRelative()) ? vehicle->altitudeRelative()->rawValue().toDouble() : 0.0;
    rootObj[QStringLiteral("barometer")] = baroObj;

    // 7. Magnetometer (MagX, MagY, MagZ in mG)
    QJsonObject magObj;
    if (csv && csv->hasMag()) {
        magObj[QStringLiteral("available")] = true;
        magObj[QStringLiteral("mag_x_mg")]  = csv->lastMagX();
        magObj[QStringLiteral("mag_y_mg")]  = csv->lastMagY();
        magObj[QStringLiteral("mag_z_mg")]  = csv->lastMagZ();
    } else {
        magObj[QStringLiteral("available")] = false;
        magObj[QStringLiteral("mag_x_mg")]  = 0.0;
        magObj[QStringLiteral("mag_y_mg")]  = 0.0;
        magObj[QStringLiteral("mag_z_mg")]  = 0.0;
    }
    rootObj[QStringLiteral("magnetometer")] = magObj;

    // 8. Payload Optics (Horizontal FOV)
    QJsonObject payloadObj;
    if (payload && payload->fov() > 0.1f) {
        payloadObj[QStringLiteral("fov_deg")] = payload->fov();
    } else {
        VideoManager *vm = VideoManager::instance();
        if (vm && vm->hfov() > 1.0) {
            payloadObj[QStringLiteral("fov_deg")] = vm->hfov();
        } else {
            payloadObj[QStringLiteral("fov_deg")] = 0.0;
        }
    }
    if (payload) {
        payloadObj[QStringLiteral("simulation")] = payload->isSimulation();
        payloadObj[QStringLiteral("model")]      = payload->payloadModel();
    }
    rootObj[QStringLiteral("payload")] = payloadObj;

    const QJsonDocument doc(rootObj);
    return doc.toJson(QJsonDocument::Compact);
}
