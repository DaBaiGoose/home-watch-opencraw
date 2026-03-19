---
name: cosyvoice-tts
description: 中文语音合成技能，使用 CosyVoice2-0.5B 模型将文字转为自然语音。当用户让你说话、朗读、配音、用语音回复，或提到"语音"、"TTS"、"朗读"时使用。支持多种情感风格（开心、温柔、悲伤等）。
---

# CosyVoice2 语音合成 🎙️

将文字转为自然中文语音，使用 ModelScope 上的 CosyVoice2-0.5B 模型。

## 快速调用

```bash
python <skill_dir>/scripts/cosyvoice_tts.py "要说的话" --play
```

- `--play` 合成后自动播放
- `--style "温柔地说"` 指定语音风格（默认"开心地说"）
- `--output out.wav` 指定输出路径

## 调用方式

直接执行脚本即可：

```bash
python D:\openclaw\workspacce\skills\cosyvoice-tts\scripts\cosyvoice_tts.py "你好世界" --play
```

输出文件默认保存到 `scripts/quick_test_audio.wav`。

## 可选风格

开心地说、温柔地说、平静地说、兴奋地说、悲伤地说、愤怒地说、笑着说、哭着地说、自信地说、害羞地说、撒娇地说、鼓励地说、叹气地说等。

## 注意事项

- 需联网（调用魔搭社区免费 API）
- 合成耗时约 5-15 秒
- 参考音频为云落 voice clone 素材
- 音频 >15 秒会自动分段
- Windows 环境，已安装 requests、librosa、soundfile
