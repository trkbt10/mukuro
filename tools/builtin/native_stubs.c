/**
 * Native FFI stubs for tools/builtin package tests
 * Minimal implementations for linking test executables
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <dirent.h>
#include <sys/stat.h>
#include <errno.h>

/* popen with UTF-8 bytes, returns handle */
int64_t moonbit_popen_bytes(const unsigned char* command, const unsigned char* mode) {
    FILE* f = popen((const char*)command, (const char*)mode);
    return (int64_t)(uintptr_t)f;
}

/* pclose with handle */
int moonbit_pclose_handle(int64_t handle) {
    FILE* f = (FILE*)(uintptr_t)handle;
    if (!f) return -1;
    return pclose(f);
}

/* fread with handle */
int moonbit_fread_handle(unsigned char* buffer, int size, int nmemb, int64_t handle) {
    FILE* f = (FILE*)(uintptr_t)handle;
    if (!f) return -1;
    return (int)fread(buffer, (size_t)size, (size_t)nmemb, f);
}

/* fopen with UTF-8 bytes, returns handle */
int64_t moonbit_fopen_bytes(const unsigned char* path, const unsigned char* mode) {
    FILE* f = fopen((const char*)path, (const char*)mode);
    return (int64_t)(uintptr_t)f;
}

/* fwrite with handle */
int moonbit_fwrite_handle(const unsigned char* data, int size, int nmemb, int64_t handle) {
    FILE* f = (FILE*)(uintptr_t)handle;
    if (!f) return -1;
    return (int)fwrite(data, (size_t)size, (size_t)nmemb, f);
}

/* fclose with handle */
int moonbit_fclose_handle(int64_t handle) {
    FILE* f = (FILE*)(uintptr_t)handle;
    if (!f) return -1;
    return fclose(f);
}

/* UTF-16LE to UTF-8 helper */
static int utf16le_to_utf8(const char* src_utf16, char* dst, int dst_len) {
    int di = 0;
    const unsigned char* s = (const unsigned char*)src_utf16;
    while (di < dst_len - 1) {
        uint16_t ch = s[0] | (s[1] << 8);
        if (ch == 0) break;
        if (ch < 0x80) {
            dst[di++] = (char)ch;
        } else if (ch < 0x800) {
            if (di + 1 >= dst_len - 1) break;
            dst[di++] = (char)(0xC0 | (ch >> 6));
            dst[di++] = (char)(0x80 | (ch & 0x3F));
        } else {
            if (di + 2 >= dst_len - 1) break;
            dst[di++] = (char)(0xE0 | (ch >> 12));
            dst[di++] = (char)(0x80 | ((ch >> 6) & 0x3F));
            dst[di++] = (char)(0x80 | (ch & 0x3F));
        }
        s += 2;
    }
    dst[di] = '\0';
    return di;
}

/* access with UTF-16LE path */
int moonbit_access(const char* path_utf16, int mode) {
    char path[1024];
    if (utf16le_to_utf8(path_utf16, path, sizeof(path)) < 0) return -1;
    return access(path, mode);
}

/* remove with UTF-16LE path */
int moonbit_remove(const char* path_utf16) {
    char path[1024];
    if (utf16le_to_utf8(path_utf16, path, sizeof(path)) < 0) return -1;
    return remove(path);
}

/* list_dir with UTF-16LE path, UTF-16LE output */
int moonbit_list_dir(const char* path_utf16, char* buffer, int buffer_len) {
    char path[1024];
    if (utf16le_to_utf8(path_utf16, path, sizeof(path)) < 0) return -1;
    DIR* dir = opendir(path);
    if (!dir) return -1;
    int offset = 0;
    struct dirent* entry;
    while ((entry = readdir(dir)) != NULL) {
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) continue;
        const char* name = entry->d_name;
        int name_len = strlen(name);
        /* Convert to UTF-16LE */
        for (int i = 0; i < name_len; i++) {
            if (offset + 2 > buffer_len) break;
            buffer[offset++] = name[i];
            buffer[offset++] = 0;
        }
        /* Add newline separator */
        if (offset + 2 <= buffer_len) {
            buffer[offset++] = '\n';
            buffer[offset++] = 0;
        }
    }
    closedir(dir);
    return offset;
}

/* mkdir_recursive with UTF-16LE path */
int moonbit_mkdir_recursive(const char* path_utf16, int mode) {
    char path[1024];
    if (utf16le_to_utf8(path_utf16, path, sizeof(path)) < 0) return -1;
    char tmp[1024];
    strncpy(tmp, path, sizeof(tmp) - 1);
    tmp[sizeof(tmp) - 1] = '\0';
    size_t len = strlen(tmp);
    if (len > 0 && tmp[len - 1] == '/') tmp[len - 1] = '\0';
    for (char* p = tmp + 1; *p; p++) {
        if (*p == '/') {
            *p = '\0';
            mkdir(tmp, (mode_t)mode);
            *p = '/';
        }
    }
    return mkdir(tmp, (mode_t)mode) == 0 || errno == EEXIST ? 0 : -1;
}
