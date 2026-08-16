-- Standalone Lua 5.3 regression test for the read-only MP hit probe.

local memory = {}
local logs = {}

function ReadByte(address)
    return memory[address] or 0
end

function ReadShort(address)
    return memory[address] or 0
end

function ReadInt(address)
    return memory[address] or 0
end

function ReadLong(address)
    return memory[address] or 0
end

function ReadFloat(address)
    return memory[address] or 0.0
end

function ConsolePrint(message)
    table.insert(logs, message)
end

GAME_ID = 0xAF71841E
ENGINE_TYPE = "BACKEND"

local FINGERPRINT_ADDRESS = 0x3B2271
local FINGERPRINT = 0x7265737563697065
local PLAYER_POINTER_ADDRESS = 0x2537E48
local BATTLE_SLOT_BASE = 0x2D50000
local CONNECT_COUNTER = 0x296B230
local PLAYER = 0x100000
local SLOT_REFERENCE = 0xCC10
local SORA_SLOT = BATTLE_SLOT_BASE + SLOT_REFERENCE

memory[FINGERPRINT_ADDRESS] = FINGERPRINT
memory[PLAYER_POINTER_ADDRESS] = PLAYER
memory[PLAYER + 0x06C] = SLOT_REFERENCE
memory[SORA_SLOT + 0x44] = 3
memory[SORA_SLOT + 0x48] = 5

local function frame(animation, secondary, time, signal, airborne)
    memory[PLAYER + 0x000] = animation == 0 and 0x03 or 0x07
    memory[PLAYER + 0x070] = airborne or 0
    memory[PLAYER + 0x164] = animation or 0
    memory[PLAYER + 0x168] = secondary or 0
    memory[PLAYER + 0x16C] = time or 0.0
    memory[CONNECT_COUNTER] = signal or 0
    _OnFrame()
end

local function countLogs(fragment)
    local count = 0
    for _, message in ipairs(logs) do
        if string.find(message, fragment, 1, true) ~= nil then
            count = count + 1
        end
    end
    return count
end

local function findLog(fragment)
    for _, message in ipairs(logs) do
        if string.find(message, fragment, 1, true) ~= nil then
            return message
        end
    end
    return nil
end

dofile("JokCombat_MPHitProbe.lua")
_OnInit()

-- Baseline, one connected ground normal, then one ground whiff.
frame(0x00, 0x00, 0.0, 0x00, 0)
frame(0xC8, 0x58, 0.0, 0x00, 0)
frame(0xC8, 0x58, 5.0, 0x01, 0)
frame(0xC8, 0x58, 6.0, 0x01, 0)
frame(0xC8, 0x58, 7.0, 0x00, 0)
frame(0x00, 0x00, 0.0, 0x00, 0)
frame(0xC9, 0x59, 0.0, 0x00, 0)
frame(0xC9, 0x59, 8.0, 0x00, 0)
frame(0x00, 0x00, 0.0, 0x00, 0)

-- Low-secondary C8 reuse is excluded and deduplicated.
frame(0xC8, 0x02, 0.0, 0x01, 0)
frame(0xC8, 0x02, 1.0, 0x01, 0)
frame(0x00, 0x00, 0.0, 0x00, 0)

-- A connected aerial normal and an independent native MP change.
frame(0xCC, 0x60, 0.0, 0x00, 2)
frame(0xCC, 0x60, 4.0, 0x40, 2)
memory[SORA_SLOT + 0x44] = 2
frame(0xCC, 0x60, 5.0, 0x00, 2)
frame(0x00, 0x00, 0.0, 0x00, 0)

for _, message in ipairs(logs) do print(message) end

assert(countLogs("[JokCombat:mp-hit-probe:hit-candidate]") == 2,
    "expected exactly one candidate for each connected normal attack")
assert(findLog("#1 ground/C8 hitCandidate=true") ~= nil,
    "connected ground normal was not summarized")
assert(findLog("#2 ground/C9 hitCandidate=false") ~= nil,
    "ground whiff was not summarized")
assert(countLogs("[JokCombat:mp-hit-probe:reuse-excluded]") == 1,
    "low-secondary animation reuse was not deduplicated")
assert(findLog("[JokCombat:mp-hit-probe:mp-change] 3/5 -> 2/5") ~= nil,
    "native MP change was not observed")

print(string.format(
    "PASS: hit, whiff, reuse exclusion and MP telemetry (%d logs)", #logs))
