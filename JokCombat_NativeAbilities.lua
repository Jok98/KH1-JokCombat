LUAGUI_NAME = "JokCombat Native Abilities"
LUAGUI_AUTH = "Jok; Critical Mix reference by Xendra"
LUAGUI_DESC = "Keeps JokCombat's Shared movement abilities and native combo passives learned and equipped."

-- JokCombat native ability grant for the current Steam Global build.
--
-- This intentionally follows KH1's two real ability stores instead of routing
-- around native checks. High Jump, Glide and Superglide belong to the four-byte
-- Shared list, while Combo Plus, Air Combo Plus and Combo Master belong to
-- Sora's contiguous 48-byte Character list. Critical Mix's authorized
-- reference distinguishes the same stores. Preserving each list's order
-- matters because entries after the first terminator are not guaranteed to be
-- visited by KH1.
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
-- design: Shared High Jump/Glide/Superglide, four Combo Plus, two Air Combo
-- Plus and one Combo Master. KH1FM has one High Jump entry rather than
-- KH2-style levels. Glide and Superglide remain native records. The combat
-- controller preserves variable-height B for High Jump, reserves a later B
-- edge for Kinetic Step and leaves native airborne Square to Superglide. A
-- pre-v0.5.0 JokCombat build incorrectly placed 0x01 in Sora's personal list;
-- this version first guarantees the Shared copy, then removes only that legacy
-- misplaced entry. Later vanilla rewards are reconciled without touching any
-- unrelated ability.

local VERSION = "v0.6.0"
local EXPECTED_GAME_ID = 0xAF71841E
local FINGERPRINT = 0x7265737563697065 -- "epicures", little endian
local ABILITY_SLOT_COUNT = 48
local SHARED_ABILITY_SLOT_COUNT = 4
local REPORT_DELAY_FRAMES = 30
local TARGET_MAX_AP = 99
local EXPECTED_GROUND_MAX = 7
local EXPECTED_AIR_MAX = 5

