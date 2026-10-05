#include "CompanyFlightLogManager.h"
#include "CompanyNetworkSettings.h"
#include "LinkConfiguration.h"
#include "LinkInterface.h"
#include "VehicleLinkManager.h"
#include "OnboardLogController.h"
#include "OnboardLogEntry.h"
#include "AppSettings.h"
#include "MavlinkSettings.h"
#include "MultiVehicleManager.h"
#include "MAVLinkProtocol.h"
#include "QGCFileHelper.h"
#include "QGCFormat.h"
#include "QGCLoggingCategory.h"
#include "QmlObjectListModel.h"
#include "SettingsManager.h"
#include "Vehicle.h"

#include <QtCore/QApplicationStatic>
#include <QtCore/QDateTime>
#include <QtCore/QDir>
#include <QtCore/QFile>
#include <QtCore/QFileInfo>
#include <QtCore/QSettings>
#include <QtCore/QStandardPaths>
#include <QtCore/QTimer>
#include <QtCore/QUrl>
#include <QtGui/QDesktopServices>
#include <QtNetwork/QNetworkAccessManager>
#include <QtNetwork/QNetworkReply>
#include <QtNetwork/QNetworkRequest>

QGC_LOGGING_CATEGORY(CompanyFlightLogManagerLog, "Company.FlightLogManager")

Q_APPLICATION_STATIC(CompanyFlightLogManager, _companyFlightLogManagerInstance);

/*===========================================================================*/

CompanyLogEntry::CompanyLogEntry(int uasId, uint logId, const QString &logType, qint64 fileSize,
                                 const QDateTime &timestamp, const QString &status,
                                 bool isOnboard, const QString &localPath, QObject *parent)
    : QObject(parent)
    , _uasId(uasId)
    , _logId(logId)
    , _logType(logType)
    , _fileSize(fileSize)
    , _timestamp(timestamp)
    , _status(status)
    , _localFilePath(localPath)
    , _isOnboard(isOnboard)
{
}

QString CompanyLogEntry::fileSizeStr() const
{
    return QGC::bigSizeToString(static_cast<quint64>(_fileSize));
}

void CompanyLogEntry::setFileSize(qint64 size)
{
    if (_fileSize != size) {
        _fileSize = size;
        emit fileSizeChanged();
    }
}

void CompanyLogEntry::setStatus(const QString &stat)
{
    if (_status != stat) {
        _status = stat;
        emit statusChanged();
    }
}

void CompanyLogEntry::setProgress(qreal prog)
{
    if (!qFuzzyCompare(_progress, prog)) {
        _progress = prog;
        emit progressChanged();
    }
}

void CompanyLogEntry::setLocalFilePath(const QString &path)
{
    if (_localFilePath != path) {
        _localFilePath = path;
        emit localFilePathChanged();
    }
}

void CompanyLogEntry::setIntegrityStatus(const QString &integrity)
{
    if (_integrityStatus != integrity) {
        _integrityStatus = integrity;
        emit integrityStatusChanged();
    }
}

void CompanyLogEntry::setSelected(bool sel)
{
    if (_selected != sel) {
        _selected = sel;
        emit selectedChanged();
    }
}

/*===========================================================================*/

CompanyFlightLogManager *CompanyFlightLogManager::instance()
{
    return _companyFlightLogManagerInstance();
}

CompanyFlightLogManager::CompanyFlightLogManager(QObject *parent)
    : QObject(parent)
    , _logEntriesModel(new QmlObjectListModel(this))
    , _telemetryPollTimer(new QTimer(this))
    , _autoSyncDelayTimer(new QTimer(this))
    , _retryTimer(new QTimer(this))
{
    qCDebug(CompanyFlightLogManagerLog) << "Instantiating CompanyFlightLogManager";

    _initGroundTelemetrySettings();

    _autoSyncDelayTimer->setSingleShot(true);
    _retryTimer->setSingleShot(true);
    _telemetryPollTimer->setInterval(1000);

    (void) connect(_telemetryPollTimer, &QTimer::timeout, this, &CompanyFlightLogManager::_checkTelemetryFileGrowth);
    (void) connect(_autoSyncDelayTimer, &QTimer::timeout, this, &CompanyFlightLogManager::_executeAutomatedLogSync);
    (void) connect(_retryTimer, &QTimer::timeout, this, &CompanyFlightLogManager::_executeAutomatedLogSync);

    MultiVehicleManager *const mvm = MultiVehicleManager::instance();
    if (mvm) {
        (void) connect(mvm, &MultiVehicleManager::activeVehicleChanged, this, &CompanyFlightLogManager::_handleActiveVehicleChanged);
        _handleActiveVehicleChanged(mvm->activeVehicle());
    }

    OnboardLogController *const onboardCtrl = OnboardLogController::instance();
    if (onboardCtrl) {
        (void) connect(onboardCtrl, &OnboardLogController::requestingListChanged, this, &CompanyFlightLogManager::_handleLogControllerRequestingListChanged);
        (void) connect(onboardCtrl, &OnboardLogController::downloadingLogsChanged, this, &CompanyFlightLogManager::_handleLogControllerDownloadingLogsChanged);
    }

    _downloadSpeedTimer.start();
    _refreshTelemetryHistory();
    _telemetryPollTimer->start();
}

