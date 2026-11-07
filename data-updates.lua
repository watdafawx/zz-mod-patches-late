require("recipe-categories")()  -- (2.1: recipe category lists; see recipe-categories.lua)

-- MachineSpeedMultiplier multiplies lab.researching_speed in its data-final-fixes without a nil check,
-- but the field is optional (default 1) — e.g. technology_or's lab omits it. Runs last in data-updates,
-- i.e. before any mod's final-fixes.
if mods["MachineSpeedMultiplier"] then
  for _, lab in pairs(data.raw.lab) do
    lab.researching_speed = lab.researching_speed or 1
  end
end

-- Whats a Spoilage strips spoil_ticks/spoil_result from every item in its data-final-fixes.
-- Snapshot them here (after every data-updates, before any final-fixes) so data-final-fixes can
-- restore the ones listed in the "mod-patches-keep-spoiling" startup setting.
if mods["whats_a_spoilage"] then
  MOD_PATCHES_SPOIL_SNAPSHOT = {}
  for _, type in pairs({"item", "tool", "capsule", "ammo", "gun", "armor", "repair-tool", "module"}) do
    for name, item in pairs(data.raw[type] or {}) do
      if item.spoil_ticks then
        MOD_PATCHES_SPOIL_SNAPSHOT[type .. "/" .. name] = { ticks = item.spoil_ticks, result = item.spoil_result }
      end
    end
  end
end
