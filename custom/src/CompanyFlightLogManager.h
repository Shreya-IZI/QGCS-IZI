#pragma once

#include <QtCore/QDateTime>
#include <QtCore/QDir>
#include <QtCore/QElapsedTimer>
#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QLoggingCategory>
#include <QtCore/QObject>
#include <QtCore/QSet>
#include <QtCore/QSettings>
#include <QtCore/QString>
#include <QtCore/QTimer>
#include <QtQmlIntegration/QtQmlIntegration>

#include "Vehicle.h"

class QmlObjectListModel;
class QGCOnboardLogEntry;
class OnboardLogController;

Q_DECLARE_LOGGING_CATEGORY(CompanyFlightLogManagerLog)

/*===========================================================================*/

/// Represents a unified telemetry or onboard flight log entry for the IZI GCS UI.
class CompanyLogEntry : public QObject
{
    Q_OBJECT
    QML_ANONYMOUS

    Q_PROPERTY(int       uasId            READ uasId            CONSTANT)
    Q_PROPERTY(uint      logId            READ logId            CONSTANT)
    Q_PROPERTY(QString   logType          READ logType          CONSTANT)
    Q_PROPERTY(qint64    fileSize         READ fileSize         NOTIFY fileSizeChanged)
    Q_PROPERTY(QString   fileSizeStr      READ fileSizeStr      NOTIFY fileSizeChanged)
    Q_PROPERTY(QDateTime flightStart      READ flightStart      CONSTANT)
    Q_PROPERTY(QDateTime flightEnd        READ flightEnd        CONSTANT)
    Q_PROPERTY(QDateTime timestamp        READ timestamp        CONSTANT)
    Q_PROPERTY(QString   status           READ status           NOTIFY statusChanged)
    Q_PROPERTY(qreal     progress         READ progress         NOTIFY progressChanged)
    Q_PROPERTY(QString   localFilePath    READ localFilePath    NOTIFY localFilePathChanged)
    Q_PROPERTY(QString   integrityStatus  READ integrityStatus  NOTIFY integrityStatusChanged)
    Q_PROPERTY(bool      selected         READ selected         WRITE setSelected      NOTIFY selectedChanged)
    Q_PROPERTY(bool      isOnboard        READ isOnboard        CONSTANT)
    Q_PROPERTY(bool      isTelemetry      READ isTelemetry      CONSTANT)

public:
    explicit CompanyLogEntry(int uasId, uint logId, const QString &logType, qint64 fileSize,
                             const QDateTime &timestamp, const QString &status,
                             bool isOnboard = true, const QString &localPath = QString(),
                             QObject *parent = nullptr);
    ~CompanyLogEntry() override = default;

    [[nodiscard]] int       uasId() const { return _uasId; }
    [[nodiscard]] uint      logId() const { return _logId; }
    [[nodiscard]] QString   logType() const { return _logType; }
    [[nodiscard]] qint64    fileSize() const { return _fileSize; }
    [[nodiscard]] QString   fileSizeStr() const;
    [[nodiscard]] QDateTime flightStart() const { return _flightStart; }
    [[nodiscard]] QDateTime flightEnd() const { return _flightEnd; }
    [[nodiscard]] QDateTime timestamp() const { return _timestamp; }
    [[nodiscard]] QString   status() const { return _status; }
    [[nodiscard]] qreal     progress() const { return _progress; }
    [[nodiscard]] QString   localFilePath() const { return _localFilePath; }
    [[nodiscard]] QString   integrityStatus() const { return _integrityStatus; }
    [[nodiscard]] bool      selected() const { return _selected; }
    [[nodiscard]] bool      isOnboard() const { return _isOnboard; }
    [[nodiscard]] bool      isTelemetry() const { return !_isOnboard; }
    [[nodiscard]] QString   ftpPath() const { return _ftpPath; }

