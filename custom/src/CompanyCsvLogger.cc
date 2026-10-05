#include "CompanyCsvLogger.h"

#include <cmath>

#include <QtCore/QApplicationStatic>
#include <QtCore/QDateTime>
#include <QtCore/QDir>
#include <QtCore/QFileInfo>
#include <QtCore/QStandardPaths>
#include <QtCore/QUrl>
#include <QtGui/QDesktopServices>

#include "AppSettings.h"
#include "Fact.h"
#include "Gimbal.h"
#include "GimbalController.h"
#include "MavlinkSettings.h"
#include "MultiVehicleManager.h"
#include "CompanyPayloadInterface.h"
#include "QGCLoggingCategory.h"
#include "SettingsManager.h"
#include "Vehicle.h"
#include "VehicleGPSFactGroup.h"
#include "VideoManager.h"

QGC_LOGGING_CATEGORY(CompanyCsvLoggerLog, "Company.CsvLogger")

Q_APPLICATION_STATIC(CompanyCsvLogger, _companyCsvLoggerInstance);

CompanyCsvLogger *CompanyCsvLogger::instance()
{
    return _companyCsvLoggerInstance();
}

CompanyCsvLogger::CompanyCsvLogger(QObject *parent)
    : QObject(parent)
{
    connect(&_timer, &QTimer::timeout, this, &CompanyCsvLogger::_onPeriodicTimeout);

    // Track active vehicle changes
    MultiVehicleManager *multiVehicleMgr = MultiVehicleManager::instance();
    if (multiVehicleMgr) {
        connect(multiVehicleMgr, &MultiVehicleManager::activeVehicleChanged,
                this, &CompanyCsvLogger::_onActiveVehicleChanged);
        if (multiVehicleMgr->activeVehicle()) {
            _connectVehicle(multiVehicleMgr->activeVehicle());
        }
    }

    // Connect to VideoManager signals for automated event capture
    VideoManager *videoMgr = VideoManager::instance();
    if (videoMgr) {
        connect(videoMgr, &VideoManager::imageFileChanged,
                this, &CompanyCsvLogger::_onVideoImageFileChanged);
        connect(videoMgr, &VideoManager::recordingChanged,
                this, &CompanyCsvLogger::_onVideoRecordingChanged);
    }

    qCDebug(CompanyCsvLoggerLog) << "CompanyCsvLogger initialized";
}

CompanyCsvLogger::~CompanyCsvLogger()
{
    _closeTelemetryCsv();
    _disconnectVehicle();
}

QString CompanyCsvLogger::logSavePath() const
{
    SettingsManager *sm = SettingsManager::instance();
    if (sm && sm->appSettings()) {
        const QString p = sm->appSettings()->telemetrySavePath();
        QDir d(p);
        if (d.exists() || d.mkpath(QStringLiteral("."))) {
            return p;
        }
    }
    const QString docPath = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation) + QStringLiteral("/QGroundControl/Telemetry");
    QDir dDoc(docPath);
    if (dDoc.exists() || dDoc.mkpath(QStringLiteral("."))) {
        return docPath;
    }
    const QString tempPath = QDir::tempPath() + QStringLiteral("/QGroundControl/Telemetry");
    QDir dTemp(tempPath);
    dTemp.mkpath(QStringLiteral("."));
    return tempPath;
}

double CompanyCsvLogger::lastLrfDistance() const
{
    if (_hasLrfDistance && _lastLrfDistance > 0.01) {
        return _lastLrfDistance;
    }
    if (CompanyPayloadInterface::instance() && CompanyPayloadInterface::instance()->lrfValid()) {
        return CompanyPayloadInterface::instance()->lrfDistance();
    }
    return _lastLrfDistance;
}

bool CompanyCsvLogger::hasLrfDistance() const
{
    if (_hasLrfDistance) {
        return true;
    }
    return (CompanyPayloadInterface::instance() && CompanyPayloadInterface::instance()->lrfValid() && CompanyPayloadInterface::instance()->lrfDistance() > 0.01f);
}

double CompanyCsvLogger::lastGimbalPitch() const
{
    if (_hasGimbalAttitude) {
        return _lastGimbalPitch;
    }
    if (CompanyPayloadInterface::instance()) {
        return CompanyPayloadInterface::instance()->pitch();
    }
    return 0.0;
}

