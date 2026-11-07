require("recipe-categories")()  -- (2.1: recipe category lists, for what was added since data-updates)

-- Labs with the same science pack listed twice fail prototype setup
-- (seen: harene-infused-lab ×2 lava-science-pack, from Rabbasca/Maraxsis/Science group edits).
for _, lab in pairs(data.raw.lab) do
  if lab.inputs then
    local seen, inputs = {}, {}
    for _, name in ipairs(lab.inputs) do
      if not seen[name] then
        seen[name] = true
        inputs[#inputs + 1] = name
      end
    end
    lab.inputs = inputs
  end
end

-- Recipes with the same ingredient listed twice fail prototype setup
-- (seen: solar-panel ×2 kr-glass, LavaBlock + Krastorio 2 both add it). Merge by summing amounts.
-- Fluids with temperature limits are left alone.
for _, recipe in pairs(data.raw.recipe) do
  if recipe.ingredients then
    local index, merged = {}, {}
    for _, ing in ipairs(recipe.ingredients) do
      local plain = ing.temperature == nil and ing.minimum_temperature == nil and ing.maximum_temperature == nil
      local key = plain and ing.name and ((ing.type or "item") .. "/" .. ing.name)
      local existing = key and index[key]
      if existing then
        existing.amount = existing.amount + ing.amount
      else
        if key then index[key] = ing end
        merged[#merged + 1] = ing
      end
    end
    recipe.ingredients = merged
  end
end

-- Recipes left in plain "crafting" while they use fluids fail prototype setup
-- (seen: express-underground-belt + lubricant, after Paracelsin/K2SO/Null's tweaks edits).
if data.raw["recipe-category"]["crafting-with-fluid"] then
  local function has_fluid(list)
    for _, entry in pairs(list or {}) do
      if entry.type == "fluid" then return true end
    end
  end
  for _, recipe in pairs(data.raw.recipe) do
    -- (2.1: a list of categories, normalised by recipe-categories.lua above)
    local cats = recipe.categories or {"crafting"}
    if (has_fluid(recipe.ingredients) or has_fluid(recipe.results)) then
      for i, c in pairs(cats) do
        if c == "crafting" then cats[i] = "crafting-with-fluid" end
      end
      recipe.categories = cats
    end
  end
end

-- Technologies with the same prerequisite listed twice fail prototype setup
-- (seen: fish-breeding ×2 OR-planet-discovery-nauvis-FOR-fish-breeding, from Better Planetary Starts).
-- So does a prerequisite another mod deleted later (seen: cs-simulate-planetaris-compression-science-pack ->
-- aai-hyper-loader; Compute Science links it in its final fixes, Arig deletes it in its own when
-- aai-loaders-sane is on). Drop those too.
for _, tech in pairs(data.raw.technology) do
  if tech.prerequisites then
    local seen, prereqs = {}, {}
    for _, name in ipairs(tech.prerequisites) do
      if not seen[name] and data.raw.technology[name] then
        seen[name] = true
        prereqs[#prereqs + 1] = name
      end
    end
    tech.prerequisites = prereqs
  end
end

-- Better Planetary Starts x Krastorio 2 Spaced Out
-- BPS puts space science before planet discovery (it clears space-platform's prereqs); K2SO then makes
-- space-science-pack require kr-research-server (→ chemical science → plastics → oil → planet discovery)
-- → tech-tree cycle. Drop that one edge.
if mods["better_planetary_starts_pre"] and mods["Krastorio2-spaced-out"] then
  local tech = data.raw.technology["space-science-pack"]
  if tech and tech.prerequisites then
    for i = #tech.prerequisites, 1, -1 do
      if tech.prerequisites[i] == "kr-research-server" then
        table.remove(tech.prerequisites, i)
      end
    end
  end
end

-- any-planet-start hides the start planet's planet-discovery-* tech (you're already there), but mods
-- running after it (e.g. Better-Planets tech-reparent) still hang techs off it → unresearchable
-- (seen: calcite-processing, tungsten-carbide under hidden planet-discovery-vulcanus). Unlink them.
if mods["any-planet-start"] then
  local techs = data.raw.technology
  for _, tech in pairs(techs) do
    if tech.prerequisites and not tech.hidden then
      for i = #tech.prerequisites, 1, -1 do
        local name = tech.prerequisites[i]
        local prereq = techs[name]
        if prereq and prereq.hidden and name:find("^planet%-discovery%-") then
          table.remove(tech.prerequisites, i)
        end
      end
    end
  end
end

-- Whats a Spoilage exceptions: restore spoiling for items matching the "mod-patches-keep-spoiling"
-- startup setting (snapshot taken in data-updates.lua) and drop their manual "wr-spoil-*" recipes.
if mods["whats_a_spoilage"] and MOD_PATCHES_SPOIL_SNAPSHOT then
  local names, prefixes, mod_names = {}, {}, {}
  for entry in settings.startup["mod-patches-keep-spoiling"].value:gmatch("[^%s,]+") do
    if entry:sub(1, 1) == "@" then
      mod_names[entry:sub(2)] = true
    elseif entry:sub(-1) == "*" then
      prefixes[#prefixes + 1] = entry:sub(1, -2)
    else
      names[entry] = true
    end
  end

  local function icon_mod(item)
    local icon = item.icon or (item.icons and item.icons[1] and item.icons[1].icon)
    return icon and icon:match("^__(.-)__/")
  end

  local function wanted(name, item)
    if names[name] or mod_names[icon_mod(item) or ""] then return true end
    for _, prefix in ipairs(prefixes) do
      if name:sub(1, #prefix) == prefix then return true end
    end
  end

  for key, spoil in pairs(MOD_PATCHES_SPOIL_SNAPSHOT) do
    local type, name = key:match("^(.-)/(.*)$")
    local item = data.raw[type][name]
    if item and wanted(name, item) then
      item.spoil_ticks = spoil.ticks
      item.spoil_result = spoil.result
      data.raw.recipe["wr-spoil-" .. name] = nil
    end
  end
end

-- Static main menu: drop every menu simulation (vanilla, Space Age, Paracelsin, Arig, Tellus, K2 sims, ...)
-- so the menu falls back to main_menu_background_image_location (K2's "Main menu background" setting picks it).
if settings.startup["mod-patches-static-menu"].value then
  data.raw["utility-constants"]["default"].main_menu_simulations = {}
end

-- Shorter "Made in" lists: the engine draws that list (no columns or wrapping), but a machine flagged
-- "not-in-made-in" drops out of it. Hides the machines matching the "mod-patches-hide-made-in" setting
-- (by default the Bioluminescent / Harene-infused copies of every machine). They still work and can be built.
do
  local names, prefixes, mod_names = {}, {}, {}
  for entry in settings.startup["mod-patches-hide-made-in"].value:gmatch("[^%s,]+") do
    if entry:sub(1, 1) == "@" then
      mod_names[entry:sub(2)] = true
    elseif entry:sub(-1) == "*" then
      prefixes[#prefixes + 1] = entry:sub(1, -2)
    else
      names[entry] = true
    end
  end
  local function icon_mod(proto)
    local icon = proto.icon or (proto.icons and proto.icons[1] and proto.icons[1].icon)
    return icon and icon:match("^__(.-)__/")
  end
  local function hide(name, proto)
    if names[name] or mod_names[icon_mod(proto) or ""] then return true end
    for _, prefix in ipairs(prefixes) do
      if name:sub(1, #prefix) == prefix then return true end
    end
  end
  for _, type in ipairs({ "assembling-machine", "furnace", "rocket-silo" }) do
    for name, proto in pairs(data.raw[type] or {}) do
      if hide(name, proto) then
        proto.flags = proto.flags or {}
        local has = false
        for _, f in ipairs(proto.flags) do if f == "not-in-made-in" then has = true end end
        if not has then table.insert(proto.flags, "not-in-made-in") end
      end
    end
  end
end

-- Synthetic-Eggs 0.0.3: its two technologies declare icon_size 256 for 128x128 images. Games with an old sprite crop
-- cache load anyway; a fresh cache (new install, game update) fails with "sprite rectangle ... outside the actual
-- sprite size" and no mods load.
if mods["Synthetic-Eggs"] then
  for _, kind in ipairs({ "pentapod", "biter" }) do
    local tech = data.raw.technology["synthetic-" .. kind .. "-dna"]
    if tech and tech.icon == "__Synthetic-Eggs__/graphics/technology/synthetic-" .. kind .. "-egg.png" and tech.icon_size == 256 then
      tech.icon_size = 128
    end
  end
end

-- (2.1, last: recipe category lists for what this file and the mods before it added, then renamed fields)
require("recipe-categories")()
require("proto-21")()

-- Planets listing an autoplace control that no longer exists fail prototype setup
-- (seen: castra wants "stone", Angels removes it for its own ores: '"stone" is not a valid autoplace control name').
-- Drop the dead names; PlanetsLib, Better-Planets etc. get blamed in the dialog but are innocent.
do
  local controls = data.raw["autoplace-control"] or {}
  for _, planet in pairs(data.raw.planet or {}) do
    local mgs = planet.map_gen_settings
    if mgs and mgs.autoplace_controls then
      for name in pairs(mgs.autoplace_controls) do
        if not controls[name] then
          log("zz-mod-patches-late: " .. planet.name .. " dropped missing autoplace control " .. name)
          mgs.autoplace_controls[name] = nil
        end
      end
    end
  end
end

-- Angels icons declared with the wrong icon_size crash sprite loading
-- (seen: angels-ore2.png is 32x32, something declares icon_size 64: "sprite rectangle 64x64 is outside the actual sprite size 32x32").
-- Set icon_size to the real size of the PNG, for every Angels icon we know the size of.
do
  local sizes = require("angels-icon-sizes")
  local function fix_layer(layer, inherited)
    local path = layer.icon
    local real = type(path) == "string" and sizes[path]
    if real and (layer.icon_size or inherited) ~= real then
      layer.icon_size = real
      return true
    end
  end
  local fixed = 0
  for _, group in pairs(data.raw) do
    for _, proto in pairs(group) do
      if type(proto) == "table" then
        if proto.icons then
          for _, layer in ipairs(proto.icons) do
            if fix_layer(layer, proto.icon_size) then fixed = fixed + 1 end
          end
        elseif proto.icon then
          if fix_layer(proto) then fixed = fixed + 1 end
        end
      end
    end
  end
  if fixed > 0 then log("zz-mod-patches-late: corrected icon_size on " .. fixed .. " Angels icon(s)") end
end