CompanyFlightLogManager::~CompanyFlightLogManager()
{
    qCDebug(CompanyFlightLogManagerLog) << "Destroying CompanyFlightLogManager";
}

void CompanyFlightLogManager::_initGroundTelemetrySettings()
{
    SettingsManager *const sm = SettingsManager::instance();
    if (!sm) {
        return;
    }

    MavlinkSettings *const mavSettings = sm->mavlinkSettings();
    if (mavSettings) {
        // Enforce automated ground telemetry recording across all operational states
        mavSettings->telemetrySave()->setRawValue(true);
        mavSettings->telemetrySaveNotArmed()->setRawValue(true);
        qCDebug(CompanyFlightLogManagerLog) << "Enforced telemetrySave and telemetrySaveNotArmed = TRUE";
    }

    AppSettings *const appSettings = sm->appSettings();
    if (appSettings) {
        const QString telDir = appSettings->telemetrySavePath();
        const QString logDir = appSettings->logSavePath();

        if (!telDir.isEmpty()) {
            QDir().mkpath(telDir);
        }
        if (!logDir.isEmpty()) {
            QDir().mkpath(logDir);
        }
        qCDebug(CompanyFlightLogManagerLog) << "Storage Paths - Telemetry:" << telDir << "Onboard Logs:" << logDir;
    }
}

int CompanyFlightLogManager::activeUasId() const
{
    return _vehicle ? _vehicle->id() : 0;
}

bool CompanyFlightLogManager::hasVehicle() const
{
    return _vehicle != nullptr;
}

bool CompanyFlightLogManager::isArmed() const
{
    return _vehicle && _vehicle->armed();
}

int CompanyFlightLogManager::selectedCount() const
{
    int count = 0;
    for (int i = 0; i < _logEntriesModel->count(); ++i) {
        CompanyLogEntry *const entry = _logEntriesModel->value<CompanyLogEntry*>(i);
        if (entry && entry->selected() && entry->isOnboard()) {
            count++;
        }
    }
    return count;
}

bool CompanyFlightLogManager::allLogsSelected() const
{
    int onboardCount = 0;
    int selected = 0;
    for (int i = 0; i < _logEntriesModel->count(); ++i) {
        CompanyLogEntry *const entry = _logEntriesModel->value<CompanyLogEntry*>(i);
        if (entry && entry->isOnboard()) {
            onboardCount++;
            if (entry->selected()) {
                selected++;
            }
        }
    }
    return (onboardCount > 0) && (selected == onboardCount);
}

bool CompanyFlightLogManager::isEthernetLink() const
{
    if (!_vehicle) {
        return false;
    }
    VehicleLinkManager *const vlm = _vehicle->vehicleLinkManager();
    if (!vlm) {
        return false;
    }
    SharedLinkInterfacePtr link = vlm->primaryLink().lock();
    if (!link || !link->linkConfiguration()) {
        return false;
    }
    const LinkConfiguration::LinkType type = link->linkConfiguration()->type();
    return (type == LinkConfiguration::TypeUdp || type == LinkConfiguration::TypeTcp);
}

QString CompanyFlightLogManager::activeTransportName() const
{
    if (!_vehicle) {
        return QStringLiteral("NO VEHICLE");
    }
    VehicleLinkManager *const vlm = _vehicle->vehicleLinkManager();
    if (!vlm) {
        return QStringLiteral("UNKNOWN");
    }
    SharedLinkInterfacePtr link = vlm->primaryLink().lock();
    if (!link || !link->linkConfiguration()) {
        return QStringLiteral("DISCONNECTED");
    }
    const LinkConfiguration::LinkType type = link->linkConfiguration()->type();
    switch (type) {
    case LinkConfiguration::TypeUdp:
        return QStringLiteral("ETHERNET (UDP 14550)");
    case LinkConfiguration::TypeTcp:
        return QStringLiteral("ETHERNET (TCP)");
#ifndef QGC_NO_SERIAL_LINK
    case LinkConfiguration::TypeSerial:
        return QStringLiteral("SERIAL (TELEMETRY)");
#endif
    case LinkConfiguration::TypeBluetooth:
        return QStringLiteral("BLUETOOTH");
#ifdef QT_DEBUG
    case LinkConfiguration::TypeMock:
        return QStringLiteral("MOCK LINK");
#endif
    case LinkConfiguration::TypeLogReplay:
        return QStringLiteral("LOG REPLAY");
    default:
        return QStringLiteral("OTHER");
    }
}

void CompanyFlightLogManager::setFastEthernetMode(bool enabled)
{
    if (_fastEthernetMode != enabled) {
        _fastEthernetMode = enabled;
        emit fastEthernetModeChanged();
        qCDebug(CompanyFlightLogManagerLog) << "Fast Ethernet Mode set to:" << enabled;
    }
}

QString CompanyFlightLogManager::telemetrySavePath() const
{
    SettingsManager *const sm = SettingsManager::instance();
    if (sm && sm->appSettings()) {
        const QString p = sm->appSettings()->telemetrySavePath();
        QDir d(p);
        if (d.exists() || d.mkpath(QStringLiteral("."))) {
            return p;
        }
    }
    return QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation) + QStringLiteral("/QGroundControl/Telemetry");
}

