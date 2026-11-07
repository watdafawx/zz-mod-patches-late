data:extend({
  {
    type = "string-setting",
    name = "mod-patches-keep-spoiling",
    setting_type = "startup",
    default_value = "@slag-pit",
    allow_blank = true,
    order = "a",
  },
  {
    type = "bool-setting",
    name = "mod-patches-static-menu",
    setting_type = "startup",
    default_value = true,
    order = "b",
  },
  {
    type = "string-setting",
    name = "mod-patches-hide-made-in",
    setting_type = "startup",
    default_value = "bioluminescent-* harene-infused-* speed-assembling-machine efficiency-assembling-machine quality-assembling-machine production-assembling-machine algite-assembler",
    allow_blank = true,
    order = "c",
  },
})
