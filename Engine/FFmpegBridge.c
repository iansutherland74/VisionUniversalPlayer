#include "FFmpegBridge.h"
#include <stdlib.h>
#include <string.h>

// Conditional compilation:
// - On simulator: Use stub implementations (returns error codes)
// - On device: Use real FFmpeg (requires libavformat, libavcodec, libavutil)
//
// The FFMPEG_DEVICE_BUILD macro is set via Xcode build settings for device builds.
// For simulator: This will be undefined, using stubs.
// For device: Define as -DFFMPEG_DEVICE_BUILD=1 in project configuration.
//
// To enable real FFmpeg on device:
// 1. Obtain visionOS-compatible FFmpeg binaries (static .a or xcframework)
// 2. Add to project.yml HEADER_SEARCH_PATHS and LIBRARY_SEARCH_PATHS
// 3. Set Xcode scheme → Edit Scheme → Pre-actions to define the macro
// 4. Or update project.yml with device-specific OTHER_LDFLAGS

#ifndef FFMPEG_DEVICE_BUILD

// ============================================================================
// SIMULATOR BUILD (or when FFMPEG_DEVICE_BUILD is not defined)
// Stub implementations that return error codes
// ============================================================================

int ffmpeg_open(const char *url) {
    (void)url;
    return -1001; // FFmpeg not available on simulator
}

int ffmpeg_read_annexb_packet(int handle, uint8_t **data, int *size, double *ptsSeconds) {
    (void)handle;
    if (data) {
        *data = NULL;
    }
    if (size) {
        *size = 0;
    }
    if (ptsSeconds) {
        *ptsSeconds = 0.0;
    }
    return -1002; // FFmpeg not available
}

int ffmpeg_seek_seconds(int handle, double seconds) {
    (void)handle;
    (void)seconds;
    return -1003; // FFmpeg not available
}

void ffmpeg_free_packet(uint8_t *data) {
    if (data) {
        free(data);
    }
}

void ffmpeg_close(int handle) {
    (void)handle;
}

int ffmpeg_sw_open(const char *url) {
    (void)url;
    return -1101; // FFmpeg not available
}

int ffmpeg_sw_read_frame(
    int handle,
    uint8_t **data,
    int *size,
    int *width,
    int *height,
    double *ptsSeconds
) {
    (void)handle;
    if (data) {
        *data = NULL;
    }
    if (size) {
        *size = 0;
    }
    if (width) {
        *width = 0;
    }
    if (height) {
        *height = 0;
    }
    if (ptsSeconds) {
        *ptsSeconds = 0.0;
    }
    return -1102; // FFmpeg not available
}

int ffmpeg_sw_seek_seconds(int handle, double seconds) {
    (void)handle;
    (void)seconds;
    return -1103; // FFmpeg not available
}

void ffmpeg_sw_free_frame(uint8_t *data) {
    if (data) {
        free(data);
    }
}

void ffmpeg_sw_close(int handle) {
    (void)handle;
}

#else

// ============================================================================
// DEVICE BUILD (FFMPEG_DEVICE_BUILD defined): Real FFmpeg implementation
// ============================================================================
// Requires FFmpeg libraries linked and headers available

#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/avutil.h>
#include <libavutil/opt.h>

// Handle pool for managing multiple concurrent demuxers
#define MAX_HANDLES 32

typedef struct {
    AVFormatContext *fmt_ctx;
    int stream_index;
    const AVBitStreamFilter *bsf;
    AVBSFContext *bsf_ctx;
    AVPacket *packet;
} FFmpegHandle;

static FFmpegHandle handles[MAX_HANDLES] = {0};
static int handle_init = 0;

static void ffmpeg_init_once(void) {
    if (!handle_init) {
        memset(handles, 0, sizeof(handles));
        handle_init = 1;
    }
}

static int ffmpeg_alloc_handle(void) {
    for (int i = 0; i < MAX_HANDLES; i++) {
        if (handles[i].fmt_ctx == NULL) {
            return i;
        }
    }
    return -1;
}

int ffmpeg_open(const char *url) {
    ffmpeg_init_once();
    
    if (!url) return -1;
    
    int handle_id = ffmpeg_alloc_handle();
    if (handle_id < 0) return -1;
    
    FFmpegHandle *handle = &handles[handle_id];
    
    AVFormatContext *fmt_ctx = NULL;
    if (avformat_open_input(&fmt_ctx, url, NULL, NULL) < 0) {
        return -1;
    }
    
    if (avformat_find_stream_info(fmt_ctx, NULL) < 0) {
        avformat_close_input(&fmt_ctx);
        return -1;
    }
    
    int stream_index = av_find_best_stream(fmt_ctx, AVMEDIA_TYPE_VIDEO, -1, -1, NULL, 0);
    if (stream_index < 0) {
        avformat_close_input(&fmt_ctx);
        return -1;
    }
    
    AVStream *stream = fmt_ctx->streams[stream_index];
    const AVCodec *codec = avcodec_find_decoder(stream->codecpar->codec_id);
    if (!codec) {
        avformat_close_input(&fmt_ctx);
        return -1;
    }
    
    AVCodecContext *codec_ctx = avcodec_alloc_context3(codec);
    if (!codec_ctx) {
        avformat_close_input(&fmt_ctx);
        return -1;
    }
    
    avcodec_parameters_to_context(codec_ctx, stream->codecpar);
    
    if (avcodec_open2(codec_ctx, codec, NULL) < 0) {
        avcodec_free_context(&codec_ctx);
        avformat_close_input(&fmt_ctx);
        return -1;
    }
    
    // Initialize bitstream filter for Annex-B output
    const AVBitStreamFilter *bsf = av_bsf_get_by_name("h264_mp4toannexb");
    if (!bsf) {
        bsf = av_bsf_get_by_name("hevc_mp4toannexb");
    }
    
    AVBSFContext *bsf_ctx = NULL;
    if (bsf) {
        if (av_bsf_alloc(bsf, &bsf_ctx) < 0) {
            avcodec_free_context(&codec_ctx);
            avformat_close_input(&fmt_ctx);
            return -1;
        }
        avcodec_parameters_copy(bsf_ctx->par_in, stream->codecpar);
        if (av_bsf_init(bsf_ctx) < 0) {
            av_bsf_free(&bsf_ctx);
            avcodec_free_context(&codec_ctx);
            avformat_close_input(&fmt_ctx);
            return -1;
        }
    }
    
    handle->fmt_ctx = fmt_ctx;
    handle->stream_index = stream_index;
    handle->bsf = bsf;
    handle->bsf_ctx = bsf_ctx;
    handle->packet = av_packet_alloc();
    
    return handle_id;
}

