#include <iostream>
#include <string>
#include <cstring>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <chrono>
#include <thread>

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/opt.h>
}

const char* VIDEO_FILE = "../test.mp4";
const char* TARGET_IP = "127.0.0.1";
const int TARGET_PORT = 3334; // 与接收端端口一致
const int PAYLOAD_SIZE = 1392; // 关键修改：载荷1392 + 头8 = 1400字节

int main() {
    int sockfd = socket(AF_INET, SOCK_DGRAM, 0);
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(TARGET_PORT);
    inet_pton(AF_INET, TARGET_IP, &addr.sin_addr);

    AVFormatContext* fmt_ctx = nullptr;
    if (avformat_open_input(&fmt_ctx, VIDEO_FILE, nullptr, nullptr) < 0) return -1;
    avformat_find_stream_info(fmt_ctx, nullptr);

    int video_idx = -1;
    for (unsigned int i = 0; i < fmt_ctx->nb_streams; i++)
        if (fmt_ctx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) video_idx = i;

    // 解码器配置
    const AVCodec* dec_codec = avcodec_find_decoder(fmt_ctx->streams[video_idx]->codecpar->codec_id);
    AVCodecContext* dec_ctx = avcodec_alloc_context3(dec_codec);
    avcodec_parameters_to_context(dec_ctx, fmt_ctx->streams[video_idx]->codecpar);
    avcodec_open2(dec_ctx, dec_codec, nullptr);

    // HEVC 编码器配置
    const AVCodec* enc_codec = avcodec_find_encoder_by_name("libx265");
    AVCodecContext* enc_ctx = avcodec_alloc_context3(enc_codec);
    enc_ctx->width = dec_ctx->width;
    enc_ctx->height = dec_ctx->height;
    enc_ctx->time_base = {1, 30};
    enc_ctx->pix_fmt = AV_PIX_FMT_YUV420P;
    enc_ctx->max_b_frames = 0;
    enc_ctx->gop_size = 30;
    
    av_opt_set(enc_ctx->priv_data, "preset", "ultrafast", 0);
    av_opt_set(enc_ctx->priv_data, "tune", "zerolatency", 0);
    av_opt_set(enc_ctx->priv_data, "x265-params", "annexb=1:keyint=30:bframes=0", 0);
    avcodec_open2(enc_ctx, enc_codec, nullptr);

    AVPacket *pkt = av_packet_alloc();
    AVFrame *frame = av_frame_alloc();
    AVPacket *enc_pkt = av_packet_alloc();
    uint16_t frame_id = 0;
    auto frame_duration = std::chrono::milliseconds(33);

    std::cout << "开始循环推流..." << std::endl;

    while (true) {
        if (av_read_frame(fmt_ctx, pkt) < 0) {
            // 实现循环播放：回到文件开头
            av_seek_frame(fmt_ctx, video_idx, 0, AVSEEK_FLAG_BACKWARD);
            avcodec_flush_buffers(dec_ctx);
            std::cout << "视频重放..." << std::endl;
            continue;
        }

        if (pkt->stream_index == video_idx) {
            auto start_time = std::chrono::steady_clock::now();

            if (avcodec_send_packet(dec_ctx, pkt) == 0) {
                while (avcodec_receive_frame(dec_ctx, frame) == 0) {
                    if (avcodec_send_frame(enc_ctx, frame) == 0) {
                        while (avcodec_receive_packet(enc_ctx, enc_pkt) == 0) {
                            
                            uint8_t* data = enc_pkt->data;
                            int size = enc_pkt->size;
                            int slice_idx = 0;

                            while (size > 0) {
                                int send_len = (size > PAYLOAD_SIZE) ? PAYLOAD_SIZE : size;
                                uint8_t buffer[1400]; // 总大小固定1400
                                
                                // 填充 8 字节固定头
                                uint16_t n_fid = htons(frame_id);
                                uint16_t n_sid = htons(slice_idx);
                                uint32_t n_tsize = htonl(enc_pkt->size);
                                
                                memcpy(buffer, &n_fid, 2);
                                memcpy(buffer + 2, &n_sid, 2);
                                memcpy(buffer + 4, &n_tsize, 4);
                                memcpy(buffer + 8, data, send_len);

                                sendto(sockfd, buffer, send_len + 8, 0, (struct sockaddr*)&addr, sizeof(addr));
                                
                                data += send_len;
                                size -= send_len;
                                slice_idx++;
                            }
                            frame_id++;
                            av_packet_unref(enc_pkt);
                        }
                    }
                }
            }
            // 控制帧率
            auto elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now() - start_time);
            if (elapsed < frame_duration) std::this_thread::sleep_for(frame_duration - elapsed);
        }
        av_packet_unref(pkt);
    }

    // 清理资源（实际由于无限循环可能运行不到此处）
    av_frame_free(&frame);
    av_packet_free(&pkt);
    av_packet_free(&enc_pkt);
    avcodec_free_context(&dec_ctx);
    avcodec_free_context(&enc_ctx);
    avformat_close_input(&fmt_ctx);
    return 0;
}