/*
 * Deflate Compression Stubs for NCD calculation
 * Uses system zlib
 */

#include <zlib.h>
#include <stdlib.h>
#include <string.h>

/*
 * Compress data using deflate algorithm
 * Returns: compressed size, or -1 on error
 *
 * dest_buf: output buffer (must be pre-allocated)
 * dest_len: max size of dest_buf
 * src_buf: input data
 * src_len: input data length
 */
int64_t moonbit_deflate_compress(
    unsigned char* dest_buf,
    int64_t dest_len,
    const unsigned char* src_buf,
    int64_t src_len
) {
    if (src_len == 0) {
        return 0;
    }

    uLongf compressed_len = (uLongf)dest_len;
    int result = compress2(
        dest_buf,
        &compressed_len,
        src_buf,
        (uLong)src_len,
        Z_DEFAULT_COMPRESSION
    );

    if (result != Z_OK) {
        return -1;
    }

    return (int64_t)compressed_len;
}

/*
 * Get maximum compressed size for given input size
 * Uses zlib's compressBound
 */
int64_t moonbit_deflate_bound(int64_t src_len) {
    return (int64_t)compressBound((uLong)src_len);
}

/*
 * Compress and return only the compressed size
 * Useful for NCD calculation where we don't need the actual compressed data
 */
int64_t moonbit_deflate_size(
    const unsigned char* src_buf,
    int64_t src_len
) {
    if (src_len == 0) {
        return 0;
    }

    uLongf bound = compressBound((uLong)src_len);
    unsigned char* temp_buf = (unsigned char*)malloc(bound);
    if (!temp_buf) {
        return -1;
    }

    uLongf compressed_len = bound;
    int result = compress2(
        temp_buf,
        &compressed_len,
        src_buf,
        (uLong)src_len,
        Z_DEFAULT_COMPRESSION
    );

    free(temp_buf);

    if (result != Z_OK) {
        return -1;
    }

    return (int64_t)compressed_len;
}