double CompanyCsvLogger::lastGimbalRoll() const
{
    if (_hasGimbalAttitude) {
        return _lastGimbalRoll;
    }
    if (CompanyPayloadInterface::instance()) {
        return CompanyPayloadInterface::instance()->roll();
    }
    return 0.0;
}

double CompanyCsvLogger::lastGimbalYaw() const
{
    if (_hasGimbalAttitude) {
        return _lastGimbalYaw;
    }
    if (CompanyPayloadInterface::instance()) {
        return CompanyPayloadInterface::instance()->yaw();
    }
    return 0.0;
}

bool CompanyCsvLogger::hasGimbalAttitude() const
{
    if (_hasGimbalAttitude) {
        return true;
    }
    return (CompanyPayloadInterface::instance() != nullptr);
}

bool CompanyCsvLogger::hasDroneGpsTime() const
{
    return _hasDroneGpsTime && (_droneTimeUsec > 0) && (_lastDroneTimeReceivedMs > 0) &&
           ((QDateTime::currentMSecsSinceEpoch() - _lastDroneTimeReceivedMs) < 10000);
}

qint64 CompanyCsvLogger::currentDroneTimeMs() const
{
    if (hasDroneGpsTime()) {
        const qint64 elapsedSinceLastMsg = QDateTime::currentMSecsSinceEpoch() - _lastDroneTimeReceivedMs;
        return static_cast<qint64>(_droneTimeUsec / 1000ULL) + elapsedSinceLastMsg;
    }
    return QDateTime::currentDateTimeUtc().toMSecsSinceEpoch();
}

QString CompanyCsvLogger::formattedHmsMs() const
{
    const qint64 tMs = currentDroneTimeMs();
    const QDateTime dt = QDateTime::fromMSecsSinceEpoch(tMs, QTimeZone::UTC);
    return dt.toString(QStringLiteral("HH:mm:ss:zzz"));
}

QString CompanyCsvLogger::droneUtcTimestamp() const
{
    const qint64 tMs = currentDroneTimeMs();
    const QDateTime dt = QDateTime::fromMSecsSinceEpoch(tMs, QTimeZone::UTC);
    return dt.toString(QStringLiteral("yyyy-MM-dd HH:mm:ss.zzz Z"));
}

void CompanyCsvLogger::setLoggingActive(bool active)
{
    if (_loggingActive == active) {
        return;
    }

    _loggingActive = active;
    emit loggingActiveChanged(_loggingActive);

    // Keep QGC core mavlinkSettings in sync for operators expecting standard QGC logging
    SettingsManager *sm = SettingsManager::instance();
    if (sm && sm->mavlinkSettings() && sm->mavlinkSettings()->saveCsvTelemetry()) {
        sm->mavlinkSettings()->saveCsvTelemetry()->setRawValue(_loggingActive);
    }

    if (_loggingActive) {
        startLogging();
    } else {
        stopLogging();
    }
}

void CompanyCsvLogger::setLoggingRateHz(int rateHz)
{
    if (rateHz < 1) rateHz = 1;
    if (rateHz > 50) rateHz = 50;

    if (_loggingRateHz != rateHz) {
        _loggingRateHz = rateHz;
        emit loggingRateHzChanged(_loggingRateHz);
        if (_timer.isActive()) {
            _timer.setInterval(1000 / _loggingRateHz);
        }
    }
}

void CompanyCsvLogger::startLogging()
{
    if (!_loggingActive) {
        _loggingActive = true;
        emit loggingActiveChanged(_loggingActive);
    }

    _initializeTelemetryCsv();
    _timer.setInterval(1000 / _loggingRateHz);
    _timer.start();

    qCDebug(CompanyCsvLoggerLog) << "Telemetry CSV logging started at" << _loggingRateHz << "Hz";
}

void CompanyCsvLogger::stopLogging()
{
    _timer.stop();
    _closeTelemetryCsv();

    if (_loggingActive) {
        _loggingActive = false;
        emit loggingActiveChanged(_loggingActive);
    }

    qCDebug(CompanyCsvLoggerLog) << "Telemetry CSV logging stopped";
}

