#include "CompanyPayloadInterface.h"
#include "QGCLoggingCategory.h"

QGC_LOGGING_CATEGORY(CompanyPayloadLog, "Company.Payload")

CompanyPayloadInterface *CompanyPayloadInterface::_instance = nullptr;

CompanyPayloadInterface::CompanyPayloadInterface(QObject *parent)
    : QObject(parent)
{
    if (!_instance) {
        _instance = this;
    }
}

CompanyPayloadInterface::~CompanyPayloadInterface()
{
    if (_instance == this) {
        _instance = nullptr;
    }
}

CompanyPayloadInterface *CompanyPayloadInterface::instance()
{
    return _instance;
}

void CompanyPayloadInterface::setInstance(CompanyPayloadInterface *inst)
{
    _instance = inst;
}

float CompanyPayloadInterface::clampPitch(float pitchDeg)
{
    if (std::isnan(pitchDeg)) {
        return 0.0f;
    }
    // Hard constraint: [-45.0, +100.0] degrees
    return std::clamp(pitchDeg, -45.0f, 100.0f);
}

void CompanyPayloadInterface::setPitch(float pitchDeg)
{
    Q_UNUSED(pitchDeg);
}

void CompanyPayloadInterface::setPitchYaw(float pitchDeg, float yawDeg)
{
    setPitch(clampPitch(pitchDeg));
    setYaw(yawDeg);
}

void CompanyPayloadInterface::stepZoom(int direction)
{
    const float step = (direction > 0) ? 1.0f : -1.0f;
    setZoom(zoom() + step);
}

void CompanyPayloadInterface::toggleRecording()
{
    if (isRecording()) {
        stopRecording();
    } else {
        startRecording();
    }
}

QString CompanyPayloadInterface::pitchStr() const
{
    return QString::number(pitch(), 'f', 1) + QStringLiteral("°");
}

QString CompanyPayloadInterface::yawStr() const
{
    return QString::number(yaw(), 'f', 1) + QStringLiteral("°");
}

QString CompanyPayloadInterface::rollStr() const
{
    return QString::number(roll(), 'f', 1) + QStringLiteral("°");
}

QString CompanyPayloadInterface::zoomStr() const
{
    return QString::number(zoom(), 'f', 1) + QStringLiteral("x");
}

QString CompanyPayloadInterface::lrfDistanceStr() const
{
    if (!lrfValid() || lrfDistance() <= 0.01f) {
        return QStringLiteral("N/A");
    }
    return QString::number(lrfDistance(), 'f', 1) + QStringLiteral(" m");
}

QString CompanyPayloadInterface::fovStr() const
{
    if (fov() <= 0.1f) {
        return QStringLiteral("N/A");
    }
    return QString::number(fov(), 'f', 1) + QStringLiteral("°");
}

#include <QtCore/QStandardPaths>
#include <QtCore/QDir>
#include <QtCore/QFileInfo>

#if defined(Q_OS_ANDROID)
#include <QtCore/QJniObject>
#include <QtCore/QJniEnvironment>
#include <QtCore/QCoreApplication>
#endif

QString CompanyPayloadInterface::photoSaveDirectory()
{
    QString dirPath;

#if defined(Q_OS_ANDROID)
    const QString pictures = QStandardPaths::writableLocation(QStandardPaths::PicturesLocation);
    if (!pictures.isEmpty()) {
        dirPath = pictures + QStringLiteral("/IZI_GCS");
    }
#else
    const QString pictures = QStandardPaths::writableLocation(QStandardPaths::PicturesLocation);
    if (!pictures.isEmpty()) {
        dirPath = pictures + QStringLiteral("/IZI_GCS");
    } else {
        dirPath = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation) + QStringLiteral("/IZI_GCS/Photos");
    }
#endif

    if (dirPath.isEmpty()) {
        dirPath = QDir::homePath() + QStringLiteral("/Pictures/IZI_GCS");
    }

    QDir dir(dirPath);
    if (!dir.exists()) {
        dir.mkpath(QStringLiteral("."));
    }

    return dirPath;
}

void CompanyPayloadInterface::notifyMediaScan(const QString &filePath)
{
    if (filePath.isEmpty()) {
        return;
    }
    qCDebug(CompanyPayloadLog) << "Notifying Media Scanner for saved photo:" << filePath;
#if defined(Q_OS_ANDROID)
    try {
        QJniObject context = QNativeInterface::QAndroidApplication::context();
        if (context.isValid()) {
            QJniObject jPath = QJniObject::fromString(filePath);
            QJniEnvironment env;
            jclass stringClass = env->FindClass("java/lang/String");
            jobjectArray paths = env->NewObjectArray(1, stringClass, jPath.object<jstring>());
            QJniObject::callStaticMethod<void>(
                "android/media/MediaScannerConnection",
                "scanFile",
                "(Landroid/content/Context;[Ljava/lang/String;[Ljava/lang/String;Landroid/media/MediaScannerConnection$OnScanCompletedListener;)V",
                context.object(),
                paths,
                nullptr,
                nullptr);
        }
    } catch (...) {
        qCWarning(CompanyPayloadLog) << "MediaScannerConnection call exception for" << filePath;
    }
#endif
}

