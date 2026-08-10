LUAGUI_NAME = "JokCombat Native Abilities"
LUAGUI_AUTH = "Jok; Critical Mix reference by Xendra"
LUAGUI_DESC = "Grants and keeps JokCombat's native combo passives equipped."

-- JokCombat native ability grant for the current Steam Global build.
--
-- This intentionally follows KH1's real Sora ability list instead of routing
-- around the native passive checks. Critical Mix's authorized learn_ability
-- reference writes a new ability into the first 0x00 slot; preserving that
-- contiguous order matters because a trailing entry after the list terminator
-- is not guaranteed to be visited by KH1's native dispatcher.
--
-- The Steam save block starts at 0x2DE9360. Its four-byte save header is
-- followed by Sora's 0x74-byte Character record: AP max is Character+0x05
-- (save+0x09), while the 48 ability bytes start at Character+0x40
-- (save+0x44). These offsets are independently described by Kingdom Save
-- Editor's KH1 Character model and match the live Kingdom Key byte at
-- Character+0x32. Do not port the old EGS globals with one uniform delta.
--
-- Unlike the retired NativePassiveTest, these are deliberate progression
-- writes. Once the player saves, the three equipped abilities become part of
-- that save. JokCombat creates no duplicate when an ability already exists.

local VERSION = "v0.2.1"
local EXPECTED_GAME_ID = 0xAF71841E
local FINGERPRINT = 0x7265737563697065 -- "epicures", little endian
local ABILITY_SLOT_COUNT = 48
local REPORT_DELAY_FRAMES = 30
local TARGET_MAX_AP = 99

local ADDRESS = {
    fingerprint = 0x3B2271,
    playerPointer = 0x2537E48,
    soraMaxAP = 0x2DE9369,
    soraAbilitySlots = 0x2DE93A4,
    maxGroundCombo = 0x2D5CCE4,
    maxAirCombo = 0x2D5CCE5,
    inMenu = 0x232DF80,
    saveMenuOpen = 0x232DF84,
    pauseMenuOpen = 0x2867374,
}

-- v0.1.x used EGS-derived globals ten bytes before the real Steam ability
-- list and also mistook a pointer byte for AP. Restore only the exact values
-- JokCombat injected there. A pre-test save backup confirms all four original
-- bytes were 0x00; any unexpected value is left untouched.
local LEGACY_WRONG_WRITES = {
    { address = 0x2DE9359, injected = 99, original = 0x00,
        name = "legacy false AP byte" },
    { address = 0x2DE9394, injected = 0x87, original = 0x00,
        name = "legacy false Air Combo Plus slot" },
    { address = 0x2DE9395, injected = 0xC1, original = 0x00,
        name = "legacy false Combo Master slot" },
    { address = 0x2DE9397, injected = 0x86, original = 0x00,
        name = "legacy false Combo Plus slot" },
}

local PLAYER = {
    slotReference = 0x06C,
    animationTime = 0x16C,
}

local PASSIVES = {
    -- KH1 uses the high bit as the disabled flag: the base ID is equipped,
    -- while ID|0x80 is learned but unequipped.
    { name = "Combo Plus", base = 0x06, equipped = 0x06,
        unequipped = 0x86 },
    { name = "Air Combo Plus", base = 0x07, equipped = 0x07,
        unequipped = 0x87 },
    { name = "Combo Master", base = 0x41, equipped = 0x41,
        unequipped = 0xC1 },
}

local canRun = false
local applied = false
local reportFrames = 0
local pendingReport = false
local waitingLogged = false

local function log(message)
    ConsolePrint("[JokCombat:native-abilities] " .. message)
end

local function isPlausiblePointer(value)
    return value >= 0x10000 and value <= 0x00007FFFFFFFFFFF
end

local function isFinite(value)
    return value == value and value > -math.huge and value < math.huge
end

local function playerIsValid(playerPointer)
    if not isPlausiblePointer(playerPointer) then return false end
    local slotReference = ReadShort(
        playerPointer + PLAYER.slotReference, true)
    if slotReference < 0x8000 or slotReference > 0xFFFF then return false end
    local animationTime = ReadFloat(
        playerPointer + PLAYER.animationTime, true)
    return isFinite(animationTime) and math.abs(animationTime) <= 100000.0
end

local function menuIsOpen()
    return ReadByte(ADDRESS.inMenu) ~= 0
        or ReadByte(ADDRESS.saveMenuOpen) ~= 0
        or ReadByte(ADDRESS.pauseMenuOpen) ~= 0
end

local function baseAbilityId(value)
    return value & 0x7F
end

local function findAbility(baseId)
    for index = 0, ABILITY_SLOT_COUNT - 1 do
        local value = ReadByte(ADDRESS.soraAbilitySlots + index)
        if value ~= 0 and baseAbilityId(value) == baseId then
            return index, value
        end
    end
    return nil, nil
end

local function findFirstEmptySlot()
    for index = 0, ABILITY_SLOT_COUNT - 1 do
        if ReadByte(ADDRESS.soraAbilitySlots + index) == 0 then
            return index
        end
    end
    return nil
end

local function verifyEquipped(passive)
    local index, value = findAbility(passive.base)
    return index ~= nil and (value & 0x80) == 0, index, value
end