void CompanyCsvLogger::openLogFolder()
{
    const QString path = logSavePath();
    QDir dir(path);
    if (!dir.exists()) {
        dir.mkpath(QStringLiteral("."));
    }
    QDesktopServices::openUrl(QUrl::fromLocalFile(path));
}

void CompanyCsvLogger::_onActiveVehicleChanged(Vehicle *vehicle)
{
    _disconnectVehicle();
    if (vehicle) {
        _connectVehicle(vehicle);
    }
}

void CompanyCsvLogger::_connectVehicle(Vehicle *vehicle)
{
    if (!vehicle) {
        return;
    }
    _currentVehicle = vehicle;
    connect(_currentVehicle, &Vehicle::mavlinkMessageReceived,
            this, &CompanyCsvLogger::_onMavlinkMessageReceived);

    qCDebug(CompanyCsvLoggerLog) << "Connected to Vehicle ID:" << vehicle->id();
}

void CompanyCsvLogger::_disconnectVehicle()
{
    if (_currentVehicle) {
        disconnect(_currentVehicle, &Vehicle::mavlinkMessageReceived,
                   this, &CompanyCsvLogger::_onMavlinkMessageReceived);
        _currentVehicle = nullptr;
    }
    _hasDroneGpsTime = false;
    _droneTimeUsec = 0;
    _lastDroneTimeReceivedMs = 0;
    emit droneTimeChanged();
}

void CompanyCsvLogger::_onMavlinkMessageReceived(const mavlink_message_t &message)
{
    bool sensorUpdated = false;

    switch (message.msgid) {
    case MAVLINK_MSG_ID_SYSTEM_TIME: {
        mavlink_system_time_t st{};
        mavlink_msg_system_time_decode(&message, &st);
        if (st.time_unix_usec > 1000000000000000ULL) {
            _droneTimeUsec = st.time_unix_usec;
            _lastDroneTimeReceivedMs = QDateTime::currentMSecsSinceEpoch();
            _hasDroneGpsTime = true;
            emit droneTimeChanged();
        }
        break;
    }
    case MAVLINK_MSG_ID_GPS_RAW_INT: {
        mavlink_gps_raw_int_t gps{};
        mavlink_msg_gps_raw_int_decode(&message, &gps);
        if (gps.time_usec > 1000000000000000ULL) {
            _droneTimeUsec = gps.time_usec;
            _lastDroneTimeReceivedMs = QDateTime::currentMSecsSinceEpoch();
            _hasDroneGpsTime = true;
            emit droneTimeChanged();
        }
        break;
    }
    case MAVLINK_MSG_ID_SCALED_PRESSURE: {
        mavlink_scaled_pressure_t p{};
        mavlink_msg_scaled_pressure_decode(&message, &p);
        _lastBaroPressure = p.press_abs;
        _hasBaroPressure = true;
        sensorUpdated = true;
        break;
    }
    case MAVLINK_MSG_ID_RAW_IMU: {
        mavlink_raw_imu_t imu{};
        mavlink_msg_raw_imu_decode(&message, &imu);
        _lastMagX = imu.xmag;
        _lastMagY = imu.ymag;
        _lastMagZ = imu.zmag;
        _hasMag = true;
        sensorUpdated = true;
        break;
    }
    case MAVLINK_MSG_ID_SCALED_IMU: {
        mavlink_scaled_imu_t simu{};
        mavlink_msg_scaled_imu_decode(&message, &simu);
        _lastMagX = simu.xmag;
        _lastMagY = simu.ymag;
        _lastMagZ = simu.zmag;
        _hasMag = true;
        sensorUpdated = true;
        break;
    }
    case MAVLINK_MSG_ID_HIGHRES_IMU: {
        mavlink_highres_imu_t himu{};
        mavlink_msg_highres_imu_decode(&message, &himu);
        if (himu.fields_updated & 0x01C0) {
            _lastMagX = himu.xmag * 1000.0;
            _lastMagY = himu.ymag * 1000.0;
            _lastMagZ = himu.zmag * 1000.0;
            _hasMag = true;
            sensorUpdated = true;
        }
        if (himu.fields_updated & 0x0200) {
            _lastBaroPressure = himu.abs_pressure;
            _hasBaroPressure = true;
            sensorUpdated = true;
        }
        break;
    }
    case MAVLINK_MSG_ID_RANGEFINDER: {
        mavlink_rangefinder_t rf{};
        mavlink_msg_rangefinder_decode(&message, &rf);
        _lastLrfDistance = rf.distance;
        _hasLrfDistance = true;
        sensorUpdated = true;
        break;
    }
    case MAVLINK_MSG_ID_DISTANCE_SENSOR: {
        mavlink_distance_sensor_t ds{};
        mavlink_msg_distance_sensor_decode(&message, &ds);
        if (ds.orientation == MAV_SENSOR_ROTATION_PITCH_270 || ds.orientation == MAV_SENSOR_ROTATION_NONE) {
            _lastLrfDistance = ds.current_distance * 0.01;
            _hasLrfDistance = true;
            sensorUpdated = true;
        }
        break;
    }
    case MAVLINK_MSG_ID_MOUNT_STATUS: {
        mavlink_mount_status_t ms{};
        mavlink_msg_mount_status_decode(&message, &ms);
        _lastGimbalPitch = ms.pointing_a * 0.01;
        _lastGimbalRoll  = ms.pointing_b * 0.01;
        _lastGimbalYaw   = ms.pointing_c * 0.01;
        _hasGimbalAttitude = true;
        sensorUpdated = true;
        break;
    }
    default:
        break;
    }

    if (sensorUpdated) {
        emit rawSensorsChanged();
    }
}

