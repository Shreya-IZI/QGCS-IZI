#pragma once

#include <QtCore/QDateTime>
#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QLoggingCategory>
#include <QtCore/QObject>
#include <QtCore/QString>
#include <QtCore/QTextStream>
#include <QtCore/QTimer>
#include <QtCore/QTimeZone>

#include "QGCMAVLink.h"

class Vehicle;

Q_DECLARE_LOGGING_CATEGORY(CompanyCsvLoggerLog)

/// Authoritative CSV telemetry and event logger for Chandipur DRDO evaluation.
/// Captures high-resolution vehicle telemetry, raw MAVLink sensors (baro, mag, LRF),
/// gimbal attitude, payload FOV, and correlates snapshot/recording events.
class CompanyCsvLogger : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool    loggingActive        READ loggingActive        WRITE setLoggingActive       NOTIFY loggingActiveChanged)
    Q_PROPERTY(int     loggingRateHz        READ loggingRateHz        WRITE setLoggingRateHz       NOTIFY loggingRateHzChanged)
    Q_PROPERTY(QString logSavePath          READ logSavePath                                       CONSTANT)
    Q_PROPERTY(QString currentLogFileName   READ currentLogFileName                                NOTIFY currentLogFileNameChanged)
    Q_PROPERTY(int     samplesLogged        READ samplesLogged                                     NOTIFY samplesLoggedChanged)
    Q_PROPERTY(int     eventsLogged         READ eventsLogged                                      NOTIFY eventsLoggedChanged)
    Q_PROPERTY(double  lastBaroPressure     READ lastBaroPressure                                  NOTIFY rawSensorsChanged)
    Q_PROPERTY(double  lastMagX             READ lastMagX                                          NOTIFY rawSensorsChanged)
    Q_PROPERTY(double  lastMagY             READ lastMagY                                          NOTIFY rawSensorsChanged)
    Q_PROPERTY(double  lastMagZ             READ lastMagZ                                          NOTIFY rawSensorsChanged)
    Q_PROPERTY(double  lastLrfDistance      READ lastLrfDistance                                   NOTIFY rawSensorsChanged)
    Q_PROPERTY(bool    hasBaroPressure      READ hasBaroPressure                                   NOTIFY rawSensorsChanged)
    Q_PROPERTY(bool    hasMag               READ hasMag                                            NOTIFY rawSensorsChanged)
    Q_PROPERTY(bool    hasLrfDistance       READ hasLrfDistance                                    NOTIFY rawSensorsChanged)
    Q_PROPERTY(bool    hasDroneGpsTime      READ hasDroneGpsTime                                   NOTIFY droneTimeChanged)
    Q_PROPERTY(qint64  currentDroneTimeMs   READ currentDroneTimeMs                                NOTIFY droneTimeChanged)
    Q_PROPERTY(QString droneUtcTimestamp    READ droneUtcTimestamp                                 NOTIFY droneTimeChanged)
    Q_PROPERTY(QString formattedHmsMs       READ formattedHmsMs                                    NOTIFY droneTimeChanged)

public:
    explicit CompanyCsvLogger(QObject *parent = nullptr);
    ~CompanyCsvLogger() override;

    static CompanyCsvLogger *instance();

    bool    loggingActive() const { return _loggingActive; }
    int     loggingRateHz() const { return _loggingRateHz; }
    QString logSavePath() const;
    QString currentLogFileName() const { return _currentLogFileName; }
    int     samplesLogged() const { return _samplesLogged; }
    int     eventsLogged() const { return _eventsLogged; }

    double  lastBaroPressure() const { return _lastBaroPressure; }
    double  lastMagX() const { return _lastMagX; }
    double  lastMagY() const { return _lastMagY; }
    double  lastMagZ() const { return _lastMagZ; }
    double  lastLrfDistance() const;

    bool    hasBaroPressure() const { return _hasBaroPressure; }
    bool    hasMag() const { return _hasMag; }
    bool    hasLrfDistance() const;

    double  lastGimbalPitch() const;
    double  lastGimbalRoll() const;
    double  lastGimbalYaw() const;
    bool    hasGimbalAttitude() const;

    bool    hasDroneGpsTime() const;
    qint64  currentDroneTimeMs() const;
    QString droneUtcTimestamp() const;
    QString formattedHmsMs() const;

    Q_INVOKABLE void setLoggingActive(bool active);
    Q_INVOKABLE void setLoggingRateHz(int rateHz);

    Q_INVOKABLE void startLogging();
    Q_INVOKABLE void stopLogging();
    Q_INVOKABLE void openLogFolder();

    /// Explicit event logging API (for QML or programmatic calls)
    Q_INVOKABLE void logSnapshotEvent(const QString &fileName,
                                      double lat, double lon,
                                      double altAmsl, double altRel,
                                      double pitch, double roll, double yaw,
                                      double gimbalPitch, double gimbalRoll, double gimbalYaw,
                                      double fov);

    Q_INVOKABLE void logRecordStartEvent(const QString &fileName);
    Q_INVOKABLE void logRecordStopEvent(const QString &fileName, int durationSec);

signals:
    void loggingActiveChanged(bool active);
    void loggingRateHzChanged(int rateHz);
    void currentLogFileNameChanged(const QString &fileName);
    void samplesLoggedChanged(int count);
    void eventsLoggedChanged(int count);
    void rawSensorsChanged();
    void droneTimeChanged();

private slots:
    void _onActiveVehicleChanged(Vehicle *vehicle);
    void _onMavlinkMessageReceived(const mavlink_message_t &message);
    void _onPeriodicTimeout();
    void _onVideoImageFileChanged(const QString &imageFile);
    void _onVideoRecordingChanged();

private:
    void _connectVehicle(Vehicle *vehicle);
    void _disconnectVehicle();
    void _initializeTelemetryCsv();
    void _closeTelemetryCsv();
    void _writeHeader();
    void _writeMetadataHeader();
    void _writeTelemetryRow();

    bool        _loggingActive = false;
    int         _loggingRateHz = 1;
    QString     _currentLogFileName;
    int         _samplesLogged = 0;
    int         _eventsLogged = 0;

    // Raw sensor values decoded from MAVLink
    double      _lastBaroPressure = 0.0;
    double      _lastMagX = 0.0;
    double      _lastMagY = 0.0;
    double      _lastMagZ = 0.0;
    double      _lastLrfDistance = 0.0;

    bool        _hasBaroPressure = false;
    bool        _hasMag = false;
    bool        _hasLrfDistance = false;

    // Raw gimbal attitude decoded from MAVLink if available
    double      _lastGimbalPitch = 0.0;
    double      _lastGimbalRoll = 0.0;
    double      _lastGimbalYaw = 0.0;
    bool        _hasGimbalAttitude = false;

    QFile       _csvFile;
    QTextStream _csvStream;
    QTimer      _timer;

    Vehicle*    _currentVehicle = nullptr;
    qint64      _recordStartTimeMs = 0;

    // Drone GPS master clock synchronization
    uint64_t    _droneTimeUsec = 0;
    qint64      _lastDroneTimeReceivedMs = 0;
    bool        _hasDroneGpsTime = false;
};
