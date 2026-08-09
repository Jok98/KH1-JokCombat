LUAGUI_NAME = "JokCombat Input Probe"
LUAGUI_AUTH = "Jok"
LUAGUI_DESC = "Read-only Steam input/address validation for JokCombat."

-- Read-only validation step. This file never changes game memory.

local EXPECTED_GAME_ID = 0xAF71841E
local FINGERPRINT = 0x7265737563697065 -- "epicures", little endian

local STEAM_GL = {
    fingerprint = 0x3B2271,
    rawButtons = 0x22C9301,
    commandButtons = 0x23407B5,
    commandMenuSlot = 0x28527AC,

    controlMapL2 = 0x22C9340,
    controlMapCircle = 0x22C9345,
    controlMapCross = 0x22C9346,
    controlMapSquare = 0x22C9347,

    forceCircleBranch = 0x2A7B74,
    forceSquareBranch = 0x2A7BD6,
    airRollBranch = 0x2A7BE0,
    guardAvailabilityBranch = 0x2A7BFD,
    forceGuardSelectionBranch = 0x2A7C01,
    dodgeAvailabilityBranch = 0x2A7C1F,
}

local BUTTONS = {
    { mask = 0x01, name = "L2" },
    { mask = 0x02, name = "R2" },
    { mask = 0x04, name = "L1" },
    { mask = 0x08, name = "R1" },
    { mask = 0x10, name = "TRIANGLE" },
    { mask = 0x20, name = "CIRCLE" },
    { mask = 0x40, name = "CROSS" },
    { mask = 0x80, name = "SQUARE" },
}

local canRun = false
local lastRaw = -1
local lastCommand = -1

local function namesFor(value)
    if value == 0 then return "released" end
    local names = {}
    for _, button in ipairs(BUTTONS) do
        if (value & button.mask) ~= 0 then
            table.insert(names, button.name)
        end
    end
    if #names == 0 then return "unknown" end
    return table.concat(names, "+")
end

local function verifyByte(name, address, expected)
    local actual = ReadByte(address)
    if actual ~= expected then
        ConsolePrint(string.format(
            "[input:opcode-mismatch] %s RVA=0x%X expected=0x%02X actual=0x%02X",
            name, address, expected, actual))
        return false
    end
    return true
end

function _OnInit()
    lastRaw = -1
    lastCommand = -1

    if GAME_ID ~= EXPECTED_GAME_ID or ENGINE_TYPE ~= "BACKEND" then
        ConsolePrint("JokCombat Input Probe - wrong game or Lua engine; disabled.")
        canRun = false
        return
    end
    if ReadLong(STEAM_GL.fingerprint) ~= FINGERPRINT then
        ConsolePrint("JokCombat Input Probe - unsupported executable; disabled.")
        canRun = false
        return
    end

    local valid = true
    valid = verifyByte("forceCircle", STEAM_GL.forceCircleBranch, 0x74) and valid
    valid = verifyByte("forceSquare", STEAM_GL.forceSquareBranch, 0x84) and valid
    valid = verifyByte("airRoll", STEAM_GL.airRollBranch, 0x85) and valid
    valid = verifyByte("guardAvailability", STEAM_GL.guardAvailabilityBranch, 0x74) and valid
    valid = verifyByte("guardSelection", STEAM_GL.forceGuardSelectionBranch, 0x74) and valid
    valid = verifyByte("dodgeAvailability", STEAM_GL.dodgeAvailabilityBranch, 0x84) and valid

    canRun = valid
    if not canRun then
        ConsolePrint("JokCombat Input Probe - opcode validation failed; logging disabled.")
        return
    end

    ConsolePrint(string.format(
        "JokCombat Input Probe ready (read-only). controlMap L2/Circle/Cross/Square="
        .. "%02X/%02X/%02X/%02X",
        ReadByte(STEAM_GL.controlMapL2),
        ReadByte(STEAM_GL.controlMapCircle),
        ReadByte(STEAM_GL.controlMapCross),
        ReadByte(STEAM_GL.controlMapSquare)))
end

function _OnFrame()
    if not canRun then return end

    local raw = ReadByte(STEAM_GL.rawButtons)
    local command = ReadByte(STEAM_GL.commandButtons)
    if raw == lastRaw and command == lastCommand then return end

    ConsolePrint(string.format(
        "[input] raw=0x%02X (%s) command=0x%02X (%s) menuSlot=0x%02X",
        raw, namesFor(raw),
        command, namesFor(command),
        ReadByte(STEAM_GL.commandMenuSlot)))
    lastRaw = raw
    lastCommand = command
end