void CompanyCsvLogger::_initializeTelemetryCsv()
{
    if (_csvFile.isOpen()) {
        return;
    }

    const QString dirPath = logSavePath();
    QDir dir(dirPath);
    if (!dir.exists()) {
        dir.mkpath(QStringLiteral("."));
    }

    const QString nowStr = QDateTime::currentDateTimeUtc().toString("yyyy-MM-dd_HH-mm-ss");
    const int sysId = _currentVehicle ? _currentVehicle->id() : 1;
    _currentLogFileName = QStringLiteral("%1_vehicle%2_chandipur_telemetry.csv").arg(nowStr).arg(sysId);

    _csvFile.setFileName(dir.absoluteFilePath(_currentLogFileName));
    if (!_csvFile.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Append)) {
        qCWarning(CompanyCsvLoggerLog) << "Failed to open CSV file:" << _csvFile.fileName();
        return;
    }

    _csvStream.setDevice(&_csvFile);
    _writeHeader();

    _samplesLogged = 0;
    emit samplesLoggedChanged(_samplesLogged);
    emit currentLogFileNameChanged(_currentLogFileName);

    qCDebug(CompanyCsvLoggerLog) << "Opened CSV telemetry log:" << _csvFile.fileName();
}

void CompanyCsvLogger::_closeTelemetryCsv()
{
    if (_csvFile.isOpen()) {
        _csvStream.flush();
        _csvFile.close();
        qCDebug(CompanyCsvLoggerLog) << "Closed CSV telemetry log. Total samples:" << _samplesLogged;
    }
}

void CompanyCsvLogger::_writeHeader()
{
    if (!_csvFile.isOpen()) {
        return;
    }

    _csvStream << "Timestamp,"
               << "Event,"
               << "Latitude_deg,"
               << "Longitude_deg,"
               << "AltAMSL_m,"
               << "AltRel_m,"
               << "Satellites,"
               << "HDOP,"
               << "VDOP,"
               << "Pitch_deg,"
               << "Roll_deg,"
               << "Yaw_deg,"
               << "GimbalPitch_deg,"
               << "GimbalRoll_deg,"
               << "GimbalYaw_deg,"
               << "LRF_Distance_m,"
               << "BaroPressure_hPa,"
               << "MagX_mG,"
               << "MagY_mG,"
               << "MagZ_mG,"
               << "FOV_deg,"
               << "EventDetails\n";
    _csvStream.flush();
}

void CompanyCsvLogger::_onPeriodicTimeout()
{
    if (!_loggingActive || !_csvFile.isOpen()) {
        return;
    }

    _writeTelemetryRow();
}