    void setFileSize(qint64 size);
    void setFlightStart(const QDateTime &dt) { _flightStart = dt; }
    void setFlightEnd(const QDateTime &dt) { _flightEnd = dt; }
    void setStatus(const QString &stat);
    void setProgress(qreal prog);
    void setLocalFilePath(const QString &path);
    void setIntegrityStatus(const QString &integrity);
    void setSelected(bool sel);
    void setFtpPath(const QString &path) { _ftpPath = path; }

signals:
    void fileSizeChanged();
    void statusChanged();
    void progressChanged();
    void localFilePathChanged();
    void integrityStatusChanged();
    void selectedChanged();

private:
    int       _uasId = 0;
    uint      _logId = 0;
    QString   _logType;
    qint64    _fileSize = 0;
    QDateTime _flightStart;
    QDateTime _flightEnd;
    QDateTime _timestamp;
    QString   _status = QStringLiteral("IDLE");
    qreal     _progress = 0.0;
    QString   _localFilePath;
    QString   _integrityStatus = QStringLiteral("Pending");
    bool      _selected = false;
    bool      _isOnboard = true;
    QString   _ftpPath;
};

/*===========================================================================*/

/// Authoritative IZI GCS Automated Flight Log Acquisition Manager.
/// Enforces autonomous MAVLink telemetry (.tlog) recording and post-flight
/// onboard autopilot dataflash/ULog (.bin/.ulg) retrieval safely when disarmed.
class CompanyFlightLogManager : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON

    Q_MOC_INCLUDE("QmlObjectListModel.h")

    Q_PROPERTY(bool                groundTelemetryRecording READ groundTelemetryRecording NOTIFY groundTelemetryChanged)
    Q_PROPERTY(QString             groundTelemetryPath      READ groundTelemetryPath      NOTIFY groundTelemetryChanged)
    Q_PROPERTY(qint64              groundTelemetryBytes     READ groundTelemetryBytes     NOTIFY groundTelemetryChanged)
    Q_PROPERTY(QString             groundTelemetryStatus    READ groundTelemetryStatus    NOTIFY groundTelemetryChanged)

    Q_PROPERTY(QString             onboardSyncStatus        READ onboardSyncStatus        NOTIFY onboardSyncStatusChanged)
    Q_PROPERTY(int                 activeUasId              READ activeUasId              NOTIFY activeUasIdChanged)
    Q_PROPERTY(bool                hasVehicle               READ hasVehicle               NOTIFY hasVehicleChanged)
    Q_PROPERTY(bool                isArmed                  READ isArmed                  NOTIFY isArmedChanged)
    Q_PROPERTY(bool                isDownloading            READ isDownloading            NOTIFY isDownloadingChanged)
    Q_PROPERTY(bool                isRequestingList         READ isRequestingList         NOTIFY isRequestingListChanged)
    Q_PROPERTY(int                 selectedCount            READ selectedCount            NOTIFY selectedCountChanged)
    Q_PROPERTY(bool                allLogsSelected          READ allLogsSelected          NOTIFY selectedCountChanged)

    Q_PROPERTY(bool                isEthernetLink           READ isEthernetLink           NOTIFY isEthernetLinkChanged)
    Q_PROPERTY(QString             activeTransportName      READ activeTransportName      NOTIFY activeTransportNameChanged)
    Q_PROPERTY(bool                fastEthernetMode         READ fastEthernetMode         WRITE setFastEthernetMode     NOTIFY fastEthernetModeChanged)
    Q_PROPERTY(QString             downloadSpeedStr         READ downloadSpeedStr         NOTIFY downloadMetricsChanged)
    Q_PROPERTY(QString             downloadEtaStr           READ downloadEtaStr           NOTIFY downloadMetricsChanged)
    Q_PROPERTY(qreal               downloadPercent          READ downloadPercent          NOTIFY downloadMetricsChanged)

    Q_PROPERTY(QmlObjectListModel* logEntries               READ logEntries               CONSTANT)
    Q_PROPERTY(QString             telemetrySavePath        READ telemetrySavePath        CONSTANT)
    Q_PROPERTY(QString             onboardLogSavePath       READ onboardLogSavePath       CONSTANT)