local function repairLegacyWrongWrites()
    local repaired = 0
    for _, entry in ipairs(LEGACY_WRONG_WRITES) do
        local value = ReadByte(entry.address)
        if value == entry.injected then
            WriteByte(entry.address, entry.original)
            if ReadByte(entry.address) ~= entry.original then
                return false, entry.name .. " could not be restored"
            end
            repaired = repaired + 1
        elseif value ~= entry.original then
            return false, string.format(
                "%s has unexpected value 0x%02X; refusing to overwrite it",
                entry.name, value)
        end
    end
    if repaired > 0 then
        log(string.format(
            "repaired %d legacy wrong-offset byte(s) from v0.1.x.",
            repaired))
    end
    return true, repaired
end

local function grantOrEquip(passive)
    local index, value = findAbility(passive.base)
    if index ~= nil then
        if (value & 0x80) ~= 0 then
            WriteByte(ADDRESS.soraAbilitySlots + index, passive.equipped)
            if ReadByte(ADDRESS.soraAbilitySlots + index)
                ~= passive.equipped then
                return false, string.format(
                    "%s could not be equipped at slot %d",
                    passive.name, index)
            end
            log(string.format(
                "%s equipped natively at existing slot %d: 0x%02X -> 0x%02X.",
                passive.name, index, value, passive.equipped))
            return true, "equipped"
        end
        return true, "already-equipped"
    end

    index = findFirstEmptySlot()
    if index == nil then
        return false, passive.name .. " could not be learned: ability list full"
    end

    WriteByte(ADDRESS.soraAbilitySlots + index, passive.equipped)
    if ReadByte(ADDRESS.soraAbilitySlots + index) ~= passive.equipped then
        return false, string.format(
            "%s write verification failed at slot %d", passive.name, index)
    end
    log(string.format(
        "%s learned and equipped natively at first empty slot %d: 0x%02X.",
        passive.name, index, passive.equipped))
    return true, "learned"
end

local function ensureNativePassives()
    local changed = false

    local repairOk, repairedOrError = repairLegacyWrongWrites()
    if not repairOk then
        log("ERROR: " .. repairedOrError .. ".")
        return false
    end
    if repairedOrError > 0 then changed = true end

    if ReadByte(ADDRESS.soraMaxAP) ~= TARGET_MAX_AP then
        local previous = ReadByte(ADDRESS.soraMaxAP)
        WriteByte(ADDRESS.soraMaxAP, TARGET_MAX_AP)
        if ReadByte(ADDRESS.soraMaxAP) ~= TARGET_MAX_AP then
            log(string.format(
                "ERROR: Sora max AP write failed: %d -> %d.",
                previous, TARGET_MAX_AP))
            return false
        end
        log(string.format(
            "Sora max AP set natively: %d -> %d.",
            previous, TARGET_MAX_AP))
        changed = true
    end

    for _, passive in ipairs(PASSIVES) do
        local ok, result = grantOrEquip(passive)
        if not ok then
            log("ERROR: " .. result .. ".")
            return false
        end
        if result ~= "already-equipped" then changed = true end
    end

    for _, passive in ipairs(PASSIVES) do
        local equipped, index, value = verifyEquipped(passive)
        if not equipped then
            log(string.format(
                "ERROR: %s failed final verification (slot=%s value=%s).",
                passive.name, tostring(index), tostring(value)))
            return false
        end
    end

    if changed then
        log("native passive grant complete; changes will persist when KH1 saves.")
    else
        log("all three native passives already learned and equipped; no writes.")
    end
    applied = true
    pendingReport = true
    reportFrames = REPORT_DELAY_FRAMES
    return true
end

local function reportNativeState()
    local details = {}
    for _, passive in ipairs(PASSIVES) do
        local equipped, index, value = verifyEquipped(passive)
        table.insert(details, string.format(
            "%s=%s@%s/0x%02X",
            passive.name,
            equipped and "on" or "off",
            index ~= nil and tostring(index) or "-",
            value or 0))
    end
    log(string.format(
        "verified native Character record: APmax=%d groundBase=%d airBase=%d; %s.",
        ReadByte(ADDRESS.soraMaxAP),
        ReadByte(ADDRESS.maxGroundCombo),
        ReadByte(ADDRESS.maxAirCombo),
        table.concat(details, ", ")))
end

function _OnInit()
    canRun = false
    applied = false
    reportFrames = 0
    pendingReport = false
    waitingLogged = false

    if GAME_ID ~= EXPECTED_GAME_ID or ENGINE_TYPE ~= "BACKEND"
        or ReadLong(ADDRESS.fingerprint) ~= FINGERPRINT then
        log("unsupported game/build; native ability grant disabled.")
        return
    end

    canRun = true
    log("Native Abilities " .. VERSION
        .. " ready: verified Steam Character offsets + persistent grant.")
end

function _OnFrame()
    if not canRun then return end

    local playerPointer = ReadLong(ADDRESS.playerPointer)
    if menuIsOpen() or not playerIsValid(playerPointer) then
        if not waitingLogged then
            log("waiting for gameplay before touching Sora's ability list.")
            waitingLogged = true
        end
        return
    end
    waitingLogged = false

    if not applied then
        if not ensureNativePassives() then canRun = false end
        return
    end

    -- Keep the requested passives equipped if KH1 or the ability menu disables
    -- them by setting their high bit. No duplicate is ever appended.
    if ReadByte(ADDRESS.soraMaxAP) ~= TARGET_MAX_AP then
        applied = false
        pendingReport = false
        return
    end

    for _, passive in ipairs(PASSIVES) do
        local equipped = verifyEquipped(passive)
        if not equipped then
            applied = false
            pendingReport = false
            return
        end
    end

    if pendingReport then
        reportFrames = reportFrames - 1
        if reportFrames <= 0 then
            reportNativeState()
            pendingReport = false
        end
    end
end
