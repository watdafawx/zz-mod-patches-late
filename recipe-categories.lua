-- Factorio 2.1: a recipe has a list of `categories` (`category` and `additional_categories` are gone, and the game
-- refuses a recipe that still has them), and the "x-or-y" categories are gone in favour of that list. Mods made for
-- 2.0 still write the old fields; some made for 2.1 read `recipe.categories` and expect it to be there. This turns
-- the old fields into the list, maps the removed categories onto the ones that replaced them, and fills in the
-- default ("crafting"), on recipes and on what can craft them. Run once from data-updates (every mod's data.lua is
-- done, no final-fixes yet) and again from data-final-fixes (for what was added since).

local REPLACED = {  -- (2.0 category -> 2.1 categories)
  ["basic-crafting"] = {"crafting"},
  ["recycling-or-hand-crafting"] = {"recycling", "hand-crafting"},
  ["chemistry-or-cryogenics"] = {"chemistry", "cryogenics"},
  ["pressing"] = {"crafting", "metallurgy"},
  ["crafting-with-fluid-or-metallurgy"] = {"crafting-with-fluid", "metallurgy"},
  ["metallurgy-or-assembling"] = {"metallurgy", "crafting"},
  ["organic-or-hand-crafting"] = {"organic", "hand-crafting"},
  ["organic-or-assembling"] = {"organic", "crafting"},
  ["organic-or-chemistry"] = {"organic", "chemistry"},
  ["electronics-or-assembling"] = {"electromagnetics", "crafting"},
  ["electronics"] = {"crafting", "electromagnetics"},
  ["electronics-with-fluid"] = {"crafting-with-fluid", "electromagnetics"},
  ["cryogenics-or-assembling"] = {"cryogenics", "crafting"},
}

local function known(c) return data.raw["recipe-category"][c] ~= nil end

-- a category list with the old names replaced (only when nothing defines the old one any more), no repeats
local function mapped(list)
  local out, seen = {}, {}
  for _, c in pairs(list) do
    for _, n in pairs((REPLACED[c] and not known(c)) and REPLACED[c] or {c}) do
      if known(n) and not seen[n] then
        seen[n] = true
        out[#out + 1] = n
      end
    end
  end
  return out
end

return function()
  for _, r in pairs(data.raw.recipe) do
    local list = {}
    for _, c in pairs(r.categories or {}) do list[#list + 1] = c end
    if r.category then list[#list + 1] = r.category end
    for _, c in pairs(r.additional_categories or {}) do list[#list + 1] = c end
    if #list == 0 then list = {"crafting"} end
    local new = mapped(list)
    if #new == 0 then new = {"crafting"} end
    r.category, r.additional_categories = nil, nil
    r.categories = new
  end
  -- (crafting machines and characters that still name a removed category get what replaced it)
  for _, t in pairs({"assembling-machine", "furnace", "rocket-silo", "character", "god-controller"}) do
    for _, e in pairs(data.raw[t] or {}) do
      if e.crafting_categories then
        local before = #e.crafting_categories
        local new = mapped(e.crafting_categories)
        if #new > 0 or before == 0 then e.crafting_categories = new end
      end
    end
  end
end
