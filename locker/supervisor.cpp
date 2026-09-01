#include <cerrno>
#include <cstdlib>

#include <sys/wait.h>
#include <unistd.h>

int main(int argc, char **argv)
{
    if (argc < 2 || argv == nullptr || argv[1] == nullptr) {
        return EXIT_FAILURE;
    }

    const pid_t child = ::fork();
    if (child < 0) {
        return EXIT_FAILURE;
    }
    if (child == 0) {
        ::execv(argv[1], argv + 1);
        ::_exit(127);
    }

    int status = 0;
    pid_t waited = -1;
    do {
        waited = ::waitpid(child, &status, 0);
    } while (waited < 0 && errno == EINTR);
    if (waited != child) {
        return EXIT_FAILURE;
    }
    if (WIFEXITED(status)) {
        const int childStatus = WEXITSTATUS(status);
        return childStatus == EXIT_SUCCESS ? EXIT_FAILURE : childStatus;
    }
    if (WIFSIGNALED(status)) {
        return 128 + WTERMSIG(status);
    }
    return EXIT_FAILURE;
}