QString CompanyFlightLogManager::onboardLogSavePath() const
{
    SettingsManager *const sm = SettingsManager::instance();
    if (sm && sm->appSettings()) {
        const QString p = sm->appSettings()->logSavePath();
        QDir d(p);
        if (d.exists() || d.mkpath(QStringLiteral("."))) {
            return p;
        }
    }
    return QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation) + QStringLiteral("/QGroundControl/Logs");
}

void CompanyFlightLogManager::_handleActiveVehicleChanged(Vehicle *vehicle)
{
    if (_vehicle) {
        (void) disconnect(_vehicle, &Vehicle::armedChanged, this, &CompanyFlightLogManager::_handleArmedChanged);
        VehicleLinkManager *const oldVlm = _vehicle->vehicleLinkManager();
        if (oldVlm) {
            (void) disconnect(oldVlm, &VehicleLinkManager::primaryLinkChanged, this, &CompanyFlightLogManager::_updateLinkTransport);
        }
    }

    _vehicle = vehicle;

    emit hasVehicleChanged();
    emit activeUasIdChanged();
    emit isArmedChanged();

    if (_vehicle) {
        qCDebug(CompanyFlightLogManagerLog) << "Vehicle Connected - System ID:" << _vehicle->id();
        (void) connect(_vehicle, &Vehicle::armedChanged, this, &CompanyFlightLogManager::_handleArmedChanged);
        VehicleLinkManager *const vlm = _vehicle->vehicleLinkManager();
        if (vlm) {
            (void) connect(vlm, &VehicleLinkManager::primaryLinkChanged, this, &CompanyFlightLogManager::_updateLinkTransport);
        }
        _updateLinkTransport();

        _groundTelemetryRecording = true;
        _groundTelemetryStatus = QStringLiteral("RECORDING");
        emit groundTelemetryChanged();

        if (_vehicle->armed()) {
            _onboardSyncStatus = QStringLiteral("WAITING FOR FLIGHT END");
            _currentFlightStart = QDateTime::currentDateTime();
            _flightWasActive = true;
            emit onboardSyncStatusChanged();
        } else {
            _onboardSyncStatus = QStringLiteral("IDLE");
            emit onboardSyncStatusChanged();
            // Automatically scan for existing onboard logs shortly after initial connect
            _autoSyncDelayTimer->start(1500);
        }
    } else {
        qCDebug(CompanyFlightLogManagerLog) << "Vehicle Disconnected";
        _updateLinkTransport();
        _groundTelemetryRecording = false;
        _groundTelemetryStatus = QStringLiteral("SAVED");
        _onboardSyncStatus = QStringLiteral("IDLE");
        _isDownloading = false;
        _isRequestingList = false;
        emit groundTelemetryChanged();
        emit onboardSyncStatusChanged();
        emit isDownloadingChanged();
        emit isRequestingListChanged();
        _refreshTelemetryHistory();
    }
}

void CompanyFlightLogManager::_handleArmedChanged(bool armed)
{
    emit isArmedChanged();

    if (!_vehicle) {
        return;
    }

    if (armed) {
        _flightWasActive = true;
        _currentFlightStart = QDateTime::currentDateTime();
        qCDebug(CompanyFlightLogManagerLog) << "Aircraft ARMED. Flight started at:" << _currentFlightStart;

        // CRITICAL SAFETY LOCKOUT:
        // Inhibit/abort heavy onboard log downloads while actively airborne to preserve bandwidth for flight controls
        if (_isDownloading) {
            qCWarning(CompanyFlightLogManagerLog) << "Safety Lockout: Cancelling active download due to aircraft arming!";
            cancel();
        }

        _onboardSyncStatus = QStringLiteral("WAITING FOR FLIGHT END");
        emit onboardSyncStatusChanged();

        // Update corresponding entries to reflect flight underway
        for (int i = 0; i < _logEntriesModel->count(); ++i) {
            CompanyLogEntry *const entry = _logEntriesModel->value<CompanyLogEntry*>(i);
            if (entry && entry->status() == QStringLiteral("LOG DETECTED")) {
                entry->setStatus(QStringLiteral("WAITING FOR FLIGHT END"));
            }
        }
    } else {
        _currentFlightEnd = QDateTime::currentDateTime();
        qCDebug(CompanyFlightLogManagerLog) << "Aircraft DISARMED. Flight ended at:" << _currentFlightEnd;

        _onboardSyncStatus = QStringLiteral("WAITING FOR FLIGHT END");
        emit onboardSyncStatusChanged();

        // Give the flight controller logger module 2.5s to flush its buffer to the SD card before listing
        _autoSyncDelayTimer->start(kPostFlightSyncDelayMs);
    }
}

void CompanyFlightLogManager::_handleFlightTimeChanged()
{
}

void CompanyFlightLogManager::_checkTelemetryFileGrowth()
{
    const QString telDir = telemetrySavePath();
    const QDir dir(telDir);
    const QFileInfoList files = dir.entryInfoList(QStringList() << QStringLiteral("*.tlog"), QDir::Files, QDir::Time);

    if (!files.isEmpty()) {
        const QFileInfo &latest = files.first();
        _groundTelemetryPath = latest.absoluteFilePath();
        _groundTelemetryBytes = latest.size();
        emit groundTelemetryChanged();
    }

    _monitorDownloadProgress();
}

