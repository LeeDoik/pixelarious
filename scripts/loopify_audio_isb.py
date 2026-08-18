"""손으로 만든 WAV를 IT SLEEPS BELOW용 루프 ogg로 변환.

VARCO 웹 UI에서 받은 앰비언트는 앞뒤가 무음으로 페이드되어 있어 그대로 루프하면
매 바퀴 소리가 끊긴다. 여기서 세 가지를 한다:

1. **트림** — 앞뒤 무음/감쇠 구간을 잘라 지속 구간만 남긴다
2. **크로스페이드 루프** — 꼬리 X초를 머리 X초 위에 겹쳐 접합점을 없앤다
   (원본에서 이어져 있던 구간끼리 겹치므로 이음매가 들리지 않는다)
3. **정규화** — 기존 앰비언트(amb_rock -19.9 dBFS RMS)에 레벨을 맞춘다

실행: python scripts/loopify_audio_isb.py <이름> [--src PATH] [--start S] [--end S]
      [--xfade S] [--target-rms DB] [--dry-run]

이름은 assets/sfx/<이름>.ogg 로 저장된다. --dry-run은 분석만 하고 쓰지 않는다.
"""
import argparse, math, os, struct, subprocess, sys, tempfile, wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "games-src", "it-sleeps-below", "assets", "sfx")
TARGET_RMS_DB = -20.0  # 기존 앰비언트 기준 (amb_rock -19.9, heartbeat -20.8)


def ffmpeg(args):
    subprocess.run(["ffmpeg", "-v", "error", "-y", *args], check=True)


def read_mono(path):
    with wave.open(path, "rb") as w:
        n, sr, ch = w.getnframes(), w.getframerate(), w.getnchannels()
        s = struct.unpack("<%dh" % (n * ch), w.readframes(n))
    if ch == 2:
        s = [(s[i] + s[i + 1]) // 2 for i in range(0, len(s), 2)]
    return s, sr


def rms_db(samples):
    if not samples:
        return -120.0
    r = math.sqrt(sum(v * v for v in samples) / len(samples))
    return 20 * math.log10(max(r, 1e-9) / 32768)


def envelope(samples, sr, block=0.25):
    blk = int(sr * block)
    return [rms_db(samples[i:i + blk]) for i in range(0, len(samples) - blk + 1, blk)]


def auto_bounds(samples, sr, floor_below_peak=18.0, block=0.25):
    """블록 RMS가 최대치보다 floor_below_peak dB 이상 낮은 앞뒤 구간을 버린다."""
    env = envelope(samples, sr, block)
    if not env:
        return 0.0, len(samples) / sr
    thresh = max(env) - floor_below_peak
    keep = [i for i, v in enumerate(env) if v >= thresh]
    if not keep:
        return 0.0, len(samples) / sr
    return keep[0] * block, (keep[-1] + 1) * block


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("name")
    ap.add_argument("--src", help="원본 wav 경로 (기본: ~/Downloads/<이름>.wav)")
    ap.add_argument("--start", type=float, help="트림 시작(초). 생략하면 자동")
    ap.add_argument("--end", type=float, help="트림 끝(초). 생략하면 자동")
    ap.add_argument("--xfade", type=float, default=1.5, help="크로스페이드 길이(초)")
    ap.add_argument("--target-rms", type=float, default=TARGET_RMS_DB)
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()

    src = a.src or os.path.join(os.path.expanduser("~"), "Downloads", a.name + ".wav")
    if not os.path.exists(src):
        sys.exit("원본을 찾을 수 없다: " + src)

    with tempfile.TemporaryDirectory() as tmp:
        # 원본이 ogg/mp3여도 받아들이도록 일단 wav로 디코드
        raw = os.path.join(tmp, "in.wav")
        ffmpeg(["-i", src, "-ac", "1", "-c:a", "pcm_s16le", raw])
        samples, sr = read_mono(raw)
        dur = len(samples) / sr
        start = a.start if a.start is not None else 0.0
        end = a.end if a.end is not None else dur
        if a.start is None or a.end is None:
            auto_s, auto_e = auto_bounds(samples, sr)
            start = auto_s if a.start is None else start
            end = auto_e if a.end is None else end
        span = end - start
        xf = min(a.xfade, span / 2 - 0.1)
        if xf <= 0:
            sys.exit("구간이 크로스페이드보다 짧다")

        print(f"{a.name}: 원본 {dur:.2f}s / RMS {rms_db(samples):.1f} dB")
        print(f"  트림 {start:.2f}~{end:.2f}s ({span:.2f}s), 크로스페이드 {xf:.2f}s"
              f" → 루프 {span - xf:.2f}s")

        # 꼬리를 머리 위로 겹친다: [A=start+xf..end] 뒤에 [B=start..start+xf]를 크로스페이드
        cut = os.path.join(tmp, "cut.wav")
        ffmpeg(["-ss", str(start), "-t", str(span), "-i", raw, "-c:a", "pcm_s16le", cut])
        loop = os.path.join(tmp, "loop.wav")
        ffmpeg(["-ss", str(xf), "-i", cut, "-t", str(xf), "-i", cut,
                "-filter_complex", f"[0][1]acrossfade=d={xf}:c1=tri:c2=tri",
                "-c:a", "pcm_s16le", loop])

        looped, _ = read_mono(loop)
        gain = a.target_rms - rms_db(looped)
        seam = abs(looped[-1] - looped[0]) if looped else 0
        peak_after = max(abs(v) for v in looped) * (10 ** (gain / 20))
        print(f"  루프 RMS {rms_db(looped):.1f} dB → 게인 {gain:+.1f} dB"
              f" (피크 {20 * math.log10(max(peak_after, 1) / 32768):.1f} dBFS), 이음매 점프 {seam}")
        if peak_after > 32767:
            print("  경고: 게인 후 클리핑 — target-rms를 낮추거나 원본을 확인할 것")

        if a.dry_run:
            return
        os.makedirs(OUT, exist_ok=True)
        dst = os.path.join(OUT, a.name + ".ogg")
        ffmpeg(["-i", loop, "-af", f"volume={gain:.2f}dB",
                "-c:a", "libvorbis", "-qscale:a", "4", dst])
        print(f"  OK -> {dst}")


if __name__ == "__main__":
    main()
