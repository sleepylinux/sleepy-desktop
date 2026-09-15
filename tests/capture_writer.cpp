#include "../src/plugin/src/Sleepy/capturewriter.hpp"
#include <QCoreApplication>
#include <QFile>
#include <QImage>
#include <QTemporaryFile>
#include <atomic>
#include <csignal>
#include <fcntl.h>
#include <iostream>
#include <stdexcept>
#include <thread>
#include <sys/mman.h>
#include <sys/resource.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>
namespace {
void expect(bool value, const char* message) { if (!value) throw std::runtime_error(message); }
struct Memfd {
    int fd = ::memfd_create("sleepy-capture-test", MFD_CLOEXEC | MFD_ALLOW_SEALING);
    Memfd() { expect(fd >= 0 && ::fchmod(fd, 0600) == 0, "private memfd"); }
    ~Memfd() { ::close(fd); }
};
QByteArray read(int fd) {
    QFile file;
    expect(file.open(fd, QIODevice::ReadOnly, QFileDevice::DontCloseHandle), "read FD");
    expect(file.seek(0), "rewind FD"); return file.readAll();
}
off_t size(int fd) {
    struct stat info {};
    expect(::fstat(fd, &info) == 0, "original FD remains open"); return info.st_size;
}
}
int main(int argc, char** argv) {
    QCoreApplication app(argc, argv);
    try {
        QImage pixels(3, 2, QImage::Format_ARGB32); pixels.fill(QColor(112, 64, 192));
        Memfd valid;
        expect(sleepy::writeCapturePng(pixels, valid.fd), "valid PNG write");
        const auto original = read(valid.fd);
        expect(QImage::fromData(original, "PNG") == pixels, "real pixels preserved");
        struct stat info {};
        expect(::fstat(valid.fd, &info) == 0 && info.st_nlink == 0 &&
            (info.st_mode & 07777) == 0600 && info.st_uid == ::geteuid(), "private anonymous output");
        expect(!sleepy::writeCapturePng(pixels, valid.fd) && read(valid.fd) == original, "existing PNG preserved");
        QTemporaryFile linked; expect(linked.open(), "linked fixture");
        expect(!linked.fileName().isEmpty(), "materialize linked filename");
        expect(!sleepy::writeCapturePng(pixels, linked.handle()) && linked.size() == 0, "linked file rejected untouched");
        const QString alias = linked.fileName() + ".link";
        expect(QFile::link(linked.fileName(), alias), "symlink fixture");
        QFile throughLink(alias); expect(throughLink.open(QIODevice::ReadWrite), "open symlink fixture");
        expect(!sleepy::writeCapturePng(pixels, throughLink.handle()), "symlink target rejected");
        expect(QFile::remove(alias), "remove test symlink");
        Memfd mode; expect(::fchmod(mode.fd, 0640) == 0, "unsafe mode fixture");
        expect(!sleepy::writeCapturePng(pixels, mode.fd) && size(mode.fd) == 0, "unsafe mode rejected");
        Memfd data; expect(::write(data.fd, "keep", 4) == 4, "existing data fixture");
        expect(!sleepy::writeCapturePng(pixels, data.fd) && read(data.fd) == "keep", "existing data preserved");
        Memfd invalid;
        expect(!sleepy::writeCapturePng(QImage(), invalid.fd), "empty image rejected");
        expect(!sleepy::writeCapturePng(QImage(32769, 1, QImage::Format_ARGB32), invalid.fd), "oversized image rejected");
        expect(size(invalid.fd) == 0 && !sleepy::writeCapturePng(pixels, -1), "invalid input untouched");
        const QByteArray fdPath = QByteArray("/proc/self/fd/") + QByteArray::number(invalid.fd);
        const int readOnly = ::open(fdPath.constData(), O_RDONLY | O_CLOEXEC);
        expect(readOnly >= 0 && !sleepy::writeCapturePng(pixels, readOnly), "read-only FD rejected");
        ::close(readOnly); expect(size(invalid.fd) == 0, "read-only FD untouched");
        Memfd concurrent; std::atomic<int> started = 0, successes = 0;
        auto write = [&] {
            ++started; while (started.load() != 2) std::this_thread::yield();
            if (sleepy::writeCapturePng(pixels, concurrent.fd)) ++successes;
        };
        std::thread first(write), second(write); first.join(); second.join();
        expect(successes == 1, "concurrent duplicate calls have one winner");
        expect(QImage::fromData(read(concurrent.fd), "PNG") == pixels, "concurrent PNG complete");
        Memfd failure; const pid_t child = ::fork(); expect(child >= 0, "fork write failure");
        if (child == 0) {
            ::signal(SIGXFSZ, SIG_IGN); const struct rlimit limit {16, 16};
            if (::setrlimit(RLIMIT_FSIZE, &limit) != 0) ::_exit(2);
            ::_exit(sleepy::writeCapturePng(pixels, failure.fd) ? 3 : 0);
        }
        int status = 0;
        expect(::waitpid(child, &status, 0) == child && WIFEXITED(status) && WEXITSTATUS(status) == 0,
            "actual partial PNG write failure cannot report success");
        expect(size(failure.fd) == 0, "failed write truncates anonymous bytes");
        std::cout << "PASS: anonymous capture writer preserves pixels and rejects unsafe or failed writes\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "capture writer: " << error.what() << '\n'; return 1;
    }
}
