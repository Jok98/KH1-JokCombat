-- Standalone Lua 5.3 regression test for the read-only X->Triangle detector.

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
local RAW_BUTTONS = 0x22C9301
local MENU_STATE = 0x2852790
local MENU_VISUAL = 0x2852794
local MENU_SLOT = 0x28527AC
local COMBO_POSITION = 0x296B221
local GROUND_MAX = 0x2D5CCE4
local AIR_MAX = 0x2D5CCE5
local PLAYER = 0x100000

memory[FINGERPRINT_ADDRESS] = FINGERPRINT
memory[PLAYER_POINTER_ADDRESS] = PLAYER
memory[PLAYER + 0x06C] = 0xCC10
memory[PLAYER + 0x16C] = 0.0
memory[GROUND_MAX] = 7
memory[AIR_MAX] = 5

local function frame(raw, airborne, animation, position, time,
        menuState, visualSlot, menuSlot)
    memory[RAW_BUTTONS] = raw or 0
    memory[PLAYER + 0x070] = airborne or 0
    memory[PLAYER + 0x164] = animation or 0
    memory[PLAYER + 0x168] = 0
    memory[PLAYER + 0x16C] = time or 0.0
    memory[COMBO_POSITION] = position or 0
    memory[MENU_STATE] = menuState or 0
    memory[MENU_VISUAL] = visualSlot or 0
    memory[MENU_SLOT] = menuSlot or 0
    _OnFrame()
end

local function findLog(fragment)
    for _, message in ipairs(logs) do
        if string.find(message, fragment, 1, true) ~= nil then
            return message
        end
    end
    return nil
end

dofile("JokCombat_StateProbe.lua")
_OnInit()

frame(0x00, 0, 0x00, 0, 0.0)
frame(0x10, 0, 0xC9, 2, 20.0)
frame(0x00, 0, 0xC9, 2, 21.0)
frame(0x10, 2, 0xCD, 4, 12.0)
frame(0x00, 2, 0xCD, 4, 13.0)
frame(0x10, 0, 0xC8, 1, 18.0, 0, 1, 1)
frame(0x00, 0, 0xC8, 1, 19.0)
frame(0x10, 0, 0x00, 1, 0.0)
frame(0x00, 0, 0x00, 1, 1.0)

local beforeChord = #logs
frame(0x11, 0, 0xC8, 1, 18.0)
frame(0x00, 0, 0xC8, 1, 19.0)

for _, message in ipairs(logs) do
    print(message)
end

assert(findLog("context=ground path=XXT position=2/7") ~= nil,
    "ground branch prefix was not recognized")
assert(findLog("context=air path=XXXXT position=4/5") ~= nil,
    "air branch prefix was not recognized")
assert(findLog("[branch:native] Triangle reserved for KH1 command") ~= nil,
    "native command priority was not recognized")
assert(findLog("[branch:neutral] Triangle stayed native") ~= nil,
    "neutral Triangle was not preserved")

for index = beforeChord + 1, #logs do
    assert(string.find(logs[index], "[branch:", 1, true) == nil,
        "modified Triangle was incorrectly added to the branch tree")
end

print(string.format(
    "PASS: ground/air X->Triangle prefixes and native priority (%d logs)",
    #logs))
