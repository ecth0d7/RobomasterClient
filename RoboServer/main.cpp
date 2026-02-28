#include <iostream>
#include <string>
#include <cstring>
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/opt.h>
#include <libavutil/imgutils.h>
#include <libswscale/swscale.h>
}

// 配置项
const char* VIDEO_FILE = "../test.mp4";
const char* TARGET_IP = "127.0.0.1"; // 客户端IP
const int TARGET_PORT = 8888;
const int MAX_UDP_SIZE = 65507;

int main() {
    // 1. 初始化 UDP Socket
    int sockfd = socket(AF_INET, SOCK_DGRAM, 0);
    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(TARGET_PORT);
    inet_pton(AF_INET, TARGET_IP, &addr.sin_addr);

    // 2. 初始化 FFmpeg 读取视频
    AVFormatContext* fmt_ctx = nullptr;
    if (avformat_open_input(&fmt_ctx, VIDEO_FILE, nullptr, nullptr) != 0) {
        std::cerr << "无法打开视频文件" << std::endl;
        return -1;
    }
    avformat_find_stream_info(fmt_ctx, nullptr);

    // 找到视频流
    int video_idx = -1;
    for (unsigned int i = 0; i < fmt_ctx->nb_streams; i++) {
        if (fmt_ctx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_VIDEO) {
            video_idx = i;
            break;
        }
    }

    // 初始化解码器 (用于读取原视频)
    AVCodecParameters* dec_par = fmt_ctx->streams[video_idx]->codecpar;
    const AVCodec* dec_codec = avcodec_find_decoder(dec_par->codec_id);
    AVCodecContext* dec_ctx = avcodec_alloc_context3(dec_codec);
    avcodec_parameters_to_context(dec_ctx, dec_par);
    avcodec_open2(dec_ctx, dec_codec, nullptr);

    // 3. 初始化 HEVC 编码器 (x265)
    const AVCodec* enc_codec = avcodec_find_encoder_by_name("libx265");
    AVCodecContext* enc_ctx = avcodec_alloc_context3(enc_codec);
    
    enc_ctx->width = dec_ctx->width;
    enc_ctx->height = dec_ctx->height;
    enc_ctx->time_base = AVRational{1, 30};
    enc_ctx->framerate = AVRational{30, 1};
    enc_ctx->pix_fmt = AV_PIX_FMT_YUV420P;
    
    // 超低延迟设置
    av_opt_set(enc_ctx->priv_data, "preset", "ultrafast", 0);
    av_opt_set(enc_ctx->priv_data, "tune", "zerolatency", 0);
    av_opt_set_int(enc_ctx->priv_data, "keyint", 10, 0);
    
    avcodec_open2(enc_ctx, enc_codec, nullptr);

    AVPacket* pkt = av_packet_alloc();
    AVFrame* frame = av_frame_alloc();

    std::cout << "开始发送视频流..." << std::endl;

    // 4. 循环处理
    while (true) {
        // 读取一帧源视频
        if (av_read_frame(fmt_ctx, pkt) >= 0) {
            if (pkt->stream_index == video_idx) {
                avcodec_send_packet(dec_ctx, pkt);
                while (avcodec_receive_frame(dec_ctx, frame) == 0) {
                    // 编码为 HEVC
                    avcodec_send_frame(enc_ctx, frame);
                    AVPacket* enc_pkt = av_packet_alloc();
                    while (avcodec_receive_packet(enc_ctx, enc_pkt) == 0) {
                        // 发送：简单协议 -> [4字节大小][数据]
                        uint32_t size = htonl(enc_pkt->size);
                        sendto(sockfd, &size, 4, 0, (struct sockaddr*)&addr, sizeof(addr));
                        sendto(sockfd, enc_pkt->data, enc_pkt->size, 0, (struct sockaddr*)&addr, sizeof(addr));
                    }
                    av_packet_free(&enc_pkt);
                    av_frame_unref(frame);
                    // 控制帧率，防止发送过快
                    usleep(33000); 
                }
            }
            av_packet_unref(pkt);
        } else {
            // 视频播放完了，循环重播
            av_seek_frame(fmt_ctx, video_idx, 0, AVSEEK_FLAG_BACKWARD);
        }
    }

    // 清理 (实际运行中不会到这里)
    av_packet_free(&pkt);
    av_frame_free(&frame);
    avcodec_free_context(&dec_ctx);
    avcodec_free_context(&enc_ctx);
    avformat_close_input(&fmt_ctx);
    close(sockfd);
    return 0;
}
