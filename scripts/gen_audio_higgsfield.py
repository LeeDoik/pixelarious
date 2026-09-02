# -*- coding: utf-8 -*-
"""Higgsfield로 생성한 LAST LOGIN 소리를 게임 규격으로 가공한다.
원본은 scripts/audio_src/higgsfield/ (Sonilo Music·Seed Audio 1.0 산출물, 2026-09-02).
gen_audio.py는 다시 돌리지 않는다 — 이 스크립트는 여기 적힌 파일만 만든다.

  ending_theme.ogg      엔딩곡 (설계서 §"음악은 엔딩 1곡") — 후보 ending_a/b/c 중 하나
  msg.wav               메신저 알림음 — 후보 msg_tense_1/2/3 중 하나 (액트와 무관하게 하나로 통일, 옛 신디사이즈판은 audio_src/msg_synth_2002.wav)
  shutdown.wav          엔딩의 "시스템을 종료하는 중" 화면에 — 후보 shutdown_1/2 중 하나
  amb_window_night.wav  창밖(1~3단) — 6번째 앰비언트 층, 6초 루프
  amb_window_dawn.wav   창밖(4·5단) — 새벽

실행: python scripts/gen_audio_higgsfield.py [--ending a|b|c] [--msg 1|2|3] [--shutdown 1|2]
후보를 바꾸려면 옵션만 바꿔 다시 돌린다. ffmpeg 필요.
"""
import argparse, math, os, struct, subprocess, wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "scripts", "audio_src", "higgsfield")
OUT = os.path.join(ROOT, "games-src", "last-login", "assets", "sfx")
SR = 22050  # 기존 효과음·앰비언트와 같은 규격 (모노 16비트)


def ffmpeg(*args):
    subprocess.run(["ffmpeg", "-v", "error", "-y", *args], check=True)


def read_mono(path):
    with wave.open(path, "rb") as w:
        n, sr, ch = w.getnframes(), w.getframerate(), w.getnchannels()
        s = struct.unpack("<%dh" % (n * ch), w.readframes(n))
    if ch > 1:
        s = [sum(s[i:i + ch]) / ch for i in range(0, len(s), ch)]
    return [v / 32768.0 for v in s], sr


def write_mono(path, s, sr=SR):
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, v)) * 32767)) for v in s))


def db(x):
    return 20 * math.log10(max(x, 1e-9))


def rms(s):
    return math.sqrt(sum(v * v for v in s) / len(s))


def to_mono_wav(src, dst, sr=SR):
    ffmpeg("-i", src, "-ac", "1", "-ar", str(sr), "-sample_fmt", "s16", dst)


def one_shot(name, src, peak_db=-6.0, tail=0.12, fade=0.06):
    """원샷 효과음: 앞뒤 무음을 잘라내고 꼬리를 짧게 페이드, 피크 정규화."""
    tmp = os.path.join(SRC, "_tmp.wav")
    to_mono_wav(src, tmp)
    s, sr = read_mono(tmp)
    os.remove(tmp)
    th = 0.004
    first = next((i for i, v in enumerate(s) if abs(v) > th), 0)
    last = next((i for i in range(len(s) - 1, -1, -1) if abs(s[i]) > th), len(s) - 1)
    first = max(0, first - int(0.01 * sr))
    last = min(len(s), last + int(tail * sr))
    s = s[first:last]
    n = int(fade * sr)
    for i in range(n):  # 머리·꼬리 페이드로 클릭 제거
        g = i / n
        s[i] *= g
        s[-1 - i] *= g
    gain = 10 ** (peak_db / 20) / max(abs(v) for v in s)
    s = [v * gain for v in s]
    write_mono(os.path.join(OUT, name), s, sr)
    print("%-22s %.2fs rms %.1f dB peak %.1f dB" % (name, len(s) / sr, db(rms(s)), peak_db))


def loop_layer(name, src, seconds=6.0, xfade=1.5, target_rms_db=-30.0, skip=0.4):
    """앰비언트 층: 가운데 6초를 잘라 꼬리를 머리에 겹치는 크로스페이드 루프 — 다른 amb_*처럼 LOOP_FORWARD."""
    tmp = os.path.join(SRC, "_tmp.wav")
    to_mono_wav(src, tmp)
    s, sr = read_mono(tmp)
    os.remove(tmp)
    L, X, off = int(seconds * sr), int(xfade * sr), int(skip * sr)
    body = s[off:off + L + X]
    out = body[:L]
    for i in range(X):  # 꼬리 X초를 머리 X초 위에 등전력 크로스페이드
        t = i / X
        out[i] = out[i] * math.sin(t * math.pi / 2) + body[L + i] * math.cos(t * math.pi / 2)
    gain = 10 ** (target_rms_db / 20) / rms(out)
    out = [v * gain for v in out]
    pk = max(abs(v) for v in out)
    if pk > 0.9:
        out = [v * 0.9 / pk for v in out]
    write_mono(os.path.join(OUT, name), out, sr)
    seam = abs(out[-1] - out[0])
    print("%-22s %.1fs rms %.1f dB peak %.1f dB seam %.4f" % (name, len(out) / sr, db(rms(out)), db(pk), seam))


def music(name, src, peak_db=-1.0):
    """엔딩곡: 스테레오 44.1k, 피크 정규화, ogg vorbis q6."""
    tmp = os.path.join(SRC, "_tmp.wav")
    ffmpeg("-i", src, "-ac", "2", "-ar", "44100", tmp)
    s, _ = read_mono(tmp)
    pk = max(abs(v) for v in s)
    gain = db(10 ** (peak_db / 20) / pk)
    ffmpeg("-i", tmp, "-af", "volume=%.2fdB" % gain, "-c:a", "libvorbis", "-q:a", "6", os.path.join(OUT, name))
    os.remove(tmp)
    print("%-22s gain %+.1f dB -> peak %.0f dB" % (name, gain, peak_db))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--ending", default="a", choices="abc")
    ap.add_argument("--msg", default="1", choices="123")
    ap.add_argument("--shutdown", default="1", choices="12")
    a = ap.parse_args()
    os.makedirs(OUT, exist_ok=True)
    music("ending_theme.ogg", os.path.join(SRC, "ending_%s.m4a" % a.ending))
    one_shot("msg.wav", os.path.join(SRC, "msg_tense_%s.wav" % a.msg))
    one_shot("shutdown.wav", os.path.join(SRC, "shutdown_%s.wav" % a.shutdown), tail=0.3, fade=0.15)
    loop_layer("amb_window_night.wav", os.path.join(SRC, "amb_window_night.wav"))
    loop_layer("amb_window_dawn.wav", os.path.join(SRC, "amb_window_dawn.wav"))
    print("ok")
