-- Lua 5.3 regression test for the production melee-MP controller itself.

local memory = {}
local writes = {}
local logs = {}

CONFIG = {
    meleeMPRecovery = true,
    meleeHitsPerMP = 10,
}
ADDRESS = {
    battleSlotBase = 0x2D50000,
    connectCounter = 0x296B230,
}
PLAYER = { slotReference = 0x06C }

function ReadByte(address)
    return memory[address] or 0
end

function ReadShort(address)
    return memory[address] or 0
end

function WriteByte(address, value)
    memory[address] = value
    table.insert(writes, { address = address, value = value })
end

function log(message)
    table.insert(logs, message)
end

local sourceFile = assert(io.open("JokCombat_CombatPrototype.lua", "r"))
local source = sourceFile:read("*a")
sourceFile:close()
local controllerStart = assert(source:find("JokCombatMeleeMP = {", 1, true))
local controllerEnd = assert(source:find(
    "local function actionKind", controllerStart, true))
assert(load(source:sub(controllerStart, controllerEnd - 1)))()

local PLAYER_POINTER = 0x100000
local SLOT_REFERENCE = 0xCC10
local CURRENT_MP = ADDRESS.battleSlotBase + SLOT_REFERENCE + 0x44
local MAX_MP = ADDRESS.battleSlotBase + SLOT_REFERENCE + 0x48
local player = {
    pointer = PLAYER_POINTER,
    animation = 0x00,
    secondary = 0x00,
    airborneState = 0,
    time = 0.0,
}

memory[PLAYER_POINTER + PLAYER.slotReference] = SLOT_REFERENCE
memory[CURRENT_MP] = 2
memory[MAX_MP] = 4
memory[ADDRESS.connectCounter] = 0

local function observe(animation, secondary, time, signal, airborneState,
        nativeLimitActive)
    player.animation = animation
    player.secondary = secondary or 0x3C
    player.time = time or 0.0
    player.airborneState = airborneState or 0
    memory[ADDRESS.connectCounter] = signal or 0
    JokCombatMeleeMP.observe(player, nativeLimitActive == true)
end

local function hit(animation, secondary, airborneState)
    observe(animation, secondary, 0.0, 0x00, airborneState, false)
    observe(animation, secondary, 5.0, 0x01, airborneState, false)
end

assert(JokCombatMeleeMP.initialize(), "controller did not initialize")
observe(0x00, 0x00, 0.0, 0x00, 0, false)

-- Whiffs and special-action contacts never add charge.
observe(0xC8, 0x3C, 0.0, 0x00, 0, false)
observe(0x00, 0x00, 0.0, 0x00, 0, false)
observe(0xCF, 0x43, 0.0, 0x00, 0, false)
observe(0xCF, 0x43, 5.0, 0x01, 0, false)
observe(0xE7, 0x12, 0.0, 0x00, 0x27, true)
observe(0xE7, 0x12, 5.0, 0x40, 0x27, true)
assert(JokCombatMeleeMP.credit == 0, "whiff/special contact earned charge")

-- A multi-edge attack still earns only one charge.
observe(0xC8, 0x3C, 0.0, 0x00, 0, false)
observe(0xC8, 0x3C, 5.0, 0x01, 0, false)
observe(0xC8, 0x3C, 6.0, 0x00, 0, false)
observe(0xC8, 0x3C, 7.0, 0x40, 0, false)
assert(JokCombatMeleeMP.credit == 1,
    "one native attack earned more than one charge")

-- Nine more native normals complete ten hits and restore one MP.
hit(0xC9, 0x3D, 0)
hit(0xCA, 0x3E, 0)
hit(0xCB, 0x3F, 0)
hit(0xCC, 0x40, 2)
hit(0xCD, 0x41, 2)
hit(0xCE, 0x42, 2)
hit(0xC8, 0x3C, 0)
hit(0xC9, 0x3D, 0)
hit(0xCA, 0x3E, 0)
assert(memory[CURRENT_MP] == 3, "ten hits did not restore exactly 1 MP")
assert(#writes == 1 and writes[1].address == CURRENT_MP,
    "controller wrote outside current MP or wrote more than once")
assert(JokCombatMeleeMP.credit == 0, "charge did not reset after payout")

-- Low-secondary C8 Limit reuse is never eligible.
hit(0xC8, 0x02, 0)
assert(JokCombatMeleeMP.credit == 0,
    "low-secondary C8 reuse earned melee charge")

-- Full MP clears partial progress and cannot be pre-banked.
JokCombatMeleeMP.credit = 9
memory[CURRENT_MP] = 4
local writesBeforeFull = #writes
hit(0xCD, 0x41, 2)
assert(JokCombatMeleeMP.credit == 0, "full-MP hit retained banked charge")
assert(#writes == writesBeforeFull, "full-MP hit performed a write")

-- A new player object clears fractional process-local progress.
memory[CURRENT_MP] = 3
hit(0xCE, 0x42, 2)
assert(JokCombatMeleeMP.credit == 1, "eligible aerial hit was not counted")
player.pointer = PLAYER_POINTER + 0x1000
memory[player.pointer + PLAYER.slotReference] = SLOT_REFERENCE
observe(0x00, 0x00, 0.0, 0x00, 0, false)
assert(JokCombatMeleeMP.credit == 0, "player change retained local charge")

for _, message in ipairs(logs) do print("[test] " .. message) end
print(string.format(
    "PASS: production melee-MP controller; %d verified MP write(s), %d logs",
    #writes, #logs))
