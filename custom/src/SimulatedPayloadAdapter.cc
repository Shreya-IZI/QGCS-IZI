#include "SimulatedPayloadAdapter.h"
#include "CompanyCsvLogger.h"
#include "QGCLoggingCategory.h"

#include <QtCore/QDateTime>
#include <QtCore/QDir>
#include <QtCore/QStandardPaths>
#include <QtGui/QColor>
#include <QtGui/QFont>
#include <QtGui/QImage>
#include <QtGui/QPainter>
#include <QtGui/QPen>
#include <cmath>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

SimulatedPayloadAdapter::SimulatedPayloadAdapter(QObject *parent)
    : CompanyPayloadInterface(parent)
{
    _elapsedTimer.start();
    _recalculateFov();

    connect(&_simTimer, &QTimer::timeout, this, &SimulatedPayloadAdapter::_onSimulationTick);
    _simTimer.start(50); // 20 Hz simulation loop

    qCDebug(CompanyPayloadLog) << "SimulatedPayloadAdapter initialized for MotionMatics ECLIPSE X-LR baseline";
}

SimulatedPayloadAdapter::~SimulatedPayloadAdapter()
{
    _simTimer.stop();
}

void SimulatedPayloadAdapter::setPitch(float pitchDeg)
{
    // Enforce strict safety limits [-45.0, +100.0] degrees
    _targetPitch = clampPitch(pitchDeg);
}

void SimulatedPayloadAdapter::setYaw(float yawDeg)
{
    _targetYaw = yawDeg;
}

void SimulatedPayloadAdapter::setRoll(float rollDeg)
{
    _roll = rollDeg;
    emit attitudeChanged();
}

void SimulatedPayloadAdapter::center()
{
    _targetPitch = 0.0f;
    _targetYaw = 0.0f;
}

void SimulatedPayloadAdapter::setZoom(float zoomFactor)
{
    const float clamped = std::clamp(zoomFactor, 1.0f, 30.0f);
    if (std::abs(_zoom - clamped) > 0.01f) {
        _zoom = clamped;
        _recalculateFov();
        emit zoomChanged();
        qCDebug(CompanyPayloadLog) << "Simulated zoom updated:" << _zoom << "x, HFOV:" << _fov << "deg";
    }
}

void SimulatedPayloadAdapter::setFocus(float focusValue)
{
    const float clamped = std::clamp(focusValue, 0.0f, 1.0f);
    if (std::abs(_focus - clamped) > 0.01f) {
        _focus = clamped;
        emit focusChanged();
    }
}

void SimulatedPayloadAdapter::setThermalPalette(const QString &palette)
{
    if (_thermalPalette != palette) {
        _thermalPalette = palette;
        emit thermalPaletteChanged();
        qCDebug(CompanyPayloadLog) << "Simulated thermal palette set to:" << _thermalPalette;
    }
}

void SimulatedPayloadAdapter::triggerSnapshot()
{
    _isCapturingPhoto = true;
    emit photoCaptureChanged();

    const QString timeStr = QDateTime::currentDateTimeUtc().toString(QStringLiteral("yyyyMMdd_hhmmss_zzz"));
    const QString photoName = QStringLiteral("IZI_SNAP_%1.jpg").arg(timeStr);
    const QString fullPath = photoSaveDirectory() + QStringLiteral("/") + photoName;

    // Generate high-resolution reconnaissance tactical snapshot frame
    QImage snapImg(1920, 1080, QImage::Format_RGB32);
    snapImg.fill(QColor(11, 14, 20));
    {
        QPainter p(&snapImg);
        p.setRenderHint(QPainter::Antialiasing);

        // Tactical HUD reticle
        p.setPen(QPen(QColor(16, 185, 129, 140), 1.5));
        p.drawLine(960, 0, 960, 1080);
        p.drawLine(0, 540, 1920, 540);
        p.drawEllipse(QPoint(960, 540), 140, 140);
        p.drawEllipse(QPoint(960, 540), 280, 280);

        // Header
        p.setFont(QFont(QStringLiteral("Monospace"), 22, QFont::Bold));
        p.setPen(QColor(255, 255, 255));
        p.drawText(60, 80, QStringLiteral("IZI GCS • TACTICAL RECONNAISSANCE PAYLOAD"));

        // OSD Telemetry
        p.setFont(QFont(QStringLiteral("Monospace"), 15));
        p.setPen(QColor(16, 185, 129));
        p.drawText(60, 130, QStringLiteral("TIME: %1 UTC").arg(QDateTime::currentDateTimeUtc().toString(QStringLiteral("yyyy-MM-dd hh:mm:ss.zzz"))));
        p.drawText(60, 165, QStringLiteral("GIMBAL: PITCH %1° | ROLL %2° | YAW %3°").arg(_pitch, 0, 'f', 1).arg(_roll, 0, 'f', 1).arg(_yaw, 0, 'f', 1));
        p.drawText(60, 200, QStringLiteral("OPTICS: ZOOM %1x | FOV %2° | LRF %3").arg(_zoom, 0, 'f', 1).arg(_fov, 0, 'f', 1).arg(lrfDistanceStr()));
        p.drawText(60, 235, QStringLiteral("STORAGE: %1").arg(fullPath));

        p.end();
    }

    if (snapImg.save(fullPath, "JPG", 92)) {
        qCDebug(CompanyPayloadLog) << "Snapshot image successfully written to storage:" << fullPath;
        notifyMediaScan(fullPath);
    } else {
        qCWarning(CompanyPayloadLog) << "Failed to write snapshot image to:" << fullPath;
    }

    emit snapshotCaptured(fullPath);

    CompanyCsvLogger *csv = CompanyCsvLogger::instance();
    if (csv) {
        // Correlate snapshot event with simulated telemetry
        csv->logSnapshotEvent(photoName,
                              0.0, 0.0, 0.0, 0.0,
                              0.0, 0.0, 0.0,
                              _pitch, _roll, _yaw,
                              _fov);
    }

    QTimer::singleShot(250, this, [this]() {
        _isCapturingPhoto = false;
        emit photoCaptureChanged();
    });
}

