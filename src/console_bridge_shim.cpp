#include <console_bridge/console.h>
#include <cstdarg>
#include <cstdio>

namespace console_bridge
{
    void log(const char * /*file*/, int /*line*/, LogLevel /*level*/, const char *fmt, ...)
    {
        va_list args;
        va_start(args, fmt);
        std::vfprintf(stderr, fmt, args);
        std::fputc('\n', stderr);
        va_end(args);
    }
} // namespace console_bridge
