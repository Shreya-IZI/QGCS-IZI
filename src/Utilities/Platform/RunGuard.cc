#include "RunGuard.h"

#include <QtCore/QCryptographicHash>
#include <QtCore/QCoreApplication>
#include <QtCore/QDir>
#include <QtCore/QStandardPaths>
#include <QtCore/QThread>

#if defined(Q_OS_UNIX)
#include <signal.h>
#endif

RunGuard::RunGuard(const QString &key)
    : _key(key)
    , _lockFilePath(lockDir() + QLatin1String("/qgc-") + generateKeyHash(key, QLatin1String("_lock")) + QLatin1String(".lock"))
    , _lockFile(_lockFilePath)
{
    // Recover instantly from stale locks after crashes.
    _lockFile.setStaleLockTime(0);
}

RunGuard::~RunGuard()
{
    release();
}

bool RunGuard::isAnotherRunning()
{
    if (_lockFile.isLocked()) {
        return false;
    }

    if (_lockFile.tryLock(0)) {
        _lockFile.unlock();
        return false;
    }

    switch (_lockFile.error()) {
    case QLockFile::NoError:
        return false;
    case QLockFile::LockFailedError:
        return true;
    case QLockFile::PermissionError:
        qWarning() << "QLockFile PermissionError: Unable to access lock file at" << _lockFile.fileName();
        break;
    case QLockFile::UnknownError:
        qWarning() << "QLockFile UnknownError: An unknown error occurred with lock file at" << _lockFile.fileName();
        break;
    default:
        break;
    }

    return true;
}

bool RunGuard::tryToRun()
{
    if (_lockFile.isLocked()) {
        return true;
    }

    if (_lockFile.tryLock(0)) {
        return true;
    }

#if !defined(Q_OS_ANDROID) && !defined(Q_OS_IOS) && defined(Q_OS_UNIX)
    // If another instance holds the lock, attempt a clean takeover to prevent deadlocks
    qint64 existingPid = 0;
    QString existingHost, existingApp;
    if (_lockFile.getLockInfo(&existingPid, &existingHost, &existingApp) && existingPid > 0 && existingPid != QCoreApplication::applicationPid()) {
        qWarning() << "Previous QGroundControl instance (PID" << existingPid << ") detected. Performing clean takeover...";
        ::kill(static_cast<pid_t>(existingPid), SIGTERM);
        QThread::msleep(400);
        if (::kill(static_cast<pid_t>(existingPid), 0) == 0) {
            ::kill(static_cast<pid_t>(existingPid), SIGKILL);
            QThread::msleep(200);
        }
        _lockFile.removeStaleLockFile();
        return _lockFile.tryLock(0);
    }
#endif

    return false;
}

void RunGuard::release()
{
    if (_lockFile.isLocked()) {
        _lockFile.unlock();
    }
}

QString RunGuard::generateKeyHash(const QString &key, const QString &salt)
{
    QByteArray data;
    (void) data.append(key.toUtf8());
    (void) data.append(salt.toUtf8());
    const QByteArray hex = QCryptographicHash::hash(data, QCryptographicHash::Sha1).toHex();
    return QString::fromLatin1(hex);
}

QString RunGuard::lockDir()
{
    QString dir = QStandardPaths::writableLocation(QStandardPaths::TempLocation);
    if (dir.isEmpty()) {
        dir = QDir::tempPath();
    }

    if (!QDir().mkpath(dir)) {
        qWarning() << "RunGuard: Failed to create lock directory:" << dir;
        return QString();
    }

    return dir;
}