void CompanyFlightLogManager::refresh()
{
    if (!_vehicle) {
        qCDebug(CompanyFlightLogManagerLog) << "refresh: No active vehicle connected";
        return;
    }

    if (_vehicle->armed()) {
        qCWarning(CompanyFlightLogManagerLog) << "refresh: Inactive during flight - aircraft is armed";
        _onboardSyncStatus = QStringLiteral("WAITING FOR FLIGHT END");
        emit onboardSyncStatusChanged();
        return;
    }

    OnboardLogController *const onboardCtrl = OnboardLogController::instance();
    if (onboardCtrl) {
        qCDebug(CompanyFlightLogManagerLog) << "refresh: Querying flight controller log catalog";
        _onboardSyncStatus = QStringLiteral("LOG DETECTED");
        emit onboardSyncStatusChanged();
        onboardCtrl->refresh();
    }
}

void CompanyFlightLogManager::_executeAutomatedLogSync()
{
    if (!_vehicle) {
        return;
    }

    if (_vehicle->armed()) {
        qCDebug(CompanyFlightLogManagerLog) << "Automated sync deferred: Vehicle is armed";
        _onboardSyncStatus = QStringLiteral("WAITING FOR FLIGHT END");
        emit onboardSyncStatusChanged();
        return;
    }

    qCDebug(CompanyFlightLogManagerLog) << "Executing automated onboard flight log synchronization";
    refresh();
}

void CompanyFlightLogManager::_handleLogControllerRequestingListChanged()
{
    OnboardLogController *const onboardCtrl = OnboardLogController::instance();
    if (!onboardCtrl) {
        return;
    }

    _isRequestingList = onboardCtrl->requestingList();
    emit isRequestingListChanged();

    if (!_isRequestingList) {
        // Log catalog query completed — sync models and evaluate automated downloads
        _syncWithOnboardController();
    }
}

void CompanyFlightLogManager::_syncWithOnboardController()
{
    OnboardLogController *const onboardCtrl = OnboardLogController::instance();
    if (!onboardCtrl || !_vehicle) {
        return;
    }

    QmlObjectListModel *const nativeModel = onboardCtrl->model();
    if (!nativeModel || nativeModel->count() == 0) {
        qCDebug(CompanyFlightLogManagerLog) << "Onboard log catalog returned zero entries from flight controller";
        _onboardSyncStatus = QStringLiteral("NO LOG AVAILABLE");
        emit onboardSyncStatusChanged();
        return;
    }

    const int uasId = _vehicle->id();
    const QString logType = _vehicle->px4Firmware() ? QStringLiteral("ULog (.ulg)") : QStringLiteral("DataFlash (.bin)");
    const QString destDir = onboardLogSavePath();

    QList<CompanyLogEntry*> entriesToDownload;

    for (int i = 0; i < nativeModel->count(); ++i) {
        QGCOnboardLogEntry *const nativeEntry = nativeModel->value<QGCOnboardLogEntry*>(i);
        if (!nativeEntry) {
            continue;
        }

        const uint logId = nativeEntry->id();
        const qint64 remoteSize = static_cast<qint64>(nativeEntry->size());
        const QString remoteFtpPath = nativeEntry->ftpPath();
        const QString remoteName = remoteFtpPath.isEmpty() ? QStringLiteral("log_%1").arg(logId) : remoteFtpPath.section(QLatin1Char('/'), -1);

        // Check if log already exists in persistent storage or matches local file on disk
        const bool alreadySaved = _isLogAlreadySaved(uasId, logId, remoteName, remoteSize);

        // Look for matching entry in our model or create a new one
        CompanyLogEntry *entry = nullptr;
        for (int j = 0; j < _logEntriesModel->count(); ++j) {
            CompanyLogEntry *const existing = _logEntriesModel->value<CompanyLogEntry*>(j);
            if (existing && existing->uasId() == uasId && existing->logId() == logId && existing->isOnboard()) {
                entry = existing;
                break;
            }
        }

        if (!entry) {
            entry = new CompanyLogEntry(uasId, logId, logType, remoteSize, nativeEntry->time(),
                                        alreadySaved ? QStringLiteral("ALREADY SAVED") : QStringLiteral("LOG DETECTED"),
                                        true, QString(), this);
            entry->setFtpPath(remoteFtpPath);
            (void) connect(entry, &CompanyLogEntry::selectedChanged, this, &CompanyFlightLogManager::selectedCountChanged);
            _logEntriesModel->append(entry);
            emit selectedCountChanged();
        } else {
            entry->setFileSize(remoteSize);
            entry->setFtpPath(remoteFtpPath);
        }

        if (alreadySaved) {
            entry->setStatus(QStringLiteral("ALREADY SAVED"));
            entry->setIntegrityStatus(QStringLiteral("Verified"));
            entry->setProgress(1.0);
            nativeEntry->setSelected(false);
        } else {
            // New log detected
            entry->setStatus(QStringLiteral("LOG DETECTED"));
            entry->setIntegrityStatus(QStringLiteral("Pending"));
            entry->setProgress(0.0);
            entriesToDownload.append(entry);
        }
    }

    if (!entriesToDownload.isEmpty()) {
        qCDebug(CompanyFlightLogManagerLog) << "Detected" << entriesToDownload.count() << "new flight logs for UAS" << uasId;
        _triggerOnboardLogDownload(entriesToDownload);
    } else {
        qCDebug(CompanyFlightLogManagerLog) << "All flight logs for UAS" << uasId << "are already saved locally";
        _onboardSyncStatus = QStringLiteral("ALREADY SAVED");
        emit onboardSyncStatusChanged();
    }
}