public:
    explicit CompanyFlightLogManager(QObject *parent = nullptr);
    ~CompanyFlightLogManager() override;

    static CompanyFlightLogManager *instance();

    [[nodiscard]] bool    groundTelemetryRecording() const { return _groundTelemetryRecording; }
    [[nodiscard]] QString groundTelemetryPath() const { return _groundTelemetryPath; }
    [[nodiscard]] qint64  groundTelemetryBytes() const { return _groundTelemetryBytes; }
    [[nodiscard]] QString groundTelemetryStatus() const { return _groundTelemetryStatus; }

    [[nodiscard]] QString onboardSyncStatus() const { return _onboardSyncStatus; }
    [[nodiscard]] int     activeUasId() const;
    [[nodiscard]] bool    hasVehicle() const;
    [[nodiscard]] bool    isArmed() const;
    [[nodiscard]] bool    isDownloading() const { return _isDownloading; }
    [[nodiscard]] bool    isRequestingList() const { return _isRequestingList; }
    [[nodiscard]] int     selectedCount() const;
    [[nodiscard]] bool    allLogsSelected() const;

    [[nodiscard]] bool    isEthernetLink() const;
    [[nodiscard]] QString activeTransportName() const;
    [[nodiscard]] bool    fastEthernetMode() const { return _fastEthernetMode; }
    [[nodiscard]] QString downloadSpeedStr() const { return _downloadSpeedStr; }
    [[nodiscard]] QString downloadEtaStr() const { return _downloadEtaStr; }
    [[nodiscard]] qreal   downloadPercent() const { return _downloadPercent; }

    [[nodiscard]] QmlObjectListModel* logEntries() const { return _logEntriesModel; }
    [[nodiscard]] QString telemetrySavePath() const;
    [[nodiscard]] QString onboardLogSavePath() const;

    Q_INVOKABLE void refresh();
    Q_INVOKABLE void downloadSelected();
    Q_INVOKABLE void selectAll(bool select);
    Q_INVOKABLE void cancel();
    Q_INVOKABLE void openLogDirectory();
    Q_INVOKABLE void openTelemetryDirectory();
    Q_INVOKABLE void setFastEthernetMode(bool enabled);
    Q_INVOKABLE void downloadDirectEthernet(int logId);

signals:
    void groundTelemetryChanged();
    void onboardSyncStatusChanged();
    void activeUasIdChanged();
    void hasVehicleChanged();
    void isArmedChanged();
    void isDownloadingChanged();
    void isRequestingListChanged();
    void selectedCountChanged();
    void isEthernetLinkChanged();
    void activeTransportNameChanged();
    void fastEthernetModeChanged();
    void downloadMetricsChanged();

private slots:
    void _handleActiveVehicleChanged(Vehicle *vehicle);
    void _handleArmedChanged(bool armed);
    void _handleFlightTimeChanged();
    void _handleLogControllerRequestingListChanged();
    void _handleLogControllerDownloadingLogsChanged();
    void _handleLogEntryStatusChanged();
    void _executeAutomatedLogSync();
    void _checkTelemetryFileGrowth();

private:
    void _initGroundTelemetrySettings();
    void _syncWithOnboardController();
    void _triggerOnboardLogDownload(QList<CompanyLogEntry*> entriesToDownload);
    void _verifyDownloadedFiles();
    void _recordDownloadedLog(int uasId, uint logId, const QString &remoteName, qint64 size);
    [[nodiscard]] bool _isLogAlreadySaved(int uasId, uint logId, const QString &remoteName, qint64 size) const;
    void _refreshTelemetryHistory();
    void _updateLinkTransport();
    void _monitorDownloadProgress();

    Vehicle*            _vehicle = nullptr;
    QmlObjectListModel* _logEntriesModel = nullptr;
    QTimer*             _telemetryPollTimer = nullptr;
    QTimer*             _autoSyncDelayTimer = nullptr;
    QTimer*             _retryTimer = nullptr;

    bool    _groundTelemetryRecording = false;
    QString _groundTelemetryPath;
    qint64  _groundTelemetryBytes = 0;
    QString _groundTelemetryStatus = QStringLiteral("IDLE");

    QString _onboardSyncStatus = QStringLiteral("IDLE");
    bool    _isDownloading = false;
    bool    _isRequestingList = false;

    bool    _fastEthernetMode = true;
    QString _downloadSpeedStr;
    QString _downloadEtaStr;
    qreal   _downloadPercent = 0.0;
    qint64  _lastBytesDownloaded = 0;
    QElapsedTimer _downloadSpeedTimer;

    QDateTime _currentFlightStart;
    QDateTime _currentFlightEnd;
    bool      _flightWasActive = false;
    int       _retryCount = 0;

    static constexpr int kMaxDownloadRetries = 3;
    static constexpr int kPostFlightSyncDelayMs = 2500;
};
