-- Factorio 2.1 renamed or moved some prototype fields. Mods made for 2.0 still write the old ones, which 2.1 refuses
-- ("Key ... not found") or ignores. Runs last (data-final-fixes) and moves each old field to where 2.1 wants it.

local function each(types, fn)
  for _, t in pairs(types) do
    for _, p in pairs(data.raw[t] or {}) do fn(p) end
  end
end

-- (every item-like type: science packs and the rest)
local ITEM_TYPES = {"item", "tool", "ammo", "capsule", "gun", "armor", "module", "repair-tool", "item-with-entity-data",
                    "item-with-label", "item-with-inventory", "item-with-tags", "rail-planner", "space-platform-starter-pack",
                    "spidertron-remote", "selection-tool", "blueprint", "blueprint-book", "copy-paste-tool",
                    "deconstruction-item", "upgrade-item"}

return function()
  -- technology research triggers: mine-entity's `entity` is now a list, `entities`
  each({"technology"}, function(t)
    local r = t.research_trigger
    if r and r.type == "mine-entity" and r.entity and not r.entities then
      r.entities = {r.entity}
      r.entity = nil
    end
  end)

  -- recipes: probability -> independent_probability; freshness flags moved from the recipe to its item results;
  -- always_show_products and show_amount_in_title are gone
  each({"recipe"}, function(r)
    for _, res in pairs(r.results or {}) do
      if res.probability ~= nil and res.independent_probability == nil then
        res.independent_probability = res.probability
      end
      res.probability = nil
      if res.type ~= "fluid" then
        if r.result_is_always_fresh and res.always_fresh == nil then res.always_fresh = true end
        if r.reset_freshness_on_craft and res.reset_freshness_on_craft == nil then res.reset_freshness_on_craft = true end
      end
    end
    r.result_is_always_fresh, r.reset_freshness_on_craft = nil, nil
    r.always_show_products, r.show_amount_in_title = nil, nil
  end)

  -- products anywhere (mining results, spoil and burnt results, ...): probability -> independent_probability
  local seen = {}
  local function walk(t, depth)
    if depth > 6 or seen[t] then return end
    seen[t] = true
    for k, v in pairs(t) do
      if type(v) == "table" then
        if k == "results" then
          for _, res in pairs(v) do
            if type(res) == "table" and res.probability ~= nil then
              if res.independent_probability == nil then res.independent_probability = res.probability end
              res.probability = nil
            end
          end
        end
        walk(v, depth + 1)
      end
    end
  end
  for _, t in pairs(data.raw) do walk(t, 0) end

  -- recipes Space Age renamed: references to the old names (technology effects, fixed recipes, ...)
  local RENAMED = {["molten-iron"] = "iron-ore-melting", ["molten-copper"] = "copper-ore-melting", ["wood-processing"] = "tree-seed"}
  local seen2 = {}
  local function rename(t, depth)
    if depth > 6 or seen2[t] then return end
    seen2[t] = true
    for k, v in pairs(t) do
      if (k == "recipe" or k == "fixed_recipe") and type(v) == "string" and RENAMED[v] and not data.raw.recipe[v]
          and data.raw.recipe[RENAMED[v]] then
        t[k] = RENAMED[v]
      elseif type(v) == "table" then
        rename(v, depth + 1)
      end
    end
  end
  for _, t in pairs({"technology", "assembling-machine", "furnace", "tips-and-tricks-item"}) do
    for _, p in pairs(data.raw[t] or {}) do rename(p, 0) end
  end

  -- technology effects naming a recipe nothing defines any more (a 2.0 one 2.1 removed): dropped, and logged
  for _, t in pairs(data.raw.technology) do
    if t.effects then
      for i = #t.effects, 1, -1 do
        local e = t.effects[i]
        if e.recipe and (e.type == "unlock-recipe" or e.type == "change-recipe-productivity") and not data.raw.recipe[e.recipe] then
          log("mod-patches-late: " .. t.name .. " named the missing recipe " .. e.recipe .. ": effect dropped")
          table.remove(t.effects, i)
        end
      end
    end
  end

  -- an entity with next_upgrade may not mine into a hidden item (2.1 checks it): such upgrade links are dropped
  local function hidden_item(name)
    for _, t in pairs(ITEM_TYPES) do
      local i = data.raw[t] and data.raw[t][name]
      if i then return i.hidden end
    end
  end
  local function item_exists(name)
    for _, t in pairs(ITEM_TYPES) do
      if data.raw[t] and data.raw[t][name] then return true end
    end
  end
  local placeable = {}  -- (entity name -> a visible item builds it)
  for _, t in pairs(ITEM_TYPES) do
    for _, i in pairs(data.raw[t] or {}) do
      if i.place_result and not i.hidden then placeable[i.place_result] = true end
    end
  end
  -- (the game asks the target's placeable_by when it has one, else the items placing it)
  local entity_of = {}
  for tn, t in pairs(data.raw) do
    for n, e in pairs(t) do
      if type(e) == "table" and (e.collision_box ~= nil or e.minable) then entity_of[n] = entity_of[n] or e end
    end
  end
  local function buildable(name)
    local target = entity_of[name]
    local by = target and target.placeable_by
    if by then
      if by.item then by = {by} end
      for _, b in pairs(by) do
        if b.item and item_exists(b.item) and not hidden_item(b.item) then return true end
      end
      return false
    end
    return placeable[name]
  end
  for _, t in pairs(data.raw) do
    for _, e in pairs(t) do
      if type(e) == "table" and e.next_upgrade and e.minable then
        local hid = e.minable.result and hidden_item(e.minable.result)
        for _, r in pairs(e.minable.results or {}) do
          if type(r) == "table" and (r.type or "item") == "item" and hidden_item(r.name) then hid = true end
        end
        if hid then
          log("mod-patches-late: " .. e.name .. " mines into a hidden item: next_upgrade " .. tostring(e.next_upgrade) .. " dropped")
          e.next_upgrade = nil
        elseif not buildable(e.next_upgrade) then
          log("mod-patches-late: " .. e.name .. "'s next_upgrade " .. e.next_upgrade .. " has no visible item: dropped")
          e.next_upgrade = nil
        end
      end
    end
  end

  -- items: fuel_category -> fuel_categories (2.1.20)
  each(ITEM_TYPES, function(i)
    if i.fuel_category and not i.fuel_categories then
      i.fuel_categories = {i.fuel_category}
    end
    i.fuel_category = nil
  end)

  -- assembling machines: enable_logistic_control_behavior is gone; "no-logistic-connection" says the opposite
  each({"assembling-machine"}, function(m)
    if m.enable_logistic_control_behavior == false then
      m.flags = m.flags or {}
      table.insert(m.flags, "no-logistic-connection")
    end
    m.enable_logistic_control_behavior = nil
  end)
  -- crafting machines: forced_symmetry is gone (use_mirroring replaced it)
  each({"assembling-machine", "furnace", "rocket-silo"}, function(m) m.forced_symmetry = nil end)
  -- asteroids: mass is gone
  each({"asteroid"}, function(a) a.mass = nil end)
  -- deconstruction planners: their filter counts are dynamic now
  each({"deconstruction-item"}, function(d) d.tile_filter_count, d.entity_filter_count = nil, nil end)
  -- pumps: the fluid wagon connector fields were replaced
  each({"pump"}, function(p) p.fluid_wagon_connector_alignment_tolerance, p.fluid_wagon_connector_graphics = nil, nil end)
  -- space platform hubs: dump_container is gone
  each({"space-platform-hub"}, function(h) h.dump_container = nil end)
  -- lightning: damage is DamageParameters now
  each({"lightning"}, function(l)
    if type(l.damage) == "number" then l.damage = {amount = l.damage, type = "electric"} end
  end)
  -- loot: a list of item products now ({item, probability, count_min, count_max} -> {type, name, ...})
  for _, t in pairs(data.raw) do
    for _, e in pairs(t) do
      if type(e) == "table" and type(e.loot) == "table" then
        for i, l in pairs(e.loot) do
          if type(l) == "table" and l.item and not l.name then
            e.loot[i] = {type = "item", name = l.item, amount_min = l.count_min or 1, amount_max = l.count_max or l.count_min or 1,
                         independent_probability = l.probability}
          end
        end
      end
    end
  end

  -- containers (and proxy and logistic ones): circuit_connector is a list now (one per direction)
  each({"container", "logistic-container", "proxy-container", "infinity-container", "linked-container"}, function(c)
    local cc = c.circuit_connector
    if type(cc) == "table" and (cc.sprites or cc.points) then c.circuit_connector = {cc} end
  end)

  -- logistic containers: the robot hatch animation moved into robot_door
  each({"logistic-container"}, function(c)
    if (c.animation or c.landing_location_offset or c.opened_duration or c.animation_sound) and not c.robot_door then
      c.robot_door = {animation = c.animation, landing_location_offset = c.landing_location_offset,
                      opened_duration = c.opened_duration, animation_sound = c.animation_sound}
    end
    c.animation, c.landing_location_offset, c.opened_duration, c.animation_sound = nil, nil, nil, nil
  end)
end