void CompanyFlightLogManager::_triggerOnboardLogDownload(QList<CompanyLogEntry*> entriesToDownload)
{
    if (!_vehicle || _vehicle->armed()) {
        qCWarning(CompanyFlightLogManagerLog) << "Download inhibited: Vehicle armed or unavailable";
        _onboardSyncStatus = QStringLiteral("WAITING FOR FLIGHT END");
        emit onboardSyncStatusChanged();
        return;
    }

    OnboardLogController *const onboardCtrl = OnboardLogController::instance();
    if (!onboardCtrl) {
        return;
    }

    QmlObjectListModel *const nativeModel = onboardCtrl->model();
    if (!nativeModel) {
        return;
    }

    // Select only the target new entries in the native controller
    onboardCtrl->selectAll(false);

    for (CompanyLogEntry *const entry : entriesToDownload) {
        for (int i = 0; i < nativeModel->count(); ++i) {
            QGCOnboardLogEntry *const nativeEntry = nativeModel->value<QGCOnboardLogEntry*>(i);
            if (nativeEntry && nativeEntry->id() == entry->logId()) {
                nativeEntry->setSelected(true);
                entry->setStatus(QStringLiteral("DOWNLOADING"));
                break;
            }
        }
    }

    _onboardSyncStatus = QStringLiteral("DOWNLOADING");
    emit onboardSyncStatusChanged();

    qCDebug(CompanyFlightLogManagerLog) << "Triggering native OnboardLogController download to:" << onboardLogSavePath();
    onboardCtrl->download(onboardLogSavePath());
}

void CompanyFlightLogManager::_handleLogControllerDownloadingLogsChanged()
{
    OnboardLogController *const onboardCtrl = OnboardLogController::instance();
    if (!onboardCtrl) {
        return;
    }

    _isDownloading = onboardCtrl->downloadingLogs();
    emit isDownloadingChanged();

    if (_isDownloading) {
        _onboardSyncStatus = QStringLiteral("DOWNLOADING");
        emit onboardSyncStatusChanged();
    } else {
        // Download phase completed — verify file integrity and update status
        _onboardSyncStatus = QStringLiteral("VERIFYING");
        emit onboardSyncStatusChanged();
        _verifyDownloadedFiles();
    }
}

void CompanyFlightLogManager::_handleLogEntryStatusChanged()
{
}

void CompanyFlightLogManager::_verifyDownloadedFiles()
{
    const QString destDir = onboardLogSavePath();
    const QDir dir(destDir);

    bool allSuccess = true;

    for (int i = 0; i < _logEntriesModel->count(); ++i) {
        CompanyLogEntry *const entry = _logEntriesModel->value<CompanyLogEntry*>(i);
        if (!entry || !entry->isOnboard()) {
            continue;
        }

        if (entry->status() == QStringLiteral("DOWNLOADING") || entry->status() == QStringLiteral("LOG DETECTED")) {
            // Find local file corresponding to this entry
            const QString baseName = QStringLiteral("log_%1").arg(entry->logId());
            const QFileInfoList matches = dir.entryInfoList(QStringList() << QStringLiteral("%1*").arg(baseName)
                                                                          << QStringLiteral("*%1*").arg(entry->logId()), QDir::Files);

            bool verified = false;
            for (const QFileInfo &fi : matches) {
                if (fi.size() > 0) {
                    entry->setLocalFilePath(fi.absoluteFilePath());
                    entry->setFileSize(fi.size());
                    entry->setProgress(1.0);
                    entry->setStatus(QStringLiteral("SAVED"));
                    entry->setIntegrityStatus(QStringLiteral("Verified"));
                    _recordDownloadedLog(entry->uasId(), entry->logId(), fi.fileName(), fi.size());
                    verified = true;
                    qCDebug(CompanyFlightLogManagerLog) << "Verified downloaded onboard log:" << fi.absoluteFilePath()
                                                       << "Size:" << fi.size() << "bytes";
                    break;
                }
            }

            if (!verified) {
                allSuccess = false;
                if (_retryCount < kMaxDownloadRetries) {
                    _retryCount++;
                    entry->setStatus(QStringLiteral("RETRYING"));
                    entry->setIntegrityStatus(QStringLiteral("Retry Pending"));
                    qCWarning(CompanyFlightLogManagerLog) << "Download incomplete for log" << entry->logId() << "- Scheduling retry" << _retryCount;
                    _retryTimer->start(3000);
                } else {
                    entry->setStatus(QStringLiteral("FAILED"));
                    entry->setIntegrityStatus(QStringLiteral("Transfer Incomplete"));
                    qCWarning(CompanyFlightLogManagerLog) << "Download failed after maximum retries for log" << entry->logId();
                }
            }
        }
    }

    if (allSuccess) {
        _retryCount = 0;
        _onboardSyncStatus = QStringLiteral("SAVED");
        emit onboardSyncStatusChanged();
    } else if (_retryCount < kMaxDownloadRetries) {
        _onboardSyncStatus = QStringLiteral("RETRYING");
        emit onboardSyncStatusChanged();
    } else {
        _onboardSyncStatus = QStringLiteral("FAILED");
        emit onboardSyncStatusChanged();
    }
}