void SimulatedPayloadAdapter::startRecording()
{
    if (!_isRecording) {
        _isRecording = true;
        _recordStartTime = QDateTime::currentMSecsSinceEpoch();
        emit recordingChanged();

        const QString timeStr = QDateTime::currentDateTimeUtc().toString(QStringLiteral("yyyyMMdd_hhmmss"));
        const QString videoName = QStringLiteral("SIM_ECLIPSE_REC_%1.mp4").arg(timeStr);

        qCDebug(CompanyPayloadLog) << "Simulated video recording started:" << videoName;

        CompanyCsvLogger *csv = CompanyCsvLogger::instance();
        if (csv) {
            csv->logRecordStartEvent(videoName);
        }
    }
}

void SimulatedPayloadAdapter::stopRecording()
{
    if (_isRecording) {
        const int durationSec = static_cast<int>((QDateTime::currentMSecsSinceEpoch() - _recordStartTime) / 1000);
        _isRecording = false;
        emit recordingChanged();

        const QString timeStr = QDateTime::currentDateTimeUtc().toString(QStringLiteral("yyyyMMdd_hhmmss"));
        const QString videoName = QStringLiteral("SIM_ECLIPSE_REC_%1.mp4").arg(timeStr);

        qCDebug(CompanyPayloadLog) << "Simulated video recording stopped:" << videoName << "Duration:" << durationSec << "s";

        CompanyCsvLogger *csv = CompanyCsvLogger::instance();
        if (csv) {
            csv->logRecordStopEvent(videoName, durationSec);
        }
    }
}

void SimulatedPayloadAdapter::_recalculateFov()
{
    // Simulation-only optical model (Task 6):
    // Effective focal length f = 4.8mm * zoom
    // Sensor horizontal width ~ 5.37mm
    // HFOV_sim = 2 * atan(sensor_width / (2 * f)) * (180 / PI)
    // Clearly marked as simulated/calculated value without claiming physical ECLIPSE optical calibration.
    const float sensorWidthMm = 5.37f;
    _focalLength = 4.8f * _zoom;
    const float rawHfov = 2.0f * std::atan(sensorWidthMm / (2.0f * _focalLength)) * static_cast<float>(180.0 / M_PI);
    _fov = std::clamp(rawHfov, 2.0f, 60.0f);
    emit fovChanged();
}

void SimulatedPayloadAdapter::_onSimulationTick()
{
    _simTickCount++;

    // 1. Gimbal Pitch Slew towards _targetPitch (with strict safety clamp [-45.0, +100.0])
    const float pitchDiff = _targetPitch - _pitch;
    const float maxPitchStep = 2.0f; // 40 deg/s at 20 Hz
    if (std::abs(pitchDiff) <= maxPitchStep) {
        _pitch = _targetPitch;
    } else {
        _pitch += (pitchDiff > 0.0f ? maxPitchStep : -maxPitchStep);
    }
    _pitch = clampPitch(_pitch);

    // 2. Gimbal Yaw Slew towards _targetYaw
    const float yawDiff = _targetYaw - _yaw;
    const float maxYawStep = 3.0f; // 60 deg/s at 20 Hz
    if (std::abs(yawDiff) <= maxYawStep) {
        _yaw = _targetYaw;
    } else {
        _yaw += (yawDiff > 0.0f ? maxYawStep : -maxYawStep);
    }

    // 3. Realistic Gyro Stabilization Residual on Roll (sub-degree micro-oscillation)
    const double t = _elapsedTimer.elapsed() / 1000.0;
    _roll = static_cast<float>(0.04 * std::sin(t * 2.5));

    // 4. Synthetic Laser Rangefinder (LRF) Distance Fluctuations
    // Simulates dynamic slant distance to target with realistic jitter
    _lrfDistance = static_cast<float>(_baseLrfDistance + 12.0 * std::sin(t * 0.4) + 0.8 * std::cos(t * 1.7));
    _lrfValid = true;

    // 5. Emit updates at 20 Hz
    emit attitudeChanged();
    if (_simTickCount % 2 == 0) { // 10 Hz for LRF
        emit lrfDistanceChanged();
    }
}
