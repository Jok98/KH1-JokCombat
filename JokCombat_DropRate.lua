LUAGUI_NAME = "JokCombat Drop Rate"
LUAGUI_AUTH = "Jok; Critical Mix reference by Xendra"
LUAGUI_DESC = "Sets both KH1 item and prize drop multipliers to 200%."

-- Fixed 200% drop-rate patch for the current Steam Global executable.
--
-- Critical Mix uses the same two operands, but selects 1.0x, 1.5x or 2.0x
-- from its difficulty setting and then applies separate weapon bonuses.
-- JokCombat deliberately keeps both base operands at 2.0x regardless of
-- difficulty. The patch is process-local and does not edit the save file.

local VERSION = "v0.1.0"
local EXPECTED_GAME_ID = 0xAF71841E
local FINGERPRINT = 0x7265737563697065 -- "epicures", little endian
local TARGET_MULTIPLIER = 2.0
local FLOAT_EPSILON = 0.0001

local ADDRESS = {
    fingerprint = 0x3B2271,

    -- Steam Global ports of Critical Mix EGS operands 0x2A1C14/0x2A1C1E.
    -- This code region uses the independently validated +0x47D0 shift.
    itemDropMultiplier = 0x2A63E4,
    prizeDropMultiplier = 0x2A63EE,
}

-- Each multiplier is the immediate operand of a `C7 05 disp32 imm32`
-- instruction. Verifying the complete six-byte prefix prevents a float write
-- on an unsupported executable even if its general build fingerprint matches.
local SIGNATURE = {
    item = { 0xC7, 0x05, 0xC0, 0xAB, 0xAB, 0x02 },
    prize = { 0xC7, 0x05, 0xB2, 0xAB, 0xAB, 0x02 },
}

local canRun = false
local ownsPatch = false
local originalItem = nil
local originalPrize = nil

local function log(message)
    ConsolePrint("[JokCombat:drop-rate] " .. message)
end

local function isFinite(value)
    return value == value and value > -math.huge and value < math.huge
end

local function approximatelyEqual(left, right)
    return math.abs(left - right) <= FLOAT_EPSILON
end

local function verifyInstruction(immediateAddress, signature)
    local instructionAddress = immediateAddress - #signature
    for index = 1, #signature do
        if ReadByte(instructionAddress + index - 1) ~= signature[index] then
            return false
        end
    end
    return true
end

local function restoreOwnedOperand(address, original, name)
    local current = ReadFloat(address)
    if not approximatelyEqual(current, TARGET_MULTIPLIER) then
        log(string.format(
            "%s multiplier changed externally to %.2f; leaving it untouched.",
            name, current))
        return false
    end

    WriteFloat(address, original)
    if not approximatelyEqual(ReadFloat(address), original) then
        log(string.format("WARNING: failed to restore %s multiplier.", name))
        return false
    end
    return true
end

function _OnInit()
    canRun = false
    ownsPatch = false
    originalItem = nil
    originalPrize = nil

    if GAME_ID ~= EXPECTED_GAME_ID or ENGINE_TYPE ~= "BACKEND"
        or ReadLong(ADDRESS.fingerprint) ~= FINGERPRINT then
        log("unsupported game/build; drop-rate patch disabled.")
        return
    end

    if not verifyInstruction(ADDRESS.itemDropMultiplier, SIGNATURE.item)
        or not verifyInstruction(
            ADDRESS.prizeDropMultiplier, SIGNATURE.prize) then
        log("Steam operand signature mismatch; all writes disabled.")
        return
    end

    originalItem = ReadFloat(ADDRESS.itemDropMultiplier)
    originalPrize = ReadFloat(ADDRESS.prizeDropMultiplier)
    if not isFinite(originalItem) or not isFinite(originalPrize)
        or originalItem < 0.0 or originalItem > 100.0
        or originalPrize < 0.0 or originalPrize > 100.0 then
        log("implausible original multiplier; all writes disabled.")
        return
    end

    WriteFloat(ADDRESS.itemDropMultiplier, TARGET_MULTIPLIER)
    WriteFloat(ADDRESS.prizeDropMultiplier, TARGET_MULTIPLIER)
    if not approximatelyEqual(
            ReadFloat(ADDRESS.itemDropMultiplier), TARGET_MULTIPLIER)
        or not approximatelyEqual(
            ReadFloat(ADDRESS.prizeDropMultiplier), TARGET_MULTIPLIER) then
        -- Restore only operands that this initialization may have changed.
        if approximatelyEqual(
                ReadFloat(ADDRESS.itemDropMultiplier), TARGET_MULTIPLIER) then
            WriteFloat(ADDRESS.itemDropMultiplier, originalItem)
        end
        if approximatelyEqual(
                ReadFloat(ADDRESS.prizeDropMultiplier), TARGET_MULTIPLIER) then
            WriteFloat(ADDRESS.prizeDropMultiplier, originalPrize)
        end
        log("write verification failed; original values restored.")
        return
    end

    canRun = true
    ownsPatch = true
    log(string.format(
        "Drop Rate %s active: item %.2fx -> %.2fx, prize %.2fx -> %.2fx.",
        VERSION, originalItem, TARGET_MULTIPLIER,
        originalPrize, TARGET_MULTIPLIER))
end

function _OnExit()
    if not canRun or not ownsPatch then return end

    local itemRestored = restoreOwnedOperand(
        ADDRESS.itemDropMultiplier, originalItem, "item")
    local prizeRestored = restoreOwnedOperand(
        ADDRESS.prizeDropMultiplier, originalPrize, "prize")
    ownsPatch = false
    canRun = false

    if itemRestored and prizeRestored then
        log(string.format(
            "original drop multipliers restored: item %.2fx, prize %.2fx.",
            originalItem, originalPrize))
    end
end