int ffmpeg_read_annexb_packet(int handle_id, uint8_t **data, int *size, double *ptsSeconds) {
    if (handle_id < 0 || handle_id >= MAX_HANDLES) return -1;
    
    FFmpegHandle *handle = &handles[handle_id];
    if (!handle->fmt_ctx || !handle->packet) return -1;
    
    while (av_read_frame(handle->fmt_ctx, handle->packet) >= 0) {
        if (handle->packet->stream_index != handle->stream_index) {
            av_packet_unref(handle->packet);
            continue;
        }
        
        AVPacket *out_pkt = handle->packet;
        
        if (handle->bsf_ctx) {
            if (av_bsf_send_packet(handle->bsf_ctx, handle->packet) < 0) {
                av_packet_unref(handle->packet);
                return -1;
            }
            
            if (av_bsf_receive_packet(handle->bsf_ctx, out_pkt) < 0) {
                av_packet_unref(handle->packet);
                return -1;
            }
        }
        
        uint8_t *out_data = (uint8_t *)malloc(out_pkt->size);
        if (!out_data) {
            av_packet_unref(handle->packet);
            return -1;
        }
        
        memcpy(out_data, out_pkt->data, out_pkt->size);
        
        if (data) {
            *data = out_data;
        }
        if (size) {
            *size = out_pkt->size;
        }
        if (ptsSeconds && handle->fmt_ctx->streams[handle->stream_index]->time_base.num > 0) {
            AVStream *stream = handle->fmt_ctx->streams[handle->stream_index];
            *ptsSeconds = av_rescale_q(out_pkt->pts, stream->time_base, 
                                       (AVRational){1, 1000}) / 1000.0;
        }
        
        av_packet_unref(handle->packet);
        return 0;
    }
    
    // EOF
    return -4;
}

int ffmpeg_seek_seconds(int handle_id, double seconds) {
    if (handle_id < 0 || handle_id >= MAX_HANDLES) return -1;
    
    FFmpegHandle *handle = &handles[handle_id];
    if (!handle->fmt_ctx) return -1;
    
    AVStream *stream = handle->fmt_ctx->streams[handle->stream_index];
    int64_t timestamp = (int64_t)(seconds * stream->time_base.den / stream->time_base.num);
    
    if (av_seek_frame(handle->fmt_ctx, handle->stream_index, timestamp, AVSEEK_FLAG_BACKWARD) < 0) {
        return -1;
    }
    
    if (handle->bsf_ctx) {
        av_bsf_flush(handle->bsf_ctx);
    }
    
    return 0;
}

void ffmpeg_free_packet(uint8_t *data) {
    if (data) {
        free(data);
    }
}

void ffmpeg_close(int handle_id) {
    if (handle_id < 0 || handle_id >= MAX_HANDLES) return;
    
    FFmpegHandle *handle = &handles[handle_id];
    
    if (handle->bsf_ctx) {
        av_bsf_free(&handle->bsf_ctx);
    }
    if (handle->packet) {
        av_packet_free(&handle->packet);
    }
    if (handle->fmt_ctx) {
        avformat_close_input(&handle->fmt_ctx);
    }
    
    memset(handle, 0, sizeof(FFmpegHandle));
}

// Software decoding variants (similar to hardware variants above)
int ffmpeg_sw_open(const char *url) {
    // Reuse hardware open; decoding happens in FFmpegEngine.swift
    return ffmpeg_open(url);
}

int ffmpeg_sw_read_frame(
    int handle_id,
    uint8_t **data,
    int *size,
    int *width,
    int *height,
    double *ptsSeconds
) {
    // For visionOS, use hardware VideoToolbox decoding instead
    // This function is retained for compatibility but returns error
    (void)handle_id;
    (void)data;
    (void)size;
    (void)width;
    (void)height;
    (void)ptsSeconds;
    return -1102; // Software decoding not supported; use VideoToolbox instead
}

int ffmpeg_sw_seek_seconds(int handle_id, double seconds) {
    return ffmpeg_seek_seconds(handle_id, seconds);
}

void ffmpeg_sw_free_frame(uint8_t *data) {
    ffmpeg_free_packet(data);
}

void ffmpeg_sw_close(int handle_id) {
    ffmpeg_close(handle_id);
}

#endif // FFMPEG_DEVICE_BUILD
