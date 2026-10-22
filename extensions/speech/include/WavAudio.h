#pragma once
#include <QVariantMap>
#include <QByteArray>
class QIODevice;
namespace WavAudio {
// 交给播放器前，按长度上限完整检查 RIFF PCM 文件。
bool inspect(QIODevice &input, QVariantMap *details);
// 对已验证PCM的一段完整样本作衰减，100%不复制／改写；不依赖播放器的私有参数。
bool attenuate(QByteArray *samples, int bits, int percent);
QByteArray alertTone(bool urgent);
} // WavAudio 命名空间
