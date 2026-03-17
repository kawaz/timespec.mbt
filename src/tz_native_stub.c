#include <time.h>
#include "moonbit.h"

// Returns the local timezone offset in minutes (e.g. JST = +540)
MOONBIT_FFI_EXPORT int32_t local_tz_offset_minutes(void) {
    time_t t = time(NULL);
    struct tm lt;
    localtime_r(&t, &lt);
    return (int32_t)(lt.tm_gmtoff / 60);
}
