#include <time.h>
#include "moonbit.h"

// Returns the local timezone offset in minutes (e.g. JST = +540)
// Falls back to 0 (UTC) if time() or localtime_r() fails.
MOONBIT_FFI_EXPORT int32_t local_tz_offset_minutes(void) {
    time_t t = time(NULL);
    if (t == (time_t)-1) {
        return 0;
    }
    struct tm lt;
    if (localtime_r(&t, &lt) == NULL) {
        return 0;
    }
    return (int32_t)(lt.tm_gmtoff / 60);
}
