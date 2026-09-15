#include "capturewriter.hpp"

#include <QFile>
#include <QImageWriter>
#include <fcntl.h>
#include <mutex>
#include <sys/stat.h>
#include <unistd.h>

namespace sleepy {
bool writeCapturePng(const QImage& image, int outputFd) {
    if (image.isNull() || image.width() > 32768 || image.height() > 32768 ||
        qint64(image.width()) * image.height() > 67108864) return false;

    // Serialize validation and writes, including duplicated descriptors for one job.
    static std::mutex writerMutex;
    const std::lock_guard<std::mutex> guard(writerMutex);
    const int fd = ::fcntl(outputFd, F_DUPFD_CLOEXEC, 5);
    if (fd < 0) return false;
    struct Descriptor {
        int fd;
        ~Descriptor() { ::close(fd); }
    } owned{fd};
    struct stat info {};
    const int flags = ::fcntl(fd, F_GETFL);
    if (::fstat(fd, &info) != 0 || !S_ISREG(info.st_mode) || info.st_nlink != 0 ||
        info.st_uid != ::geteuid() || (info.st_mode & 07777) != 0600 || info.st_size != 0 ||
        flags < 0 || (flags & O_ACCMODE) == O_RDONLY || (flags & O_APPEND) != 0 ||
        ::lseek(fd, 0, SEEK_SET) != 0) return false;

    QFile file;
    bool saved = file.open(fd, QIODevice::WriteOnly, QFileDevice::DontCloseHandle);
    if (saved) {
        QImageWriter writer(&file, "png");
        saved = writer.write(image) && file.flush();
        file.close();
    }
    // No pathname exists to clean up or replace. The daemon rejects an empty FD.
    if (!saved) {
        ::ftruncate(fd, 0);
        ::lseek(fd, 0, SEEK_SET);
    }
    return saved;
}
}
