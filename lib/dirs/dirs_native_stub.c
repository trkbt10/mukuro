/*
 * MoonBit Native FFI Stubs for dirs module
 * OS standard directory resolution
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#ifdef _WIN32
#define OS_NAME "Windows"
#elif defined(__APPLE__)
#define OS_NAME "Darwin"
#elif defined(__linux__)
#define OS_NAME "Linux"
#else
#define OS_NAME "Unknown"
#endif

/*
 * Get home directory into buffer
 * Returns: bytes written (excluding null), or -1 on error
 */
int moonbit_get_home_dir(char* buffer, int buffer_len) {
    if (!buffer || buffer_len <= 0) return -1;

    const char* home = getenv("HOME");
    if (!home) return -1;

    int len = strlen(home);
    if (len >= buffer_len) return -1;

    memcpy(buffer, home, len);
    return len;
}

/*
 * Get OS name into buffer
 * Returns: bytes written (excluding null), or -1 on error
 */
int moonbit_get_os_name(char* buffer, int buffer_len) {
    if (!buffer || buffer_len <= 0) return -1;

    const char* os_name = OS_NAME;
    int len = strlen(os_name);
    if (len >= buffer_len) return -1;

    memcpy(buffer, os_name, len);
    return len;
}

/*
 * Get environment variable into buffer
 * name: null-terminated UTF-8 string
 * Returns: bytes written (excluding null), 0 if not found, -1 on error
 */
int moonbit_getenv_safe(const char* name, char* buffer, int buffer_len) {
    if (!name || !buffer || buffer_len <= 0) return -1;

    const char* value = getenv(name);
    if (!value) return 0;

    int len = strlen(value);
    if (len >= buffer_len) return -1;

    memcpy(buffer, value, len);
    return len;
}
