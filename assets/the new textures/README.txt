PSX Comic-Noir Subway Texture Pack  (11 x 512x512 seamless PNG, RGB)

textures/   the PNGs
preview/    contact_sheet.png, tiling_check_2x2.png
generate_textures.py   regenerate / tweak (needs numpy + Pillow)
    python generate_textures.py --seed 7 --block 4 --preview --check

Godot 4 import (per texture, Import dock):
  - Filter: Nearest in the material (Texture > Filter = Nearest, or Nearest Mipmap)
  - Repeat: Enabled; Mipmaps: on (use Nearest Mipmap) to reduce shimmer
  - Compress: Lossless (VRAM compression smears the dither)
  - Use as albedo; keep albedo values low-contrast for the toon ramp.

Notes
  old_tile    = subway wall tile, running bond (64x32 tiles)
  dirty_tile  = square 64px tile grid, grimy, some missing tiles
  rail_dark   = horizontal strip; U runs along the rail, wear band near y 160-224
  faded_sign_paint = panel with inset off-white frame, no text (frame repeats if tiled)
  warning_stripe = off-white/near-black 45 deg stripes (no yellow, by design)
  rusty_metal = only texture with a warm tint (very desaturated brown-grey)
  Cyan/green: none (verified by --check). Add them in the shader.