local ADDRESS = {
    fingerprint = 0x3B2271,
    playerPointer = 0x2537E48,
    soraMaxAP = 0x2DE9369,
    soraAbilitySlots = 0x2DE93A4,
    -- Steam save block 0x2DE9360 + KH1FM SharedAbilities offset 0x599.
    -- The corresponding authorized Critical Mix EGS address is 0x2DE5F69;
    -- both identify the four movement abilities, not Sora's Character list.
    sharedAbilitySlots = 0x2DE98F9,
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

local SHARED_MOVEMENT = {
    { name = "High Jump", base = 0x01, equipped = 0x01,
        targetCopies = 1 },
    { name = "Glide", base = 0x03, equipped = 0x03,
        targetCopies = 1 },
    { name = "Superglide", base = 0x04, equipped = 0x04,
        targetCopies = 1 },
}
local SHARED_HIGH_JUMP = SHARED_MOVEMENT[1]

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

local function collectSharedAbilitySlots(baseId)
    local slots = {}
    for index = 0, SHARED_ABILITY_SLOT_COUNT - 1 do
        local value = ReadByte(ADDRESS.sharedAbilitySlots + index)
        if value ~= 0 and baseAbilityId(value) == baseId then
            table.insert(slots, { index = index, value = value })
        end
    end
    return slots
end

local function findFirstEmptySharedSlot()
    for index = 0, SHARED_ABILITY_SLOT_COUNT - 1 do
        if ReadByte(ADDRESS.sharedAbilitySlots + index) == 0 then
            return index
        end
    end
    return nil
end

local function restoreSharedAbilityList(snapshot)
    for index = 0, SHARED_ABILITY_SLOT_COUNT - 1 do
        WriteByte(ADDRESS.sharedAbilitySlots + index, snapshot[index + 1])
    end
end

local function removeSharedAbilitySlot(index)
    local snapshot = {}
    for cursor = 0, SHARED_ABILITY_SLOT_COUNT - 1 do
        snapshot[cursor + 1] = ReadByte(
            ADDRESS.sharedAbilitySlots + cursor)
    end

    for cursor = index, SHARED_ABILITY_SLOT_COUNT - 2 do
        WriteByte(ADDRESS.sharedAbilitySlots + cursor,
            snapshot[cursor + 2])
    end
    WriteByte(ADDRESS.sharedAbilitySlots + SHARED_ABILITY_SLOT_COUNT - 1, 0)

    for cursor = index, SHARED_ABILITY_SLOT_COUNT - 1 do
        local expected = cursor < SHARED_ABILITY_SLOT_COUNT - 1
            and snapshot[cursor + 2] or 0
        if ReadByte(ADDRESS.sharedAbilitySlots + cursor) ~= expected then
            restoreSharedAbilityList(snapshot)
            return false, string.format(
                "Shared ability compaction failed at slot %d", cursor)
        end
    end
    return true
end

local function verifySharedAbility(sharedAbility)
    local slots = collectSharedAbilitySlots(sharedAbility.base)
    if #slots ~= sharedAbility.targetCopies then
        return false, slots, string.format(
            "copy count %d/%d", #slots, sharedAbility.targetCopies)
    end
    if slots[1].value ~= sharedAbility.equipped then
        return false, slots, string.format(
            "slot %d has non-canonical value 0x%02X",
            slots[1].index, slots[1].value)
    end
    return true, slots, nil
end

local function reconcileSharedAbility(sharedAbility)
    local changed = false
    local slots = collectSharedAbilitySlots(sharedAbility.base)

    while #slots > sharedAbility.targetCopies do
        local surplus = slots[#slots]
        local ok, errorMessage = removeSharedAbilitySlot(surplus.index)
        if not ok then return false, errorMessage end
        log(string.format(
            "Shared %s surplus removed from slot %d; list compacted.",
            sharedAbility.name, surplus.index))
        changed = true
        slots = collectSharedAbilitySlots(sharedAbility.base)
    end

    if #slots == 0 then
        local index = findFirstEmptySharedSlot()
        if index == nil then
            return false, sharedAbility.name
                .. " missing but Shared ability list is full"
        end
        WriteByte(ADDRESS.sharedAbilitySlots + index,
            sharedAbility.equipped)
        if ReadByte(ADDRESS.sharedAbilitySlots + index)
            ~= sharedAbility.equipped then
            return false, string.format(
                "Shared %s write failed at slot %d",
                sharedAbility.name, index)
        end
        log(string.format(
            "%s learned in native Shared slot %d: 0x%02X.",
            sharedAbility.name, index, sharedAbility.equipped))
        changed = true
        slots = collectSharedAbilitySlots(sharedAbility.base)
    elseif slots[1].value ~= sharedAbility.equipped then
        WriteByte(ADDRESS.sharedAbilitySlots + slots[1].index,
            sharedAbility.equipped)
        if ReadByte(ADDRESS.sharedAbilitySlots + slots[1].index)
            ~= sharedAbility.equipped then
            return false, string.format(
                "Shared %s normalization failed at slot %d",
                sharedAbility.name, slots[1].index)
        end
        log(string.format(
            "%s normalized in Shared slot %d: 0x%02X -> 0x%02X.",
            sharedAbility.name, slots[1].index, slots[1].value,
            sharedAbility.equipped))
        changed = true
    end

    return true, changed
end

local function removeLegacySoraHighJump()
    local changed = false
    local slots = collectAbilitySlots(SHARED_HIGH_JUMP.base)
    while #slots > 0 do
        local misplaced = slots[#slots]
        local ok, errorMessage = removeAbilitySlot(misplaced.index)
        if not ok then return false, errorMessage end
        log(string.format(
            "legacy misplaced High Jump removed from Sora slot %d; "
                .. "Shared record preserved.",
            misplaced.index))
        changed = true
        slots = collectAbilitySlots(SHARED_HIGH_JUMP.base)
    end
    return true, changed
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

    -- Movement abilities belong to the Shared list, not Sora's Character
    -- passives. Guarantee all three native records before removing the
    -- misplaced personal 0x01 written by JokCombat v0.4.0 and earlier.
    for _, sharedAbility in ipairs(SHARED_MOVEMENT) do
        local sharedOk, sharedChangedOrError =
            reconcileSharedAbility(sharedAbility)
        if not sharedOk then
            log("ERROR: " .. sharedChangedOrError .. ".")
            return false
        end
        if sharedChangedOrError then changed = true end
    end

    local migrationOk, migrationChangedOrError =
        removeLegacySoraHighJump()
    if not migrationOk then
        log("ERROR: " .. migrationChangedOrError .. ".")
        return false
    end
    if migrationChangedOrError then changed = true end

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

    for _, sharedAbility in ipairs(SHARED_MOVEMENT) do
        local sharedValid, sharedSlots, sharedError =
            verifySharedAbility(sharedAbility)
        if not sharedValid then
            log(string.format(
                "ERROR: Shared %s failed final verification: %s; "
                    .. "slots=[%s].",
                sharedAbility.name, sharedError,
                describeSlotIndices(sharedSlots)))
            return false
        end
    end
    local misplaced = collectAbilitySlots(SHARED_HIGH_JUMP.base)
    if #misplaced ~= 0 then
        log(string.format(
            "ERROR: %d misplaced High Jump record(s) remain in Sora's list.",
            #misplaced))
        return false
    end

    if changed then
        log("native ability grant complete; changes will persist when KH1 saves.")
    else
        log("Shared movement set and native passive counts already exact "
            .. "and equipped (3 + 4/2/1); no writes.")
    end
    applied = true
    pendingReport = true
    reportFrames = REPORT_DELAY_FRAMES
    return true
end

local function reportNativeState()
    local details = {}
    for _, sharedAbility in ipairs(SHARED_MOVEMENT) do
        local sharedValid, sharedSlots = verifySharedAbility(sharedAbility)
        table.insert(details, string.format(
            "Shared %s=%d/1 %s@[%s]",
            sharedAbility.name,
            #sharedSlots,
            sharedValid and "on" or "off",
            describeSlotIndices(sharedSlots)))
    end
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
        "verified native records: APmax=%d groundMax=%d airMax=%d; %s.",
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
        .. " ready: Shared High Jump/Glide/Superglide + exact native "
        .. "counts 4/2/1 + persistent grant.")
end

function _OnFrame()
    if not canRun then return end

    local playerPointer = ReadLong(ADDRESS.playerPointer)
    local menuOpen = menuIsOpen()
    local playerValid = playerIsValid(playerPointer)
    if menuOpen or not playerValid then
        if not waitingLogged then
            log("waiting for gameplay before touching native ability records: "
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

    for _, sharedAbility in ipairs(SHARED_MOVEMENT) do
        local sharedValid = verifySharedAbility(sharedAbility)
        if not sharedValid then
            applied = false
            pendingReport = false
            return
        end
    end
    if #collectAbilitySlots(SHARED_HIGH_JUMP.base) ~= 0 then
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
