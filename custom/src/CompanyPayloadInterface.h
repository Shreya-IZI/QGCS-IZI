#pragma once

#include <QtCore/QLoggingCategory>
#include <QtCore/QObject>
#include <QtCore/QString>
#include <algorithm>
#include <cmath>

Q_DECLARE_LOGGING_CATEGORY(CompanyPayloadLog)

/// Clean, vendor-neutral payload abstraction interface for IZI Ground Control Station.
/// Decouples UI, CSV telemetry logging, and DRDO UDP data broadcasting from concrete payload hardware.
class CompanyPayloadInterface : public QObject
{
    Q_OBJECT

    // Gimbal Properties
    Q_PROPERTY(float pitch READ pitch WRITE setPitch NOTIFY attitudeChanged)
    Q_PROPERTY(float yaw READ yaw WRITE setYaw NOTIFY attitudeChanged)
    Q_PROPERTY(float roll READ roll WRITE setRoll NOTIFY attitudeChanged)
    Q_PROPERTY(QString pitchStr READ pitchStr NOTIFY attitudeChanged)
    Q_PROPERTY(QString yawStr READ yawStr NOTIFY attitudeChanged)
    Q_PROPERTY(QString rollStr READ rollStr NOTIFY attitudeChanged)
    Q_PROPERTY(bool isStabilized READ isStabilized NOTIFY statusChanged)
    Q_PROPERTY(QString gimbalStatus READ gimbalStatus NOTIFY statusChanged)

    // Camera & Zoom Properties
    Q_PROPERTY(float zoom READ zoom WRITE setZoom NOTIFY zoomChanged)
    Q_PROPERTY(QString zoomStr READ zoomStr NOTIFY zoomChanged)
    Q_PROPERTY(float focus READ focus WRITE setFocus NOTIFY focusChanged)
    Q_PROPERTY(bool capturesPhotos READ capturesPhotos CONSTANT)
    Q_PROPERTY(bool capturesVideo READ capturesVideo CONSTANT)
    Q_PROPERTY(bool isRecording READ isRecording NOTIFY recordingChanged)
    Q_PROPERTY(bool isCapturingPhoto READ isCapturingPhoto NOTIFY photoCaptureChanged)
    Q_PROPERTY(QString activeSensor READ activeSensor NOTIFY activeSensorChanged)

    // Thermal Properties
    Q_PROPERTY(bool thermalAvailable READ thermalAvailable NOTIFY thermalStatusChanged)
    Q_PROPERTY(QString thermalPalette READ thermalPalette WRITE setThermalPalette NOTIFY thermalPaletteChanged)
    Q_PROPERTY(bool thermalStreamAvailable READ thermalStreamAvailable NOTIFY thermalStatusChanged)

    // Laser Rangefinder (LRF) Properties
    // (Notice: Read-only distance/validity telemetry. Laser firing commands are strictly omitted per safety rules)
    Q_PROPERTY(float lrfDistance READ lrfDistance NOTIFY lrfDistanceChanged)
    Q_PROPERTY(QString lrfDistanceStr READ lrfDistanceStr NOTIFY lrfDistanceChanged)
    Q_PROPERTY(bool lrfValid READ lrfValid NOTIFY lrfDistanceChanged)

    // Video & Optics Properties
    Q_PROPERTY(bool eoAvailable READ eoAvailable NOTIFY streamStatusChanged)
    Q_PROPERTY(float fov READ fov NOTIFY fovChanged)
    Q_PROPERTY(QString fovStr READ fovStr NOTIFY fovChanged)
    Q_PROPERTY(float focalLength READ focalLength NOTIFY zoomChanged)

    // Simulation Metadata
    Q_PROPERTY(bool isSimulation READ isSimulation CONSTANT)
    Q_PROPERTY(QString payloadModel READ payloadModel CONSTANT)

public:
    explicit CompanyPayloadInterface(QObject *parent = nullptr);
    ~CompanyPayloadInterface() override;

    static CompanyPayloadInterface *instance();
    static void setInstance(CompanyPayloadInterface *inst);

    // --- Gimbal Interface ---
    virtual float pitch() const = 0;
    virtual float yaw() const = 0;
    virtual float roll() const = 0;
    virtual QString pitchStr() const;
    virtual QString yawStr() const;
    virtual QString rollStr() const;
    virtual bool isStabilized() const = 0;
    virtual QString gimbalStatus() const = 0;

    Q_INVOKABLE virtual void setPitch(float pitchDeg);
    Q_INVOKABLE virtual void setYaw(float yawDeg) = 0;
    Q_INVOKABLE virtual void setRoll(float rollDeg) = 0;
    Q_INVOKABLE virtual void setPitchYaw(float pitchDeg, float yawDeg);
    Q_INVOKABLE virtual void center() = 0;

    // --- Camera Interface ---
    virtual float zoom() const = 0;
    virtual QString zoomStr() const;
    virtual float focus() const = 0;
    virtual bool capturesPhotos() const = 0;
    virtual bool capturesVideo() const = 0;
    virtual bool isRecording() const = 0;
    virtual bool isCapturingPhoto() const = 0;
    virtual QString activeSensor() const = 0;

    Q_INVOKABLE virtual void setZoom(float zoomFactor) = 0;
    Q_INVOKABLE virtual void stepZoom(int direction);
    Q_INVOKABLE virtual void setFocus(float focusValue) = 0;
    Q_INVOKABLE virtual void triggerSnapshot() = 0;
    Q_INVOKABLE virtual void startRecording() = 0;
    Q_INVOKABLE virtual void stopRecording() = 0;
    Q_INVOKABLE virtual void toggleRecording();
    Q_INVOKABLE virtual QString photoSaveDirectory();
    Q_INVOKABLE virtual void notifyMediaScan(const QString &filePath);

    // --- Thermal Interface ---
    virtual bool thermalAvailable() const = 0;
    virtual QString thermalPalette() const = 0;
    virtual bool thermalStreamAvailable() const = 0;
    Q_INVOKABLE virtual void setThermalPalette(const QString &palette) = 0;

    // --- LRF Interface (Telemetry only; no laser fire command) ---
    virtual float lrfDistance() const = 0;
    virtual QString lrfDistanceStr() const;
    virtual bool lrfValid() const = 0;

    // --- Video & Optics Interface ---
    virtual bool eoAvailable() const = 0;
    virtual float fov() const = 0;
    virtual QString fovStr() const;
    virtual float focalLength() const = 0;

    // --- Metadata ---
    virtual bool isSimulation() const = 0;
    virtual QString payloadModel() const = 0;

    // --- Safety Enforcement ---
    // Clamps pitch input strictly within [-45.0, +100.0] degrees
    static float clampPitch(float pitchDeg);

signals:
    void attitudeChanged();
    void statusChanged();
    void zoomChanged();
    void focusChanged();
    void recordingChanged();
    void photoCaptureChanged();
    void activeSensorChanged();
    void thermalStatusChanged();
    void thermalPaletteChanged();
    void lrfDistanceChanged();
    void streamStatusChanged();
    void fovChanged();
    void snapshotCaptured(const QString &filePath);

protected:
    static CompanyPayloadInterface *_instance;
};
