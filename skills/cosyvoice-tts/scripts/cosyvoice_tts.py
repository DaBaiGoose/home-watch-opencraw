"""
CosyVoice2-0.5B TTS 脚本 - 供 OpenClaw 调用
接入 https://www.modelscope.cn/studios/iic/CosyVoice2-0.5B/summary

用法:
    python cosyvoice_tts.py "要说的话"
    python cosyvoice_tts.py "要说的话" --play
    python cosyvoice_tts.py "要说的话" --output output.wav
"""

import requests
import json
import time
import os
import sys
import argparse
import subprocess

# Windows console encoding fix
if os.name == "nt":
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8")

base_url = "https://iic-cosyvoice2-0-5b.ms.show/"

# 参考音频配置（云落语音）
input_path = [
    "/tmp/gradio/299aa607941d2adcf54471ccc4a5781903cf471c/majiong_yunluo_clip.mp3",
    "快点吧，我等的花儿都谢了，快点吧，我打完还得去刷副本呢，大牌大牌，我要做个大牌。"
]

# 可用的语音风格
STYLE_OPTIONS = [
    "开心地说", "悲伤地说", "愤怒地说", "平静地说", "兴奋地说",
    "温柔地说", "惊讶地说", "恐惧地说", "厌恶地说", "自豪地说",
    "崇拜地说", "无奈地说", "鼓励地说", "害羞地说", "撒娇地说",
    "自信地说", "恐慌地说", "得意地说", "平静地说", "友好的说",
    "哭着说", "笑着说", "叹气地说"
]


def upload_audio(local_file_path):
    """上传音频文件并返回服务器路径"""
    url = base_url.rstrip("/") + "/upload"
    with open(local_file_path, "rb") as f:
        files = {"files": (os.path.basename(local_file_path), f, "audio/mpeg")}
        response = requests.post(url, files=files)
    if response.status_code == 200:
        result = response.json()
        return result[0]
    else:
        raise Exception(f"上传失败: {response.text}")


def synthesize(text, style="开心地说", output_path=None, play=False):
    """合成语音
    
    Args:
        text: 要合成的文字
        style: 语音风格（如 "开心地说", "温柔地说" 等）
        output_path: 输出文件路径，默认 quick_test_audio.wav
        play: 是否播放音频
    
    Returns:
        (wav_times, wav_files): 每段时长和文件路径列表
    """
    if output_path is None:
        output_path = os.path.join(os.path.dirname(__file__), "quick_test_audio.wav")
    
    session = requests.Session()
    session.headers.update({
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "Content-Type": "application/json",
        "Referer": base_url,
    })

    session_hash = f"cv2_{int(time.time()*1000)}_{os.urandom(4).hex()}"

    payload = {
        "data": [
            text,
            "3s极速复刻",
            input_path[1],
            {
                "path": input_path[0],
                "url": base_url + "file=" + input_path[0],
                "orig_name": os.path.basename(input_path[0]),
                "size": 1673264,
                "mime_type": "audio/wav",
                "meta": {"_type": "gradio.FileData"},
            },
            None,
            style,
            0,
            False,
        ],
        "event_data": None,
        "fn_index": 1,
        "trigger_id": 18,
        "dataType": ["textbox", "radio", "textbox", "audio", "audio", "textbox", "number", "radio"],
        "session_hash": session_hash,
    }

    # 提交任务
    resp = session.post(
        base_url + "queue/join",
        json=payload,
        params={"t": int(time.time() * 1000), "__theme": "light", "backend_url": "/"},
    )
    if resp.status_code != 200:
        raise Exception(f"提交失败: {resp.text}")

    # 监听进度
    with session.get(
        base_url + "queue/data",
        params={"session_hash": session_hash, "studio_token": ""},
        stream=True,
    ) as r:
        for line in r.iter_lines():
            if line and line.startswith(b"data: "):
                try:
                    data = json.loads(line[6:])
                    if data.get("msg") == "process_completed":
                        audio_url = data["output"]["data"][0]["url"].strip().replace(" ", "")
                        audio_response = session.get(audio_url)
                        with open(output_path, "wb") as f:
                            f.write(audio_response.content)
                        break
                except:
                    pass

    if not os.path.exists(output_path):
        raise Exception("音频文件生成失败")

    # 分段（如果 >15s 则截断为 14s 一段）
    import librosa
    import soundfile as sf

    audio, sr = librosa.load(output_path)
    duration = librosa.get_duration(y=audio, sr=sr)

    wav_files = []
    wav_times = []

    if duration > 15:
        segment_samples = int(14 * sr)
        segments = [audio[i:i + segment_samples] for i in range(0, len(audio), segment_samples)]
        for idx, segment in enumerate(segments):
            seg_path = os.path.join(os.path.dirname(output_path), f"segment_{idx}.wav")
            sf.write(seg_path, segment, sr)
            wav_files.append(seg_path)
            wav_times.append(len(segment) / sr)
    else:
        wav_files.append(output_path)
        wav_times.append(duration)

    # 播放
    if play:
        for wf in wav_files:
            play_audio_system(wf)

    return wav_times, wav_files


def play_audio_system(filepath):
    """用系统默认播放器播放音频"""
    try:
        if os.name == "nt":  # Windows
            # 用 powershell 播放
            abs_path = os.path.abspath(filepath)
            subprocess.run(
                ["powershell", "-Command",
                 f"(New-Object Media.SoundPlayer '{abs_path}').PlaySync()"],
                timeout=60,
            )
    except Exception as e:
        print(f"播放失败: {e}", file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(description="CosyVoice2 TTS")
    parser.add_argument("text", help="要合成的文字")
    parser.add_argument("--style", default="开心地说", help=f"语音风格，可选: {', '.join(STYLE_OPTIONS[:10])}...")
    parser.add_argument("--output", "-o", default=None, help="输出文件路径")
    parser.add_argument("--play", "-p", action="store_true", help="合成后播放")
    args = parser.parse_args()

    try:
        times, files = synthesize(args.text, style=args.style, output_path=args.output, play=args.play)
        for t, f in zip(times, files):
            print(f"[OK] 合成完成: {f} ({t:.1f}s)")
    except Exception as e:
        print(f"[FAIL] 合成失败: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
