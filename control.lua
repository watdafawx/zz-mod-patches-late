-- Runtime patches. Every patch is guarded: each only acts when the mods it touches are loaded.

-- Quantum-Logistics calls rendering.clear() with no mod name in on_configuration_changed, which destroys
-- EVERY mod's render objects. Disco Science Lite then touches its (now dead) lab overlays on the next tick
-- and crashes ("LuaRenderObject API call when LuaRenderObject was invalid"). This mod's
-- on_configuration_changed runs after both (hidden optional deps in info.json), so ask Disco to rebuild its
-- overlays. Its remote setLabScale triggers a full rebuild; a lab name that doesn't exist leaves every real
-- lab's scale untouched.
local function rebuild_disco_overlays()
  if not (script.active_mods["Quantum-Logistics"] and script.active_mods["disco-science-lite"]) then return end
  local iface = remote.interfaces["DiscoScience"]
  if not (iface and iface.setLabScale) then return end
  local ok, err = pcall(remote.call, "DiscoScience", "setLabScale", "zz-mod-patches-late-rebuild", 1)
  log(ok and "rebuilt Disco Science Lite overlays after Quantum-Logistics' rendering.clear()"
         or ("Disco Science Lite rebuild failed: " .. tostring(err)))
end

script.on_configuration_changed(function()
  rebuild_disco_overlays()
end)


-- power-propagation hides a pole in every powered building and wires it to the poles around. A real pole near a
-- few buildings can end up "full" of those hidden wires, and then a pole placed next to it gets no wire to it: it
-- runs only through hidden poles, and drops off the network when those buildings are removed. Give a newly built
-- pole real wires: to the nearest real pole in reach, and to any other real pole in reach it isn't already joined
-- to through real wires.
local HIDDEN = "power%-propagation%-invisible%-pole"

local function is_real(pole)
  return pole.type == "electric-pole" and not string.find(pole.name, HIDDEN)
end

local function copper(pole)
  return pole.get_wire_connector(defines.wire_connector_id.pole_copper, true)
end

--- real poles joined to `pole` through real copper wires (bounded to the neighbourhood: every pole also has wires
--- to the hidden poles of the buildings around it, so a wide search is slow; a pole beyond it may get a spare wire)
local SEARCH = 60
local function real_component(pole)
  local seen, todo, n = { [pole.unit_number] = true }, { pole }, 1
  while #todo > 0 and n < SEARCH do
    local p = table.remove(todo)
    for _, c in pairs(copper(p).connections) do
      local o = c.target.owner
      if is_real(o) and o.unit_number and not seen[o.unit_number] then
        seen[o.unit_number] = true
        n = n + 1
        todo[#todo + 1] = o
      end
    end
  end
  return seen
end

local function wire_real(pole)
  if not (pole and pole.valid and is_real(pole)) then return end
  local reach = pole.prototype.get_max_wire_distance(pole.quality)
  local near = pole.surface.find_entities_filtered({ type = "electric-pole", force = pole.force, position = pole.position,
    radius = reach })
  local cands = {}
  for _, o in pairs(near) do
    if o ~= pole and is_real(o) then
      local d = math.sqrt((o.position.x - pole.position.x) ^ 2 + (o.position.y - pole.position.y) ^ 2)
      if d <= math.min(reach, o.prototype.get_max_wire_distance(o.quality)) then
        cands[#cands + 1] = { pole = o, d = d }
      end
    end
  end
  table.sort(cands, function(a, b) return a.d < b.d end)
  local joined = real_component(pole)
  local added = 0
  for _, c in ipairs(cands) do
    if added >= 5 then break end
    if not joined[c.pole.unit_number] then
      copper(pole).connect_to(copper(c.pole), false)
      added = added + 1
      for k in pairs(real_component(c.pole)) do joined[k] = true end
    end
  end
end

if script.active_mods["power-propagation"] then
  -- (a filter per event: only poles reach Lua at all, not every building placed or upgraded)
  local function on_pole(e)
    local pole = e.entity
    if pole and pole.valid and pole.type == "electric-pole" then wire_real(pole) end
  end
  local only_poles = { { filter = "type", type = "electric-pole" } }
  for _, ev in pairs({ defines.events.on_built_entity, defines.events.on_robot_built_entity,
      defines.events.script_raised_built, defines.events.script_raised_revive }) do
    script.on_event(ev, on_pole, only_poles)
  end
end
