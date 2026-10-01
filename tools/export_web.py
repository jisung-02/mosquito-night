"""Export the committed game and its notices for any static web host."""
import argparse
import gzip
import hashlib
import json
import shutil
import subprocess
from pathlib import Path

from build_web_template import build, GODOT_VERSION

project = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--godot", default="godot")
parser.add_argument("--output", type=Path, required=True)
parser.add_argument("--template-cache", type=Path,
                    default=Path.home() / ".cache/mosquito-night-web-build")
parser.add_argument("--jobs", type=int, default=4)
args = parser.parse_args()
output = args.output.resolve()
output.mkdir(parents=True, exist_ok=True)
if output.is_relative_to(project):
    (output / ".gdignore").touch()

version = subprocess.check_output([args.godot, "--version"], text=True).strip()
if not version.startswith(GODOT_VERSION + ".stable."):
    parser.error(f"The pinned Web template requires Godot {GODOT_VERSION}, got {version}")
if args.jobs < 1:
    parser.error("--jobs must be positive")
template_cache = args.template_cache.resolve()
template = build(template_cache, args.jobs)
template_dir = project / "tools/.web-template"
template_dir.mkdir(exist_ok=True)
shutil.copyfile(template, template_dir / "web_release.zip")
template_manifest = json.loads((template_cache / "template.json").read_text())

# Import first so a fresh submodule checkout has its texture/audio caches.
subprocess.run([args.godot, "--headless", "--path", str(project),
                "--editor", "--import"], check=True)
subprocess.run([args.godot, "--headless", "--path", str(project),
                "--export-release", "Web", str(output / "index.html")], check=True)
notices = output / "licenses"
notices.mkdir(exist_ok=True)
for name in ("Godot-LICENSE.txt", "Godot-COPYRIGHT.txt"):
    shutil.copyfile(project / "licenses" / name, notices / name)
shutil.copyfile(project / "assets/fonts/OFL.txt", notices / "NotoSansKR-OFL.txt")
shutil.copyfile(project / "assets/audio/CREDITS.md", notices / "audio-credits.md")
source_commit = subprocess.check_output(
    ["git", "-C", str(project), "rev-parse", "HEAD"], text=True).strip()
pack_hash = hashlib.sha256((output / "index.pck").read_bytes()).hexdigest()
(output / "build.json").write_text(json.dumps({
    "source_commit": source_commit,
    "godot_version": version,
    "pack_sha256": pack_hash,
    "wasm_sha256": hashlib.sha256((output / "index.wasm").read_bytes()).hexdigest(),
    "web_template": template_manifest,
}, indent=2) + "\n")
files = []
for path in sorted(output.iterdir()):
    if path.is_file() and path.name not in ("size-report.json", ".gdignore"):
        data = path.read_bytes()
        files.append({"file": path.name, "bytes": len(data),
                      "gzip_bytes": len(gzip.compress(data, compresslevel=9, mtime=0))})
(output / "size-report.json").write_text(json.dumps({
    "files": files,
    "total_bytes": sum(file["bytes"] for file in files),
    "gzip_bytes": sum(file["gzip_bytes"] for file in files),
    "gzip_note": "Local gzip-9 estimate; host compression and transfer sizes can differ.",
}, indent=2) + "\n")
print(f"Exported {source_commit[:12]} to {output}")