void CompanyCsvLogger::_writeTelemetryRow()
{
    if (!_currentVehicle) {
        return;
    }

    const QString nowIso = QDateTime::currentDateTimeUtc().toString(QStringLiteral("yyyy-MM-ddTHH:mm:ss.zzzZ"));

    // 1. GPS Coordinates (defensive check against fake zeros)
    const QGeoCoordinate coord = _currentVehicle->coordinate();
    QString latStr = QStringLiteral("N/A");
    QString lonStr = QStringLiteral("N/A");
    if (coord.isValid() && (std::abs(coord.latitude()) > 0.000001 || std::abs(coord.longitude()) > 0.000001)) {
        latStr = QString::number(coord.latitude(), 'f', 6);
        lonStr = QString::number(coord.longitude(), 'f', 6);
    }

    // 2. Altitudes
    const double amsl = _currentVehicle->altitudeAMSL() ? _currentVehicle->altitudeAMSL()->rawValue().toDouble() : 0.0;
    const double rel  = _currentVehicle->altitudeRelative() ? _currentVehicle->altitudeRelative()->rawValue().toDouble() : 0.0;
    const QString amslStr = QString::number(amsl, 'f', 1);
    const QString relStr  = QString::number(rel, 'f', 1);

    // 3. Satellites & DOP
    int sats = 0;
    double hdop = 99.0;
    double vdop = 99.0;
    VehicleGPSFactGroup *gpsGroup = qobject_cast<VehicleGPSFactGroup*>(_currentVehicle->gpsFactGroup());
    if (gpsGroup) {
        if (gpsGroup->count()) {
            sats = gpsGroup->count()->rawValue().toInt();
        }
        if (gpsGroup->hdop()) {
            hdop = gpsGroup->hdop()->rawValue().toDouble();
        }
        if (gpsGroup->vdop()) {
            vdop = gpsGroup->vdop()->rawValue().toDouble();
        }
    }
    const QString satsStr = (sats > 0) ? QString::number(sats) : QStringLiteral("0");
    const QString hdopStr = (hdop < 90.0) ? QString::number(hdop, 'f', 2) : QStringLiteral("N/A");
    const QString vdopStr = (vdop < 90.0) ? QString::number(vdop, 'f', 2) : QStringLiteral("N/A");

    // 4. Autopilot Attitude
    const double pitch = _currentVehicle->pitch() ? _currentVehicle->pitch()->rawValue().toDouble() : 0.0;
    const double roll  = _currentVehicle->roll() ? _currentVehicle->roll()->rawValue().toDouble() : 0.0;
    const double yaw   = _currentVehicle->heading() ? _currentVehicle->heading()->rawValue().toDouble() : 0.0;
    const QString pitchStr = QString::number(pitch, 'f', 1);
    const QString rollStr  = QString::number(roll, 'f', 1);
    const QString yawStr   = QString::number(yaw, 'f', 1);

    // 5. Gimbal Attitude
    QString gPitchStr = QStringLiteral("N/A");
    QString gRollStr  = QStringLiteral("N/A");
    QString gYawStr   = QStringLiteral("N/A");
    if (_hasGimbalAttitude) {
        gPitchStr = QString::number(_lastGimbalPitch, 'f', 1);
        gRollStr  = QString::number(_lastGimbalRoll, 'f', 1);
        gYawStr   = QString::number(_lastGimbalYaw, 'f', 1);
    } else if (_currentVehicle->gimbalController() && _currentVehicle->gimbalController()->activeGimbal()) {
        Gimbal *gimbal = _currentVehicle->gimbalController()->activeGimbal();
        if (gimbal->absolutePitch() && !std::isnan(gimbal->absolutePitch()->rawValue().toDouble())) {
            gPitchStr = QString::number(gimbal->absolutePitch()->rawValue().toDouble(), 'f', 1);
        }
        if (gimbal->absoluteRoll() && !std::isnan(gimbal->absoluteRoll()->rawValue().toDouble())) {
            gRollStr = QString::number(gimbal->absoluteRoll()->rawValue().toDouble(), 'f', 1);
        }
        if (gimbal->absoluteYaw() && !std::isnan(gimbal->absoluteYaw()->rawValue().toDouble())) {
            gYawStr = QString::number(gimbal->absoluteYaw()->rawValue().toDouble(), 'f', 1);
        }
    } else if (CompanyPayloadInterface::instance()) {
        CompanyPayloadInterface *payload = CompanyPayloadInterface::instance();
        gPitchStr = QString::number(payload->pitch(), 'f', 1);
        gRollStr  = QString::number(payload->roll(), 'f', 1);
        gYawStr   = QString::number(payload->yaw(), 'f', 1);
    }

    // 6. LRF Distance
    QString lrfStr = QStringLiteral("N/A");
    if (CompanyPayloadInterface::instance() && CompanyPayloadInterface::instance()->lrfValid() && CompanyPayloadInterface::instance()->lrfDistance() > 0.01f) {
        lrfStr = QString::number(CompanyPayloadInterface::instance()->lrfDistance(), 'f', 2);
    } else if (_hasLrfDistance && _lastLrfDistance > 0.01) {
        lrfStr = QString::number(_lastLrfDistance, 'f', 2);
    } else if (_currentVehicle->rangeFinderDist() && _currentVehicle->rangeFinderDist()->rawValue().toDouble() > 0.01) {
        lrfStr = QString::number(_currentVehicle->rangeFinderDist()->rawValue().toDouble(), 'f', 2);
    }

    // 7. Barometer Absolute Pressure
    const QString baroStr = _hasBaroPressure ? QString::number(_lastBaroPressure, 'f', 2) : QStringLiteral("N/A");

    // 8. Magnetometer Tri-axial Field
    const QString magXStr = _hasMag ? QString::number(_lastMagX, 'f', 1) : QStringLiteral("N/A");
    const QString magYStr = _hasMag ? QString::number(_lastMagY, 'f', 1) : QStringLiteral("N/A");
    const QString magZStr = _hasMag ? QString::number(_lastMagZ, 'f', 1) : QStringLiteral("N/A");

    // 9. Camera FOV
    QString fovStr = QStringLiteral("N/A");
    if (CompanyPayloadInterface::instance() && CompanyPayloadInterface::instance()->fov() > 0.1f) {
        fovStr = QString::number(CompanyPayloadInterface::instance()->fov(), 'f', 1);
    } else {
        VideoManager *vm = VideoManager::instance();
        if (vm && vm->hfov() > 1.0) {
            fovStr = QString::number(vm->hfov(), 'f', 1);
        }
    }

    // 10. Flight Mode
    const QString modeStr = _currentVehicle->flightMode();

    _csvStream << nowIso << ","
               << "TELEMETRY,"
               << latStr << ","
               << lonStr << ","
               << amslStr << ","
               << relStr << ","
               << satsStr << ","
               << hdopStr << ","
               << vdopStr << ","
               << pitchStr << ","
               << rollStr << ","
               << yawStr << ","
               << gPitchStr << ","
               << gRollStr << ","
               << gYawStr << ","
               << lrfStr << ","
               << baroStr << ","
               << magXStr << ","
               << magYStr << ","
               << magZStr << ","
               << fovStr << ","
               << modeStr << "\n";
    _csvStream.flush();

    _samplesLogged++;
    emit samplesLoggedChanged(_samplesLogged);
}

