-- Standalone Lua 5.3 regression test for JokCombat_NativeKeyblades.lua.
-- LuaBackend memory APIs are replaced with a small in-memory Steam save block.

local memory = {}
local logs = {}

function ReadByte(address)
    return memory[address] or 0
end

function ReadShort(address)
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
local SORA_WEAPON = 0x2DE9396
local DONALD_WEAPON = 0x2DE940A
local GOOFY_WEAPON = 0x2DE947E
local INVENTORY_BASE = 0x2DE97F9
local ULTIMA = 0x64
local SAVE_THE_QUEEN = 0x72
local SAVE_THE_KING = 0x82

local TARGET_IDS = {
    0x51,
    0x56, 0x57, 0x58, 0x59, 0x5A, 0x5B, 0x5C,
    0x5D, 0x5E, 0x5F, 0x60, 0x61, 0x62, 0x63,
    0x65, 0x66,
}

memory[FINGERPRINT_ADDRESS] = FINGERPRINT
memory[PLAYER_POINTER_ADDRESS] = PLAYER_POINTER
memory[PLAYER_POINTER + 0x06C] = 0xCC10
memory[PLAYER_POINTER + 0x16C] = 0.0
memory[SORA_WEAPON] = 0x51
memory[DONALD_WEAPON] = 0x67
memory[GOOFY_WEAPON] = 0x77

-- Excluded tutorial/special weapons and Ultima must survive byte-for-byte.
memory[INVENTORY_BASE + 0x52] = 2
memory[INVENTORY_BASE + 0x53] = 3
memory[INVENTORY_BASE + 0x54] = 4
memory[INVENTORY_BASE + 0x55] = 5
memory[INVENTORY_BASE + ULTIMA] = 0

dofile("JokCombat_NativeKeyblades.lua")

local function findUpvalue(fn, targetName)
    for index = 1, 64 do
        local name, value = debug.getupvalue(fn, index)
        if name == nil then break end
        if name == targetName then return value end
    end
    return nil
end

local function assertTargetOwnership(equipped)
    for _, itemId in ipairs(TARGET_IDS) do
        local expected = itemId == equipped and 0 or 1
        local observed = ReadByte(INVENTORY_BASE + itemId)
        assert(observed == expected, string.format(
            "Keyblade 0x%02X stock: expected %d, got %d",
            itemId, expected, observed))
    end
end

local function assertPartyUltimateOwnership()
    local queenExpected = ReadByte(DONALD_WEAPON) == SAVE_THE_QUEEN
        and 0 or 1
    local kingExpected = ReadByte(GOOFY_WEAPON) == SAVE_THE_KING
        and 0 or 1
    assert(ReadByte(INVENTORY_BASE + SAVE_THE_QUEEN) == queenExpected,
        "Save the Queen ownership is not canonical")
    assert(ReadByte(INVENTORY_BASE + SAVE_THE_KING) == kingExpected,
        "Save the King ownership is not canonical")
end

local function assertExcludedUnchanged(ultimaCount)
    assert(ReadByte(INVENTORY_BASE + 0x52) == 2,
        "Dream Sword stock changed")
    assert(ReadByte(INVENTORY_BASE + 0x53) == 3,
        "Dream Shield stock changed")
    assert(ReadByte(INVENTORY_BASE + 0x54) == 4,
        "Dream Rod stock changed")
    assert(ReadByte(INVENTORY_BASE + 0x55) == 5,
        "Wooden Sword stock changed")
    assert(ReadByte(INVENTORY_BASE + ULTIMA) == ultimaCount,
        "Ultima Weapon stock changed")
end

_OnInit()
local reconcileKeyblades = findUpvalue(_OnFrame, "reconcileKeyblades")
assert(reconcileKeyblades ~= nil,
    "could not inspect source Keyblade reconciler")
local reportNativeState = findUpvalue(_OnFrame, "reportNativeState")
assert(reportNativeState ~= nil,
    "could not inspect source native-state reporter")
assert(reconcileKeyblades(), "initial Keyblade reconciliation failed")

assertTargetOwnership(0x51)
assertPartyUltimateOwnership()
assertExcludedUnchanged(0)

-- Simulate both allies equipping their final weapons. Each equipped copy
-- leaves the shared inventory while the other ownership records stay intact.
memory[DONALD_WEAPON] = SAVE_THE_QUEEN
memory[INVENTORY_BASE + SAVE_THE_QUEEN] = 0
assert(reconcileKeyblades(), "Save the Queen equip reconciliation failed")
assertPartyUltimateOwnership()

memory[GOOFY_WEAPON] = SAVE_THE_KING
memory[INVENTORY_BASE + SAVE_THE_KING] = 0
assert(reconcileKeyblades(), "Save the King equip reconciliation failed")
assertPartyUltimateOwnership()

-- Simulate KH1 equipping Oathkeeper: the old weapon returns to inventory and
-- the newly equipped weapon leaves inventory. This is already canonical.
memory[SORA_WEAPON] = 0x60
memory[INVENTORY_BASE + 0x51] = 1
memory[INVENTORY_BASE + 0x60] = 0
assert(reconcileKeyblades(), "equip-state reconciliation failed")
assertTargetOwnership(0x60)
assertPartyUltimateOwnership()
assertExcludedUnchanged(0)

-- A later native reward may increment an already-owned unique weapon. The
-- module removes only that duplicate stock count.
memory[INVENTORY_BASE + 0x59] = 2
assert(reconcileKeyblades(), "duplicate reward reconciliation failed")
assertTargetOwnership(0x60)
assertPartyUltimateOwnership()
assertExcludedUnchanged(0)

-- Naturally synthesized Ultima must remain untouched both in inventory and
-- while equipped.
memory[INVENTORY_BASE + ULTIMA] = 1
assert(reconcileKeyblades(), "post-Ultima reconciliation failed")
assertTargetOwnership(0x60)
assertPartyUltimateOwnership()
assertExcludedUnchanged(1)

memory[SORA_WEAPON] = ULTIMA
memory[INVENTORY_BASE + ULTIMA] = 0
memory[INVENTORY_BASE + 0x60] = 1
assert(reconcileKeyblades(), "equipped Ultima reconciliation failed")
assertTargetOwnership(ULTIMA)
assertPartyUltimateOwnership()
assertExcludedUnchanged(0)
reportNativeState()
assert(logs[#logs]:find("Save the Queen/King", 1, true) ~= nil,
    "native-state report omitted the ally final weapons")
assert(logs[#logs]:find("Ultima Weapon untouched", 1, true) ~= nil,
    "native-state report omitted the Ultima exclusion")

for _, message in ipairs(logs) do
    print(message)
end

print(string.format(
    "PASS: 17 native Keyblades plus Save the Queen/King granted exactly once; Ultima and special weapons untouched (%d logs)",
    #logs))
