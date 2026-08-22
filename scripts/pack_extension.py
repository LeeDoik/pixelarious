"""크롬 웹 스토어 업로드용 zip 패키징. 사용: python scripts/pack_extension.py

extension/starfall-drift/ → extension/dist/starfall-drift-v<version>.zip
버전은 manifest.json에서 읽는다. dist/는 gitignore.
"""
import json
import os
import zipfile

SRC = os.path.join("extension", "starfall-drift")
DIST = os.path.join("extension", "dist")

# 스토어 zip에 들어가면 안 되는 것들
SKIP_NAMES = {".DS_Store", "Thumbs.db", "desktop.ini"}
SKIP_SUFFIXES = (".zip", ".md", ".psd", ".xcf")


def files() -> list[str]:
    out = []
    for root, dirs, names in os.walk(SRC):
        dirs[:] = sorted(d for d in dirs if not d.startswith("."))
        for name in sorted(names):
            if name in SKIP_NAMES or name.startswith("."):
                continue
            if name.endswith(SKIP_SUFFIXES):
                continue
            out.append(os.path.join(root, name))
    return out


def main() -> None:
    with open(os.path.join(SRC, "manifest.json"), encoding="utf-8") as f:
        version = json.load(f)["version"]

    os.makedirs(DIST, exist_ok=True)
    out = os.path.join(DIST, f"starfall-drift-v{version}.zip")

    paths = files()
    assert any(p.endswith("manifest.json") for p in paths), "manifest.json이 빠졌다"

    # zip 루트에 manifest.json이 오도록 SRC 기준 상대경로로 담는다.
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for path in paths:
            z.write(path, os.path.relpath(path, SRC).replace(os.sep, "/"))

    size = os.path.getsize(out)
    print(f"wrote {out} ({size / 1024:.1f} KB, {len(paths)} files)")
    for path in paths:
        print("  ", os.path.relpath(path, SRC).replace(os.sep, "/"))


if __name__ == "__main__":
    main()