void CompanyCsvLogger::logSnapshotEvent(const QString &fileName,
                                      double lat, double lon,
                                      double altAmsl, double altRel,
                                      double pitch, double roll, double yaw,
                                      double gimbalPitch, double gimbalRoll, double gimbalYaw,
                                      double fov)
{
    const QString nowIso = QDateTime::currentDateTimeUtc().toString(QStringLiteral("yyyy-MM-ddTHH:mm:ss.zzzZ"));

    const QString latStr = (std::abs(lat) > 0.000001) ? QString::number(lat, 'f', 6) : QStringLiteral("N/A");
    const QString lonStr = (std::abs(lon) > 0.000001) ? QString::number(lon, 'f', 6) : QStringLiteral("N/A");
    const QString amslStr = !std::isnan(altAmsl) ? QString::number(altAmsl, 'f', 1) : QStringLiteral("N/A");
    const QString relStr  = !std::isnan(altRel) ? QString::number(altRel, 'f', 1) : QStringLiteral("N/A");
    const QString pitchStr = !std::isnan(pitch) ? QString::number(pitch, 'f', 1) : QStringLiteral("N/A");
    const QString rollStr  = !std::isnan(roll) ? QString::number(roll, 'f', 1) : QStringLiteral("N/A");
    const QString yawStr   = !std::isnan(yaw) ? QString::number(yaw, 'f', 1) : QStringLiteral("N/A");
    const QString gPitchStr = !std::isnan(gimbalPitch) ? QString::number(gimbalPitch, 'f', 1) : QStringLiteral("N/A");
    const QString gRollStr  = !std::isnan(gimbalRoll) ? QString::number(gimbalRoll, 'f', 1) : QStringLiteral("N/A");
    const QString gYawStr   = !std::isnan(gimbalYaw) ? QString::number(gimbalYaw, 'f', 1) : QStringLiteral("N/A");
    const QString fovStr    = (fov > 1.0) ? QString::number(fov, 'f', 1) : QStringLiteral("N/A");

    // Write to continuous telemetry log if open
    if (_csvFile.isOpen()) {
        _csvStream << nowIso << ","
                   << "SNAPSHOT,"
                   << latStr << ","
                   << lonStr << ","
                   << amslStr << ","
                   << relStr << ","
                   << "N/A," // sats
                   << "N/A," // hdop
                   << "N/A," // vdop
                   << pitchStr << ","
                   << rollStr << ","
                   << yawStr << ","
                   << gPitchStr << ","
                   << gRollStr << ","
                   << gYawStr << ","
                   << (_hasLrfDistance ? QString::number(_lastLrfDistance, 'f', 2) : "N/A") << ","
                   << (_hasBaroPressure ? QString::number(_lastBaroPressure, 'f', 2) : "N/A") << ","
                   << (_hasMag ? QString::number(_lastMagX, 'f', 1) : "N/A") << ","
                   << (_hasMag ? QString::number(_lastMagY, 'f', 1) : "N/A") << ","
                   << (_hasMag ? QString::number(_lastMagZ, 'f', 1) : "N/A") << ","
                   << fovStr << ","
                   << fileName << "\n";
        _csvStream.flush();
    }

    // Also append to dedicated snapshots_metadata.csv in photo save path
    SettingsManager *sm = SettingsManager::instance();
    const QString photoDir = (sm && sm->appSettings()) ? sm->appSettings()->photoSavePath() : logSavePath();
    QDir dir(photoDir);
    if (!dir.exists()) {
        dir.mkpath(QStringLiteral("."));
    }

    const QString metaFilePath = dir.absoluteFilePath(QStringLiteral("snapshots_metadata.csv"));
    const bool exists = QFile::exists(metaFilePath);
    QFile metaFile(metaFilePath);
    if (metaFile.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
        QTextStream metaStream(&metaFile);
        if (!exists) {
            metaStream << "Timestamp,Filename,Latitude_deg,Longitude_deg,AltAMSL_m,AltRel_m,"
                       << "Pitch_deg,Roll_deg,Yaw_deg,GimbalPitch_deg,GimbalRoll_deg,GimbalYaw_deg,FOV_deg\n";
        }
        metaStream << nowIso << ","
                   << fileName << ","
                   << latStr << ","
                   << lonStr << ","
                   << amslStr << ","
                   << relStr << ","
                   << pitchStr << ","
                   << rollStr << ","
                   << yawStr << ","
                   << gPitchStr << ","
                   << gRollStr << ","
                   << gYawStr << ","
                   << fovStr << "\n";
        metaStream.flush();
    }

    _eventsLogged++;
    emit eventsLoggedChanged(_eventsLogged);

    qCDebug(CompanyCsvLoggerLog) << "Logged snapshot event:" << fileName << "Lat:" << latStr << "Lon:" << lonStr;
}

