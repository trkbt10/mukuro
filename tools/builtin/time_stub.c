/*
 * Time stub for tools/builtin
 * Provides a proper wrapper for the C time() function
 */

#include <time.h>
#include <stdint.h>

/*
 * Get current time in seconds since Unix epoch
 * Wrapper to properly call time(NULL)
 */
int64_t moonbit_builtin_time_now(void) {
    return (int64_t)time(NULL);
}
