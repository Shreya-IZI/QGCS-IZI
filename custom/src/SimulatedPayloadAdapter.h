#pragma once

#include "CompanyPayloadInterface.h"
#include <QtCore/QElapsedTimer>
#include <QtCore/QTimer>

/// Deterministic simulation adapter for MotionMatics ECLIPSE X-LR payload.
/// Emulates realistic 3-axis gimbal dynamics, optical zoom FOV changes, LRF ranging,
/// and camera event workflows without requiring physical payload hardware.
class SimulatedPayloadAdapter : public CompanyPayloadInterface
{
    Q_OBJECT

public:
    explicit SimulatedPayloadAdapter(QObject *parent = nullptr);
    ~SimulatedPayloadAdapter() override;

    // --- Gimbal Implementation ---
    float pitch() const override { return _pitch; }
    float yaw() const override { return _yaw; }
    float roll() const override { return _roll; }
    bool isStabilized() const override { return true; }
    QString gimbalStatus() const override { return QStringLiteral("STABILIZED (SIMULATION)"); }

    void setPitch(float pitchDeg) override;
    void setYaw(float yawDeg) override;
    void setRoll(float rollDeg) override;
    void center() override;

    // --- Camera Implementation ---
    float zoom() const override { return _zoom; }
    float focus() const override { return _focus; }
    bool capturesPhotos() const override { return true; }
    bool capturesVideo() const override { return true; }
    bool isRecording() const override { return _isRecording; }
    bool isCapturingPhoto() const override { return _isCapturingPhoto; }
    QString activeSensor() const override { return _activeSensor; }

    void setZoom(float zoomFactor) override;
    void setFocus(float focusValue) override;
    void triggerSnapshot() override;
    void startRecording() override;
    void stopRecording() override;

    // --- Thermal Implementation ---
    bool thermalAvailable() const override { return true; }
    QString thermalPalette() const override { return _thermalPalette; }
    bool thermalStreamAvailable() const override { return true; }
    void setThermalPalette(const QString &palette) override;

    // --- LRF Implementation (Read-only; no laser firing command) ---
    float lrfDistance() const override { return _lrfDistance; }
    bool lrfValid() const override { return _lrfValid; }

    // --- Video & Optics Implementation ---
    bool eoAvailable() const override { return true; }
    float fov() const override { return _fov; }
    float focalLength() const override { return _focalLength; }

    // --- Metadata ---
    bool isSimulation() const override { return true; }
    QString payloadModel() const override { return QStringLiteral("MotionMatics ECLIPSE X-LR (SIMULATION)"); }

private slots:
    void _onSimulationTick();

private:
    void _recalculateFov();

    // Gimbal state
    float _pitch = 0.0f;
    float _yaw = 0.0f;
    float _roll = 0.0f;
    float _targetPitch = 0.0f;
    float _targetYaw = 0.0f;

    // Camera & Optics state
    float _zoom = 1.0f;           // 1.0x to 30.0x
    float _focus = 0.5f;          // 0.0 to 1.0
    float _fov = 58.4f;           // Simulated HFOV (deg)
    float _focalLength = 4.8f;    // Simulated focal length (mm)
    bool  _isRecording = false;
    bool  _isCapturingPhoto = false;
    QString _activeSensor = QStringLiteral("EO");
    QString _thermalPalette = QStringLiteral("WHITE_HOT");

    // LRF state
    float _baseLrfDistance = 1250.0f;
    float _lrfDistance = 1250.0f;
    bool  _lrfValid = true;

    // Timers & counters
    QTimer _simTimer;
    QElapsedTimer _elapsedTimer;
    qint64 _recordStartTime = 0;
    quint64 _simTickCount = 0;
};
