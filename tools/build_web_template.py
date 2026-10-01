"""Build a pinned, minimal Godot Web release template in a reusable cache."""

import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
import tarfile
import urllib.request
import zipfile
from pathlib import Path

GODOT_COMMIT = "ed1daf0bf001b61586d9930840f2f1394092c079"
GODOT_VERSION = "4.7.2"
SDK_VERSION = "4.0.11"
SCONS_VERSION = "4.9.1"
ARCHIVES = {
    "godot": (
        f"https://codeload.github.com/godotengine/godot/tar.gz/{GODOT_COMMIT}",
        "e607e9985e1c201bc9cdc1aec8a120f0c3f53b9603f1f828e2b748534a2471ef",
    ),
    "emsdk": (
        f"https://codeload.github.com/emscripten-core/emsdk/tar.gz/refs/tags/{SDK_VERSION}",
        "058f97f3d408e6438c0128de63fc83b085a1a1c8f8e2ef992edee01281af9546",
    ),
}
PROJECT = Path(__file__).resolve().parents[1]
PROFILE = PROJECT / "tools/web_template.py"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(command: list[str], **kwargs) -> None:
    subprocess.run(command, check=True, **kwargs)


def unpack(cache: Path, name: str) -> Path:
    url, checksum = ARCHIVES[name]
    archive = cache / ("godot-source.tar.gz" if name == "godot" else "emsdk.tar.gz")
    destination = cache / name
    if not archive.exists():
        temporary = archive.with_suffix(".download")
        urllib.request.urlretrieve(url, temporary)
        if digest(temporary) != checksum:
            raise RuntimeError(f"Unexpected checksum for {name}")
        temporary.replace(archive)
    if digest(archive) != checksum:
        raise RuntimeError(f"Unexpected cached checksum for {name}")
    if not destination.exists():
        with tarfile.open(archive) as source:
            root = source.getmembers()[0].name.split("/")[0]
            source.extractall(cache, filter="data")
        (cache / root).rename(destination)
    return destination


def build(cache: Path, jobs: int) -> Path:
    cache.mkdir(parents=True, exist_ok=True)
    identity = {
        "godot_commit": GODOT_COMMIT,
        "godot_version": GODOT_VERSION,
        "emscripten_version": SDK_VERSION,
        "scons_version": SCONS_VERSION,
        "profile_sha256": digest(PROFILE),
    }
    template = cache / "mosquito-web-release.zip"
    manifest_path = cache / "template.json"
    if template.exists() and manifest_path.exists():
        manifest = json.loads(manifest_path.read_text())
        if all(manifest.get(key) == value for key, value in identity.items()):
            if digest(template) == manifest.get("template_sha256"):
                return template

    godot = unpack(cache, "godot")
    sdk = unpack(cache, "emsdk")
    python = cache / "venv/bin/python"
    if not python.exists():
        run([sys.executable, "-m", "venv", str(cache / "venv")])
    installed = subprocess.run([str(python), "-m", "SCons", "--version"],
                               capture_output=True, text=True)
    if installed.returncode or f"v{SCONS_VERSION}" not in installed.stdout:
        run([str(python), "-m", "pip", "install", f"SCons=={SCONS_VERSION}"])
    run([str(sdk / "emsdk"), "install", SDK_VERSION], cwd=sdk)
    run([str(sdk / "emsdk"), "activate", SDK_VERSION], cwd=sdk)
    # The SDK supplies Node and LLVM. Keep its environment scoped to this build.
    run(["bash", "-c", 'source "$1/emsdk_env.sh" >/dev/null && shift && exec "$@"',
         "godot-web-build", str(sdk), str(python), "-m", "SCons",
         f"profile={PROFILE}", "platform=web", "target=template_release",
         "arch=wasm32", "threads=no", "dlink_enabled=no", "optimize=size",
         f"-j{jobs}"], cwd=godot)
    source = godot / "bin/godot.web.template_release.wasm32.nothreads.zip"
    with zipfile.ZipFile(source) as bundle:
        wasm = bundle.read("godot.wasm")
    # Refuse a misconfigured build that is larger than the official template.
    if not wasm.startswith(b"\0asm") or len(wasm) >= 39_514_754:
        raise RuntimeError("The custom Web engine failed the size/format check")
    shutil.copyfile(source, template)
    manifest_path.write_text(json.dumps({**identity,
        "template_sha256": digest(template),
        "wasm_bytes": len(wasm),
    }, indent=2) + "\n")
    return template


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cache-dir", type=Path,
                        default=Path.home() / ".cache/mosquito-night-web-build")
    parser.add_argument("--jobs", type=int, default=min(4, os.cpu_count() or 2))
    args = parser.parse_args()
    if args.jobs < 1:
        parser.error("--jobs must be positive")
    print(build(args.cache_dir.resolve(), args.jobs), flush=True)


if __name__ == "__main__":
    main()