void CompanyCsvLogger::logRecordStartEvent(const QString &fileName)
{
    const QString nowIso = QDateTime::currentDateTimeUtc().toString(QStringLiteral("yyyy-MM-ddTHH:mm:ss.zzzZ"));

    if (_csvFile.isOpen()) {
        _csvStream << nowIso << ","
                   << "RECORD_START,"
                   << ",,,,,,,,,,,,,,,," // empty sensor fields
                   << "START: " << fileName << "\n";
        _csvStream.flush();
    }

    _eventsLogged++;
    emit eventsLoggedChanged(_eventsLogged);
    qCDebug(CompanyCsvLoggerLog) << "Logged video record start event:" << fileName;
}

void CompanyCsvLogger::logRecordStopEvent(const QString &fileName, int durationSec)
{
    const QString nowIso = QDateTime::currentDateTimeUtc().toString(QStringLiteral("yyyy-MM-ddTHH:mm:ss.zzzZ"));

    if (_csvFile.isOpen()) {
        _csvStream << nowIso << ","
                   << "RECORD_STOP,"
                   << ",,,,,,,,,,,,,,,," // empty sensor fields
                   << "STOP: " << fileName << " (duration: " << durationSec << "s)\n";
        _csvStream.flush();
    }

    _eventsLogged++;
    emit eventsLoggedChanged(_eventsLogged);
    qCDebug(CompanyCsvLoggerLog) << "Logged video record stop event:" << fileName << "Duration:" << durationSec;
}

