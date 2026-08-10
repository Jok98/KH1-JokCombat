LUAGUI_NAME = "JokCombat Native Abilities"
LUAGUI_AUTH = "Jok; Critical Mix reference by Xendra"
LUAGUI_DESC = "Keeps JokCombat's native combo passives at vanilla-max counts."

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
-- writes. Once the player saves, the equipped abilities become part of that
-- save. JokCombat keeps the exact vanilla maxima requested by the combat
-- design: four Combo Plus, two Air Combo Plus and one Combo Master. If later
-- vanilla rewards append a surplus copy, it is removed and the contiguous
-- ability list is compacted before gameplay continues.

local VERSION = "v0.3.0"
local EXPECTED_GAME_ID = 0xAF71841E
local FINGERPRINT = 0x7265737563697065 -- "epicures", little endian
local ABILITY_SLOT_COUNT = 48
local REPORT_DELAY_FRAMES = 30
local TARGET_MAX_AP = 99
local EXPECTED_GROUND_MAX = 7
local EXPECTED_AIR_MAX = 5

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
        unequipped = 0x86, targetCopies = 4 },
    { name = "Air Combo Plus", base = 0x07, equipped = 0x07,
        unequipped = 0x87, targetCopies = 2 },
    { name = "Combo Master", base = 0x41, equipped = 0x41,
        unequipped = 0xC1, targetCopies = 1 },
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

local function collectAbilitySlots(baseId)
    local slots = {}
    for index = 0, ABILITY_SLOT_COUNT - 1 do
        local value = ReadByte(ADDRESS.soraAbilitySlots + index)
        if value ~= 0 and baseAbilityId(value) == baseId then
            table.insert(slots, { index = index, value = value })
        end
    end
    return slots
end

local function findFirstEmptySlot()
    for index = 0, ABILITY_SLOT_COUNT - 1 do
        if ReadByte(ADDRESS.soraAbilitySlots + index) == 0 then
            return index
        end
    end
    return nil
end

local function restoreAbilityList(snapshot)
    for index = 0, ABILITY_SLOT_COUNT - 1 do
        WriteByte(ADDRESS.soraAbilitySlots + index, snapshot[index + 1])
    end
end

local function removeAbilitySlot(index)
    local snapshot = {}
    for cursor = 0, ABILITY_SLOT_COUNT - 1 do
        snapshot[cursor + 1] = ReadByte(
            ADDRESS.soraAbilitySlots + cursor)
    end

    for cursor = index, ABILITY_SLOT_COUNT - 2 do
        WriteByte(ADDRESS.soraAbilitySlots + cursor, snapshot[cursor + 2])
    end
    WriteByte(ADDRESS.soraAbilitySlots + ABILITY_SLOT_COUNT - 1, 0)

    for cursor = index, ABILITY_SLOT_COUNT - 1 do
        local expected = cursor < ABILITY_SLOT_COUNT - 1
            and snapshot[cursor + 2] or 0
        if ReadByte(ADDRESS.soraAbilitySlots + cursor) ~= expected then
            restoreAbilityList(snapshot)
            return false, string.format(
                "ability-list compaction failed at slot %d", cursor)
        end
    end
    return true
end

