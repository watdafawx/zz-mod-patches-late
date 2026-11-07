# zz-mod-patches-late

Late-loading compatibility fixes for big Factorio 2.1 modpacks. It loads after (almost) every other mod and fixes prototype
errors that stop the game from loading. Every fix only acts when the problem is present, and logs what it changed.

## What it fixes
- **Angels:** planets that list an autoplace control Angels removed (castra and `stone`: "is not a valid autoplace control
  name"); Angels icons declared with the wrong `icon_size` (sprite rectangle 64x64 outside the actual 32x32 sprite).
  `angels-icon-sizes.lua` holds the real PNG sizes of the Angels icons.
- **Factorio 2.1 port helpers:** recipe `category` lists to `categories`, `probability` to `independent_probability`, and
  other renamed or removed prototype fields (`recipe-categories.lua`, `proto-21.lua`).
- Labs listing a science pack twice, recipes listing an ingredient twice, recipes using fluids in a plain crafting category.
- Runtime: Disco Science Lite overlays after Quantum-Logistics clears every mod's render objects.

Optional dependencies on a few mods only keep this one last in the load order; none are required.

MIT licensed.
