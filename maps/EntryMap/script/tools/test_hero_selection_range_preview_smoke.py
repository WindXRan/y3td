#!/usr/bin/env python
# -*- coding: utf-8 -*-

import subprocess
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
REPO_ROOT = ROOT.parents[1]
MODULE_PATH = ROOT / "script" / "runtime" / "hero_selection_range.lua"
LUA = Path(r"C:\Users\裴浩然\AppData\Local\Programs\Lua\5.4.8\lua.exe")
LUAC = Path(r"C:\Users\裴浩然\AppData\Local\Programs\Lua\5.4.8\luac.exe")


def run(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        cmd,
        cwd=REPO_ROOT,
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
        check=False,
    )


def assert_ok(result: subprocess.CompletedProcess[str], message: str) -> None:
    if result.returncode != 0:
        raise AssertionError(f"{message}\nSTDOUT:\n{result.stdout}\nSTDERR:\n{result.stderr}")


def main() -> None:
    syntax = run([str(LUAC), "-p", str(MODULE_PATH)])
    assert_ok(syntax, "runtime/hero_selection_range.lua syntax check failed")

    smoke_source = r"""
package.path = 'maps/EntryMap/script/?.lua;maps/EntryMap/script/?/init.lua;maps/EntryMap/script/?/?.lua;' .. package.path

local selection_range = require('runtime.hero_selection_range')
local registered = {}
local loop_callback = nil
local loop_remove_count = 0
local particle_creations = {}
local particle_removes = 0
local builtin_preview_calls = {}
local particle_updates = {
  points = {},
  scales = {},
  heights = {},
}

local function make_point(x, y, z)
  local point = { x = x or 0, y = y or 0, z = z or 0 }
  function point:get_x()
    return self.x
  end
  function point:get_y()
    return self.y
  end
  function point:get_z()
    return self.z
  end
  function point:move(dx, dy, dz)
    return make_point(self.x + (dx or 0), self.y + (dy or 0), self.z + (dz or 0))
  end
  return point
end

local hero = { exists = true, point = make_point(120, 220, 0) }
function hero:is_exist()
  return self.exists
end
function hero:get_point()
  return self.point
end

local creep = { exists = true, point = make_point(400, 500, 0) }
function creep:is_exist()
  return self.exists
end
function creep:get_point()
  return self.point
end

local local_player = { selected_unit = hero }
function local_player:get_local_selecting_unit()
  return self.selected_unit
end

local current_range = 2000
local state = {
  hero = hero,
  session_phase = 'battle',
  game_finished = false,
}

local system = selection_range.create({
  STATE = state,
  y3 = {
    const = {
      MouseKey = {
        LEFT = 0xF0,
      },
    },
    game = {
      event = function(self, name, arg2, arg3)
        if arg3 ~= nil then
          registered[name] = {
            key = arg2,
            callback = arg3,
          }
          return
        end
        registered[name] = arg2
      end,
    },
    player = {
      with_local = function(callback)
        callback(local_player)
      end,
    },
    ability = {
      set_normal_attack_preview_state = function(player, state)
        builtin_preview_calls[#builtin_preview_calls + 1] = {
          player = player,
          state = state,
        }
      end,
    },
    helper = {
      tonumber = tonumber,
    },
    ltimer = {
      loop = function(_, callback)
        loop_callback = callback
        return {
          remove = function()
            loop_remove_count = loop_remove_count + 1
          end,
        }
      end,
    },
    particle = {
      create = function(args)
        particle_creations[#particle_creations + 1] = {
          type = args.type,
          scale = args.scale,
          height = args.height,
          target_x = args.target:get_x(),
          target_y = args.target:get_y(),
        }
        return {
          set_point = function(_, point)
            particle_updates.points[#particle_updates.points + 1] = {
              x = point:get_x(),
              y = point:get_y(),
            }
          end,
          set_scale = function(_, x, y, z)
            particle_updates.scales[#particle_updates.scales + 1] = { x = x, y = y, z = z }
          end,
          set_height = function(_, height)
            particle_updates.heights[#particle_updates.heights + 1] = height
          end,
          remove = function()
            particle_removes = particle_removes + 1
          end,
        }
      end,
    },
  },
  is_battle_active = function()
    return state.session_phase == 'battle' and state.game_finished ~= true
  end,
  get_current_basic_attack_range = function()
    return current_range
  end,
})

system.register_runtime_events()
assert(#particle_creations == 0, 'register should not show the preview before the player clicks the hero')
assert(#builtin_preview_calls >= 1, 'register should proactively disable the builtin attack preview ring')
assert(builtin_preview_calls[#builtin_preview_calls].state == false, 'builtin attack preview should be disabled on register')

assert(registered['本地-鼠标-按下单位'].key == 0xF0, 'preview should bind to local left click on a unit')

registered['本地-鼠标-按下单位'].callback(nil, { unit = hero })
assert(#particle_creations == 1, 'clicking the hero should create one preview particle')
assert(particle_creations[#particle_creations].type == 101492, 'hero click should use the expected range preview particle')
assert(particle_creations[#particle_creations].scale >= 12, 'hero click should scale the range preview particle close to the runtime range')

registered['本地-选中-单位'](nil, { unit = creep })
assert(particle_removes >= 1, 'selecting a non-hero should remove the preview particle')
assert(loop_remove_count >= 1, 'selecting a non-hero should stop the preview update timer')

registered['本地-鼠标-按下单位'].callback(nil, { unit = hero })
assert(#particle_creations >= 2, 'clicking the hero again should recreate the preview particle')

local_player.selected_unit = hero
registered['本地-选中-单位组'](nil, { player = local_player })
assert(particle_removes >= 1, 'group selection that still points at hero should not force a new preview by itself')

current_range = 2600
hero.point = make_point(180, 260, 0)
loop_callback({ remove = function() end }, 1)
assert(#particle_updates.points >= 1, 'update loop should keep the preview particle following the hero')
assert(#particle_updates.scales >= 1, 'update loop should refresh preview scale when range changes')

registered['本地-选中-取消'](nil, {})
assert(particle_removes >= 2, 'cancel selection should hide the preview particle')

state.game_finished = true
registered['本地-选中-单位'](nil, { unit = hero })
assert(particle_removes >= 2, 'finished battles should not keep the preview enabled')

system.disable_local_preview()
assert(particle_removes >= 2, 'disable_local_preview should be safe to call repeatedly')

print('hero selection range smoke ok')
"""

    with tempfile.NamedTemporaryFile("w", encoding="utf-8", suffix=".lua", delete=False) as handle:
        handle.write(smoke_source)
        smoke_path = Path(handle.name)

    try:
        smoke = run([str(LUA), str(smoke_path)])
    finally:
        smoke_path.unlink(missing_ok=True)

    assert_ok(smoke, "hero selection range smoke failed")


if __name__ == "__main__":
    main()