bool CompanyFlightLogManager::_isLogAlreadySaved(int uasId, uint logId, const QString &remoteName, qint64 size) const
{
    QSettings settings;
    const QString key = QStringLiteral("CompanyLogManager/Vehicle_%1_Downloaded").arg(uasId);
    const QStringList savedList = settings.value(key).toStringList();

    const QString logSig = QStringLiteral("%1_%2").arg(logId).arg(size);
    if (savedList.contains(logSig) || savedList.contains(QString::number(logId))) {
        return true;
    }

    // Secondary verification: inspect file existence in local storage directory
    const QDir logDir(onboardLogSavePath());
    if (logDir.exists()) {
        const QStringList candidates = QStringList() << QStringLiteral("log_%1.ulg").arg(logId)
                                                     << QStringLiteral("log_%1.bin").arg(logId)
                                                     << QStringLiteral("log_%1.px4log").arg(logId)
                                                     << remoteName;
        for (const QString &cand : candidates) {
            if (!cand.isEmpty() && logDir.exists(cand)) {
                const QFileInfo fi(logDir.filePath(cand));
                if (fi.size() > 0 && (size == 0 || qAbs(fi.size() - size) < 512 || fi.size() >= size)) {
                    return true;
                }
            }
        }
    }

    return false;
}

void CompanyFlightLogManager::_recordDownloadedLog(int uasId, uint logId, const QString &remoteName, qint64 size)
{
    Q_UNUSED(remoteName);
    QSettings settings;
    const QString key = QStringLiteral("CompanyLogManager/Vehicle_%1_Downloaded").arg(uasId);
    QStringList savedList = settings.value(key).toStringList();

    const QString logSig = QStringLiteral("%1_%2").arg(logId).arg(size);
    if (!savedList.contains(logSig)) {
        savedList.append(logSig);
    }
    if (!savedList.contains(QString::number(logId))) {
        savedList.append(QString::number(logId));
    }

    settings.setValue(key, savedList);
}

void CompanyFlightLogManager::_refreshTelemetryHistory()
{
    const QString telDir = telemetrySavePath();
    const QDir dir(telDir);
    if (!dir.exists()) {
        return;
    }

    const QFileInfoList files = dir.entryInfoList(QStringList() << QStringLiteral("*.tlog"), QDir::Files, QDir::Time);
    for (const QFileInfo &fi : files) {
        bool alreadyPresent = false;
        for (int i = 0; i < _logEntriesModel->count(); ++i) {
            CompanyLogEntry *const entry = _logEntriesModel->value<CompanyLogEntry*>(i);
            if (entry && entry->localFilePath() == fi.absoluteFilePath()) {
                alreadyPresent = true;
                break;
            }
        }

        if (!alreadyPresent) {
            CompanyLogEntry *const telEntry = new CompanyLogEntry(1, 0, QStringLiteral("Telemetry (.tlog)"), fi.size(),
                                                                  fi.lastModified(), QStringLiteral("SAVED"), false,
                                                                  fi.absoluteFilePath(), this);
            telEntry->setIntegrityStatus(QStringLiteral("Verified"));
            telEntry->setProgress(1.0);
            (void) connect(telEntry, &CompanyLogEntry::selectedChanged, this, &CompanyFlightLogManager::selectedCountChanged);
            _logEntriesModel->append(telEntry);
            emit selectedCountChanged();
        }
    }
}

void CompanyFlightLogManager::downloadSelected()
{
    OnboardLogController *const onboardCtrl = OnboardLogController::instance();
    if (!onboardCtrl || !_vehicle) {
        return;
    }

    if (_vehicle->armed()) {
        qCWarning(CompanyFlightLogManagerLog) << "downloadSelected: Inactive during flight";
        return;
    }

    QList<CompanyLogEntry*> selectedToDownload;
    for (int i = 0; i < _logEntriesModel->count(); ++i) {
        CompanyLogEntry *const entry = _logEntriesModel->value<CompanyLogEntry*>(i);
        if (entry && entry->selected() && entry->isOnboard()) {
            selectedToDownload.append(entry);
        }
    }

    if (!selectedToDownload.isEmpty()) {
        _triggerOnboardLogDownload(selectedToDownload);
    }
}

void CompanyFlightLogManager::selectAll(bool select)
{
    for (int i = 0; i < _logEntriesModel->count(); ++i) {
        CompanyLogEntry *const entry = _logEntriesModel->value<CompanyLogEntry*>(i);
        if (entry && entry->isOnboard()) {
            entry->setSelected(select);
        }
    }
    emit selectedCountChanged();
}

void CompanyFlightLogManager::cancel()
{
    OnboardLogController *const onboardCtrl = OnboardLogController::instance();
    if (onboardCtrl) {
        onboardCtrl->cancel();
    }
    _isDownloading = false;
    _isRequestingList = false;
    _onboardSyncStatus = QStringLiteral("IDLE");
    emit isDownloadingChanged();
    emit isRequestingListChanged();
    emit onboardSyncStatusChanged();
}

