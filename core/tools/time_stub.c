/*
 * Time stub for core/tools
 */

#include <time.h>
#include <stdint.h>

int64_t moonbit_builtin_time_now(void) {
    return (int64_t)time(NULL);
}
