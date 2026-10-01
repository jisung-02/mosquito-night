"""Godot 4.7.2 release profile for this game's canvas-only runtime."""

platform = "web"
target = "template_release"
arch = "wasm32"
threads = False
dlink_enabled = False
optimize = "size"
lto = "full"
debug_symbols = False
deprecated = False
disable_3d = True
disable_physics_2d = True
disable_advanced_gui = True
modules_enabled_by_default = False
module_gdscript_enabled = True
module_freetype_enabled = True
module_text_server_adv_enabled = True
module_webp_enabled = True
graphite = False
