-- Standalone Lua 5.3 regression test for JokCombat_NativeAbilities.lua.
-- LuaBackend memory APIs are replaced with a small in-memory save block.

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

function WriteByte(address, value)
    memory[address] = value
end

function ConsolePrint(message)
    table.insert(logs, message)
end

GAME_ID = 0xAF71841E
ENGINE_TYPE = "BACKEND"

local FINGERPRINT_ADDRESS = 0x3B2271
local FINGERPRINT = 0x7265737563697065
local PLAYER_POINTER_ADDRESS = 0x2537E48
local PLAYER_POINTER = 0x100000
local SORA_MAX_AP = 0x2DE9369
local ABILITY_BASE = 0x2DE93A4
local GROUND_MAX = 0x2D5CCE4
local AIR_MAX = 0x2D5CCE5

memory[FINGERPRINT_ADDRESS] = FINGERPRINT
memory[PLAYER_POINTER_ADDRESS] = PLAYER_POINTER
memory[PLAYER_POINTER + 0x06C] = 0xCC10
memory[PLAYER_POINTER + 0x16C] = 0.0
memory[SORA_MAX_AP] = 3
memory[GROUND_MAX] = 7
memory[AIR_MAX] = 5

-- Representative contiguous early-game list. The three existing passive
-- entries deliberately start disabled to exercise the 0x80 migration too.
local initialAbilities = {
    0xC0, 0xB9, 0x05, 0x96, 0xB8, 0x0A, 0x8B,
    0x86, 0x87, 0xC1,
}
for index, value in ipairs(initialAbilities) do
    memory[ABILITY_BASE + index - 1] = value
end

local function collect(baseId)
    local slots = {}
    for index = 0, 47 do
        local value = ReadByte(ABILITY_BASE + index)
        if value ~= 0 and (value & 0x7F) == baseId then
            table.insert(slots, { index = index, value = value })
        end
    end
    return slots
end

local function assertExactActive(baseId, expectedCount, name)
    local slots = collect(baseId)
    assert(#slots == expectedCount, string.format(
        "%s count: expected %d, got %d", name, expectedCount, #slots))
    for _, slot in ipairs(slots) do
        assert((slot.value & 0x80) == 0, string.format(
            "%s slot %d remained disabled: 0x%02X",
            name, slot.index, slot.value))
    end
end

dofile("JokCombat_NativeAbilities.lua")
local function findUpvalue(fn, targetName)
    for index = 1, 64 do
        local name, value = debug.getupvalue(fn, index)
        if name == nil then break end
        if name == targetName then return value end
    end
    return nil
end

_OnInit()
local ensureNativePassives = findUpvalue(_OnFrame, "ensureNativePassives")
assert(ensureNativePassives ~= nil,
    "could not inspect source passive reconciler")
assert(ensureNativePassives(), "initial passive reconciliation failed")

for _, message in ipairs(logs) do
    print(message)
end

assert(ReadByte(SORA_MAX_AP) == 99, "Sora AP max was not raised to 99")
assertExactActive(0x06, 4, "Combo Plus")
assertExactActive(0x07, 2, "Air Combo Plus")
assertExactActive(0x41, 1, "Combo Master")
assert(ReadByte(ABILITY_BASE + 14) == 0,
    "ability list did not terminate after the granted passives")

-- Simulate a later vanilla reward appending a fifth Combo Plus immediately
-- before another learned ability. Reconciliation must remove only the surplus
-- copy, shift the following entry left and preserve a contiguous terminator.
memory[ABILITY_BASE + 14] = 0x06
memory[ABILITY_BASE + 15] = 0x3E
assert(ensureNativePassives(), "surplus reconciliation failed")

assertExactActive(0x06, 4, "Combo Plus after surplus reward")
assert(ReadByte(ABILITY_BASE + 14) == 0x3E,
    "ability-list compaction did not preserve the following entry")
assert(ReadByte(ABILITY_BASE + 15) == 0,
    "ability-list compaction did not restore the terminator")

-- Simulate the ability menu disabling an existing Air Combo Plus.
local airSlots = collect(0x07)
memory[ABILITY_BASE + airSlots[1].index] = 0x87
assert(ensureNativePassives(), "Air Combo Plus re-equip failed")
assertExactActive(0x07, 2, "Air Combo Plus after menu disable")

print(string.format(
    "PASS: exact native counts 4/2/1, surplus compaction and re-equip (%d logs)",
    #logs))