void CompanyFlightLogManager::openLogDirectory()
{
    const QString path = onboardLogSavePath();
    if (!path.isEmpty()) {
        QDesktopServices::openUrl(QUrl::fromLocalFile(path));
    }
}

void CompanyFlightLogManager::openTelemetryDirectory()
{
    const QString path = telemetrySavePath();
    if (!path.isEmpty()) {
        QDesktopServices::openUrl(QUrl::fromLocalFile(path));
    }
}

void CompanyFlightLogManager::_updateLinkTransport()
{
    emit isEthernetLinkChanged();
    emit activeTransportNameChanged();
    qCDebug(CompanyFlightLogManagerLog) << "Transport updated:" << activeTransportName() << "isEthernet:" << isEthernetLink();
}

void CompanyFlightLogManager::_monitorDownloadProgress()
{
    if (!_isDownloading) {
        if (!_downloadSpeedStr.isEmpty() || !_downloadEtaStr.isEmpty() || _downloadPercent > 0.0) {
            _downloadSpeedStr.clear();
            _downloadEtaStr.clear();
            _downloadPercent = 0.0;
            _lastBytesDownloaded = 0;
            emit downloadMetricsChanged();
        }
        return;
    }

    OnboardLogController *const onboardCtrl = OnboardLogController::instance();
    if (!onboardCtrl) {
        return;
    }

    QmlObjectListModel *const model = onboardCtrl->model();
    if (!model) {
        return;
    }

    for (int i = 0; i < model->count(); ++i) {
        QGCOnboardLogEntry *const nativeEntry = model->value<QGCOnboardLogEntry*>(i);
        if (!nativeEntry) {
            continue;
        }

        const QString status = nativeEntry->status();
        if (status.contains(QStringLiteral("/s"))) {
            for (int j = 0; j < _logEntriesModel->count(); ++j) {
                CompanyLogEntry *const cEntry = _logEntriesModel->value<CompanyLogEntry*>(j);
                if (cEntry && cEntry->logId() == nativeEntry->id()) {
                    cEntry->setStatus(status);

                    const int startParen = status.indexOf(QLatin1Char('('));
                    const int endParen = status.indexOf(QLatin1Char(')'));
                    if (startParen != -1 && endParen > startParen) {
                        _downloadSpeedStr = status.mid(startParen + 1, endParen - startParen - 1);
                    }

                    if (nativeEntry->size() > 0) {
                        const QString writtenStr = status.left(startParen).trimmed();
                        qreal writtenBytes = 0;
                        const QStringList parts = writtenStr.split(QLatin1Char(' '), Qt::SkipEmptyParts);
                        if (!parts.isEmpty()) {
                            const double val = parts.first().toDouble();
                            if (writtenStr.contains(QStringLiteral("MB"), Qt::CaseInsensitive)) {
                                writtenBytes = val * 1024.0 * 1024.0;
                            } else if (writtenStr.contains(QStringLiteral("KB"), Qt::CaseInsensitive)) {
                                writtenBytes = val * 1024.0;
                            } else if (writtenStr.contains(QStringLiteral("GB"), Qt::CaseInsensitive)) {
                                writtenBytes = val * 1024.0 * 1024.0 * 1024.0;
                            } else {
                                writtenBytes = val;
                            }
                        }

                        if (writtenBytes > 0 && nativeEntry->size() > 0) {
                            _downloadPercent = qBound(0.0, writtenBytes / static_cast<qreal>(nativeEntry->size()), 1.0);
                            cEntry->setProgress(_downloadPercent);

                            double speedBytesPerSec = 0;
                            const QString speedStr = _downloadSpeedStr;
                            const QStringList sParts = speedStr.split(QLatin1Char(' '), Qt::SkipEmptyParts);
                            if (!sParts.isEmpty()) {
                                const double sVal = sParts.first().toDouble();
                                if (speedStr.contains(QStringLiteral("MB/s"), Qt::CaseInsensitive)) {
                                    speedBytesPerSec = sVal * 1024.0 * 1024.0;
                                } else if (speedStr.contains(QStringLiteral("KB/s"), Qt::CaseInsensitive)) {
                                    speedBytesPerSec = sVal * 1024.0;
                                }
                            }
                            if (speedBytesPerSec > 0) {
                                const qint64 remainingBytes = nativeEntry->size() - static_cast<qint64>(writtenBytes);
                                if (remainingBytes > 0) {
                                    const int etaSec = static_cast<int>(remainingBytes / speedBytesPerSec);
                                    _downloadEtaStr = QStringLiteral("%1s").arg(etaSec);
                                } else {
                                    _downloadEtaStr = QStringLiteral("0s");
                                }
                            }
                        }
                    }
                    break;
                }
            }
        }
    }

    emit downloadMetricsChanged();
}