void CompanyCsvLogger::_onVideoImageFileChanged(const QString &imageFile)
{
    if (imageFile.isEmpty()) {
        return;
    }

    const QString fileName = QFileInfo(imageFile).fileName();

    double lat = 0.0;
    double lon = 0.0;
    double amsl = 0.0;
    double rel = 0.0;
    double pitch = 0.0;
    double roll = 0.0;
    double yaw = 0.0;
    double gPitch = std::nan("");
    double gRoll  = std::nan("");
    double gYaw   = std::nan("");
    double fov    = std::nan("");

    if (_currentVehicle) {
        const QGeoCoordinate coord = _currentVehicle->coordinate();
        if (coord.isValid()) {
            lat = coord.latitude();
            lon = coord.longitude();
        }
        if (_currentVehicle->altitudeAMSL()) amsl = _currentVehicle->altitudeAMSL()->rawValue().toDouble();
        if (_currentVehicle->altitudeRelative()) rel = _currentVehicle->altitudeRelative()->rawValue().toDouble();
        if (_currentVehicle->pitch()) pitch = _currentVehicle->pitch()->rawValue().toDouble();
        if (_currentVehicle->roll()) roll = _currentVehicle->roll()->rawValue().toDouble();
        if (_currentVehicle->heading()) yaw = _currentVehicle->heading()->rawValue().toDouble();

        if (_hasGimbalAttitude) {
            gPitch = _lastGimbalPitch;
            gRoll = _lastGimbalRoll;
            gYaw = _lastGimbalYaw;
        } else if (_currentVehicle->gimbalController() && _currentVehicle->gimbalController()->activeGimbal()) {
            Gimbal *g = _currentVehicle->gimbalController()->activeGimbal();
            if (g->absolutePitch()) gPitch = g->absolutePitch()->rawValue().toDouble();
            if (g->absoluteRoll())  gRoll  = g->absoluteRoll()->rawValue().toDouble();
            if (g->absoluteYaw())   gYaw   = g->absoluteYaw()->rawValue().toDouble();
        }
    }

    VideoManager *vm = VideoManager::instance();
    if (vm && vm->hfov() > 1.0) {
        fov = vm->hfov();
    }

    logSnapshotEvent(fileName, lat, lon, amsl, rel, pitch, roll, yaw, gPitch, gRoll, gYaw, fov);
}

void CompanyCsvLogger::_onVideoRecordingChanged()
{
    VideoManager *vm = VideoManager::instance();
    if (!vm) {
        return;
    }

    if (vm->recording()) {
        _recordStartTimeMs = QDateTime::currentMSecsSinceEpoch();
        logRecordStartEvent(QStringLiteral("ActiveVideoStream"));
    } else {
        const qint64 durationSec = (_recordStartTimeMs > 0) ? ((QDateTime::currentMSecsSinceEpoch() - _recordStartTimeMs) / 1000) : 0;
        _recordStartTimeMs = 0;
        logRecordStopEvent(QStringLiteral("ActiveVideoStream"), static_cast<int>(durationSec));
    }
}
