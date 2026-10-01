"""Embed a regular-weight Korean font with only the game's visible glyphs."""
from pathlib import Path
from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

project = Path(__file__).resolve().parents[1]
source = project / "tools/fonts/NotoSansKR.ttf"
destination = project / "assets/fonts/NightKorean.ttf"
text = "".join(path.read_text() for path in sorted(project.glob("*.gd")) if not path.name.startswith("verify"))
characters = set(range(32, 127)) | {ord(character) for character in text}
font = TTFont(source)
instantiateVariableFont(font, {"wght": 400}, inplace=True)
for record in font["name"].names:
    if record.nameID in (1, 4, 6):
        record.string = ("NightKorean" if record.nameID == 6 else "Night Korean").encode(record.getEncoding())
options = subset.Options()
options.layout_features = ["*"]
options.name_IDs = [0, 1, 2, 3, 4, 5, 6, 13, 14]
subsetter = subset.Subsetter(options=options)
subsetter.populate(unicodes=characters)
subsetter.subset(font)
font.save(destination)
print(f"Web font: {destination.stat().st_size:,} bytes; {len(characters)} requested characters")