local function verifyPassive(passive)
    local slots = collectAbilitySlots(passive.base)
    if #slots ~= passive.targetCopies then
        return false, slots, string.format(
            "copy count %d/%d", #slots, passive.targetCopies)
    end
    for _, slot in ipairs(slots) do
        if (slot.value & 0x80) ~= 0 then
            return false, slots, string.format(
                "slot %d is disabled (0x%02X)", slot.index, slot.value)
        end
    end
    return true, slots, nil
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

local function reconcilePassive(passive)
    local changed = false
    local slots = collectAbilitySlots(passive.base)

    -- A later vanilla level/reward may append a copy even though JokCombat
    -- already granted the natural maximum at the start. Remove newest copies
    -- first and compact the 48-byte list so its first 0x00 remains a terminator.
    while #slots > passive.targetCopies do
        local surplus = slots[#slots]
        local ok, errorMessage = removeAbilitySlot(surplus.index)
        if not ok then
            return false, errorMessage
        end
        log(string.format(
            "%s surplus copy removed from slot %d; list compacted to %d/%d.",
            passive.name, surplus.index, #slots - 1,
            passive.targetCopies))
        changed = true
        slots = collectAbilitySlots(passive.base)
    end

    for _, slot in ipairs(slots) do
        if (slot.value & 0x80) ~= 0 then
            WriteByte(ADDRESS.soraAbilitySlots + slot.index,
                passive.equipped)
            if ReadByte(ADDRESS.soraAbilitySlots + slot.index)
                ~= passive.equipped then
                return false, string.format(
                    "%s could not be equipped at slot %d",
                    passive.name, slot.index)
            end
            log(string.format(
                "%s copy equipped at slot %d: 0x%02X -> 0x%02X.",
                passive.name, slot.index, slot.value,
                passive.equipped))
            changed = true
        end
    end

    while #slots < passive.targetCopies do
        local index = findFirstEmptySlot()
        if index == nil then
            return false, string.format(
                "%s could not reach %d copies: ability list full",
                passive.name, passive.targetCopies)
        end
        WriteByte(ADDRESS.soraAbilitySlots + index, passive.equipped)
        if ReadByte(ADDRESS.soraAbilitySlots + index)
            ~= passive.equipped then
            return false, string.format(
                "%s copy write failed at slot %d", passive.name, index)
        end
        log(string.format(
            "%s copy %d/%d learned and equipped at slot %d: 0x%02X.",
            passive.name, #slots + 1, passive.targetCopies,
            index, passive.equipped))
        changed = true
        slots = collectAbilitySlots(passive.base)
    end

    return true, changed
end

local function describeSlotIndices(slots)
    local indices = {}
    for _, slot in ipairs(slots) do
        table.insert(indices, tostring(slot.index))
    end
    return table.concat(indices, ",")
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
        local ok, passiveChangedOrError = reconcilePassive(passive)
        if not ok then
            log("ERROR: " .. passiveChangedOrError .. ".")
            return false
        end
        if passiveChangedOrError then changed = true end
    end

    for _, passive in ipairs(PASSIVES) do
        local valid, slots, errorMessage = verifyPassive(passive)
        if not valid then
            log(string.format(
                "ERROR: %s failed final verification: %s; slots=[%s].",
                passive.name, errorMessage,
                describeSlotIndices(slots)))
            return false
        end
    end

    if changed then
        log("native passive grant complete; changes will persist when KH1 saves.")
    else
        log("native passive counts already exact and equipped (4/2/1); no writes.")
    end
    applied = true
    pendingReport = true
    reportFrames = REPORT_DELAY_FRAMES
    return true
end

local function reportNativeState()
    local details = {}
    for _, passive in ipairs(PASSIVES) do
        local valid, slots = verifyPassive(passive)
        table.insert(details, string.format(
            "%s=%d/%d %s@[%s]",
            passive.name,
            #slots,
            passive.targetCopies,
            valid and "on" or "off",
            describeSlotIndices(slots)))
    end
    local groundMax = ReadByte(ADDRESS.maxGroundCombo)
    local airMax = ReadByte(ADDRESS.maxAirCombo)
    log(string.format(
        "verified native Character record: APmax=%d groundMax=%d airMax=%d; %s.",
        ReadByte(ADDRESS.soraMaxAP),
        groundMax,
        airMax,
        table.concat(details, ", ")))
    if groundMax ~= EXPECTED_GROUND_MAX
        or airMax ~= EXPECTED_AIR_MAX then
        log(string.format(
            "WARNING: expected native combo maxima %d/%d, observed %d/%d; "
            .. "capture the full X string before enabling Triangle branches.",
            EXPECTED_GROUND_MAX, EXPECTED_AIR_MAX,
            groundMax, airMax))
    end
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
        .. " ready: exact native counts 4/2/1 + persistent grant.")
end

function _OnFrame()
    if not canRun then return end

    local playerPointer = ReadLong(ADDRESS.playerPointer)
    local menuOpen = menuIsOpen()
    local playerValid = playerIsValid(playerPointer)
    if menuOpen or not playerValid then
        if not waitingLogged then
            log("waiting for gameplay before touching Sora's ability list: "
                .. (menuOpen and "menu open" or "invalid player object")
                .. ".")
            waitingLogged = true
        end
        return
    end
    waitingLogged = false

    if not applied then
        if not ensureNativePassives() then canRun = false end
        return
    end

    -- Keep the requested exact counts equipped. Natural rewards may append a
    -- surplus copy later; the next gameplay frame reconciles and compacts it.
    if ReadByte(ADDRESS.soraMaxAP) ~= TARGET_MAX_AP then
        applied = false
        pendingReport = false
        return
    end

    for _, passive in ipairs(PASSIVES) do
        local valid = verifyPassive(passive)
        if not valid then
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
