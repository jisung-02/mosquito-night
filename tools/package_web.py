"""Package a verified static Web export without adding binaries to Git history."""

import argparse
import hashlib
import json
import zipfile
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root = args.input.resolve()
    manifest = json.loads((root / "build.json").read_text())
    for filename, key in [("index.pck", "pack_sha256"), ("index.wasm", "wasm_sha256")]:
        actual = hashlib.sha256((root / filename).read_bytes()).hexdigest()
        if actual != manifest[key]:
            raise RuntimeError(f"Export checksum mismatch: {filename}")
    required = ["index.html", "index.js", "index.audio.worklet.js",
                "index.audio.position.worklet.js", "size-report.json",
                "licenses/Godot-LICENSE.txt", "licenses/Godot-COPYRIGHT.txt",
                "licenses/NotoSansKR-OFL.txt", "licenses/audio-credits.md"]
    for filename in required:
        if not (root / filename).is_file():
            raise RuntimeError(f"Incomplete export: {filename}")
    output = args.output.resolve()
    if output.is_relative_to(root):
        parser.error("Keep the ZIP outside the export directory")
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as bundle:
        for path in sorted(root.rglob("*")):
            if path.is_file() and path.name != ".gdignore":
                bundle.write(path, path.relative_to(root).as_posix())
        bundle.writestr("README.txt", (
            "잠들 수 없는 밤 — 웹 빌드\n\n"
            "압축을 풀고 폴더 전체를 HTTPS 정적 웹 서버에 올려 주세요.\n"
            "로컬에서 확인하려면 이 폴더에서 python3 -m http.server 8766을 실행하고\n"
            "브라우저로 http://localhost:8766을 여세요. index.html 파일을 직접 여는 방식은 지원하지 않습니다.\n\n"
            "게임: https://jisung-02.github.io/mosquito-night/\n"
            "소스: https://github.com/jisung-02/mosquito-night\n"
            f"소스 커밋: {manifest['source_commit']}\n"
            "build.json의 SHA256과 size-report.json에서 이 빌드의 파일을 확인할 수 있습니다.\n"
            "엔진·글꼴·음원 라이선스는 licenses 폴더에 있습니다.\n"
        ))
    with zipfile.ZipFile(output) as bundle:
        if bundle.testzip() is not None:
            raise RuntimeError("The Web ZIP integrity check failed")
    print(f"Packaged {manifest['source_commit'][:12]}: {output.stat().st_size:,} bytes → {output}")


if __name__ == "__main__":
    main()