void CompanyFlightLogManager::downloadDirectEthernet(int logId)
{
    CompanyNetworkSettings *const netSettings = CompanyNetworkSettings::instance();
    if (!netSettings || !netSettings->ethernetLogEnabled()) {
        qCWarning(CompanyFlightLogManagerLog) << "downloadDirectEthernet: High-speed Ethernet logging is disabled in settings";
        return;
    }

    if (_vehicle && _vehicle->armed()) {
        qCWarning(CompanyFlightLogManagerLog) << "downloadDirectEthernet: Airborne safety lockout active";
        return;
    }

    const QString droneIp = netSettings->ethernetLogDroneIP();
    const int httpPort = netSettings->ethernetLogHttpPort();
    if (!netSettings->isValidIPv4(droneIp)) {
        qCWarning(CompanyFlightLogManagerLog) << "downloadDirectEthernet: Invalid drone IP configuration:" << droneIp;
        return;
    }

    uint targetId = static_cast<uint>(logId > 0 ? logId : 1);
    if (logId <= 0) {
        for (int i = 0; i < _logEntriesModel->count(); ++i) {
            CompanyLogEntry *const entry = _logEntriesModel->value<CompanyLogEntry*>(i);
            if (entry && entry->isOnboard()) {
                targetId = entry->logId();
                if (entry->selected()) {
                    break;
                }
            }
        }
    }

    const QString destDir = onboardLogSavePath();
    const QString targetFileName = QStringLiteral("log_%1_ethernet.bin").arg(targetId);
    const QString localPath = destDir + QDir::separator() + targetFileName;

    const QUrl url(QStringLiteral("http://%1:%2/logs/log_%3.bin").arg(droneIp).arg(httpPort).arg(targetId));
    qCDebug(CompanyFlightLogManagerLog) << "Initiating direct high-speed Ethernet HTTP offload from:" << url << "to:" << localPath;

    _isDownloading = true;
    _onboardSyncStatus = QStringLiteral("DOWNLOADING (ETHERNET)");
    _downloadSpeedStr = QStringLiteral("High-Speed Eth (~100 Mbps)");
    _downloadPercent = 0.1;
    emit isDownloadingChanged();
    emit onboardSyncStatusChanged();
    emit downloadMetricsChanged();

    for (int i = 0; i < _logEntriesModel->count(); ++i) {
        CompanyLogEntry *const entry = _logEntriesModel->value<CompanyLogEntry*>(i);
        if (entry && entry->logId() == targetId) {
            entry->setStatus(QStringLiteral("DOWNLOADING (ETHERNET)"));
            entry->setProgress(0.1);
            break;
        }
    }

    QNetworkAccessManager *const nam = new QNetworkAccessManager(this);
    QNetworkRequest request(url);
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);

    QNetworkReply *const reply = nam->get(request);

    (void) connect(reply, &QNetworkReply::downloadProgress, this, [this, targetId](qint64 bytesReceived, qint64 bytesTotal) {
        if (bytesTotal > 0) {
            _downloadPercent = static_cast<qreal>(bytesReceived) / static_cast<qreal>(bytesTotal);
            _downloadSpeedStr = QStringLiteral("Eth Direct (%1)").arg(QGC::bigSizeToString(bytesReceived));
            emit downloadMetricsChanged();

            for (int i = 0; i < _logEntriesModel->count(); ++i) {
                CompanyLogEntry *const entry = _logEntriesModel->value<CompanyLogEntry*>(i);
                if (entry && entry->logId() == targetId) {
                    entry->setProgress(_downloadPercent);
                    break;
                }
            }
        }
    });

    (void) connect(reply, &QNetworkReply::finished, this, [this, reply, nam, localPath, targetId]() {
        reply->deleteLater();
        nam->deleteLater();

        _isDownloading = false;
        emit isDownloadingChanged();

        if (reply->error() == QNetworkReply::NoError) {
            QFile file(localPath);
            if (file.open(QIODevice::WriteOnly)) {
                file.write(reply->readAll());
                file.close();

                const qint64 fileSize = QFileInfo(localPath).size();
                qCDebug(CompanyFlightLogManagerLog) << "Direct Ethernet offload succeeded. Saved to:" << localPath << "Size:" << fileSize;

                for (int i = 0; i < _logEntriesModel->count(); ++i) {
                    CompanyLogEntry *const entry = _logEntriesModel->value<CompanyLogEntry*>(i);
                    if (entry && entry->logId() == targetId) {
                        entry->setLocalFilePath(localPath);
                        entry->setFileSize(fileSize);
                        entry->setStatus(QStringLiteral("SAVED"));
                        entry->setIntegrityStatus(QStringLiteral("Verified (Ethernet)"));
                        entry->setProgress(1.0);
                        break;
                    }
                }

                _onboardSyncStatus = QStringLiteral("SAVED");
                emit onboardSyncStatusChanged();
                _recordDownloadedLog(activeUasId(), targetId, QFileInfo(localPath).fileName(), fileSize);
            } else {
                qCWarning(CompanyFlightLogManagerLog) << "Failed to open local file for writing:" << localPath;
                _onboardSyncStatus = QStringLiteral("FAILED");
                emit onboardSyncStatusChanged();
            }
        } else {
            qCWarning(CompanyFlightLogManagerLog) << "Direct Ethernet offload failed with network error:" << reply->errorString()
                                                << "- Falling back to MAVLink FTP acquisition";
            _onboardSyncStatus = QStringLiteral("FALLBACK TO MAVLINK FTP");
            emit onboardSyncStatusChanged();
            downloadSelected();
        }
    });
}
