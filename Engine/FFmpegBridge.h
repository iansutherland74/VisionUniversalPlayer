#ifndef FFMPEG_BRIDGE_H
#define FFMPEG_BRIDGE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Opens a media file from a URL using FFmpeg.
 * Supports HTTP/HTTPS/FTP/WebDAV and container formats (MP4, MKV, TS, HLS).
 *
 * @param url The URL to open (e.g., "http://example.com/video.mp4", "ftp://...", etc.)
 * @return A handle >= 0 on success, < 0 on error
 */
int ffmpeg_open(const char *url);

/**
 * Reads the next Annex-B formatted video packet from the opened media.
 * Automatically detects codec and applies appropriate bitstream filters.
 *
 * @param handle Handle returned by ffmpeg_open()
 * @param data Output buffer (allocated by function, must be freed with ffmpeg_free_packet)
 * @param size Output size of data buffer
 * @param ptsSeconds Output PTS in seconds (can be NULL)
 * @return 0 on success, < 0 on EOF or error
 */
int ffmpeg_read_annexb_packet(int handle, uint8_t **data, int *size, double *ptsSeconds);

/**
 * Seeks the opened media to a target playback time in seconds.
 *
 * @param handle Handle returned by ffmpeg_open()
 * @param seconds Target time in seconds from stream start
 * @return 0 on success, < 0 on error
 */
int ffmpeg_seek_seconds(int handle, double seconds);

/**
 * Frees a packet buffer allocated by ffmpeg_read_annexb_packet().
 *
 * @param data Pointer to data buffer returned by ffmpeg_read_annexb_packet
 */
void ffmpeg_free_packet(uint8_t *data);

/**
 * Closes the media file and frees resources.
 *
 * @param handle Handle returned by ffmpeg_open()
 */
void ffmpeg_close(int handle);

/**
 * Opens a media file for software frame decoding through FFmpeg/libavcodec.
 *
 * @param url The URL to open
 * @return A handle >= 0 on success, < 0 on error
 */
int ffmpeg_sw_open(const char *url);

/**
 * Reads the next decoded frame converted to packed BGRA bytes.
 * The output buffer is allocated by FFmpeg and must be released with
 * ffmpeg_sw_free_frame().
 *
 * @param handle Handle returned by ffmpeg_sw_open()
 * @param data Output pointer to BGRA bytes
 * @param size Output byte size
 * @param width Output frame width
 * @param height Output frame height
 * @param ptsSeconds Output presentation timestamp in seconds
 * @return 0 on success, < 0 on EOF or error
 */
int ffmpeg_sw_read_frame(
	int handle,
	uint8_t **data,
	int *size,
	int *width,
	int *height,
	double *ptsSeconds
);

/**
 * Seeks a software-decoder handle to a target playback time.
 *
 * @param handle Handle returned by ffmpeg_sw_open()
 * @param seconds Target time in seconds from stream start
 * @return 0 on success, < 0 on error
 */
int ffmpeg_sw_seek_seconds(int handle, double seconds);

/**
 * Frees a frame buffer allocated by ffmpeg_sw_read_frame().
 */
void ffmpeg_sw_free_frame(uint8_t *data);

/**
 * Closes a software-decoder handle and releases resources.
 */
void ffmpeg_sw_close(int handle);

/**
 * Returns whether the FFmpeg demux/decode bridge is available in this build.
 * 1 = available, 0 = stubbed/unavailable.
 */
int ffmpeg_bridge_is_available(void);

/**
 * Returns whether the FFmpeg software-decoder bridge is available in this build.
 * 1 = available, 0 = stubbed/unavailable.
 */
int ffmpeg_sw_bridge_is_available(void);

#ifdef __cplusplus
}
#endif

#endif // FFMPEG_BRIDGE_H
