// Native FFI stubs for hello_world_native plugin
#include <stdio.h>
#include <string.h>

int moonbit_read_stdin_line(unsigned char* buffer, int buffer_len) {
    if (buffer == NULL || buffer_len <= 0) {
        return -1;
    }
    if (fgets((char*)buffer, buffer_len, stdin) == NULL) {
        return -1;
    }
    int len = strlen((char*)buffer);
    // Remove trailing newline
    if (len > 0 && buffer[len - 1] == '\n') {
        buffer[len - 1] = '\0';
        len--;
    }
    return len;
}

int moonbit_write_stdout(const unsigned char* data, int len) {
    if (data == NULL || len <= 0) {
        return 0;
    }
    return fwrite(data, 1, len, stdout);
}
