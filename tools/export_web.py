"""Export the committed game and its notices for any static web host."""
import argparse
import hashlib
import json
import shutil
import subprocess
from pathlib import Path

project = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--godot", default="godot")
parser.add_argument("--output", type=Path, required=True)
args = parser.parse_args()
output = args.output.resolve()
output.mkdir(parents=True, exist_ok=True)

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
    "godot_version": subprocess.check_output([args.godot, "--version"], text=True).strip(),
    "pack_sha256": pack_hash,
}, indent=2) + "\n")
print(f"Exported {source_commit[:12]} to {output}")
