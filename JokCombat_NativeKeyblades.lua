LUAGUI_NAME = "JokCombat Native Keyblades"
LUAGUI_AUTH = "Jok; Critical Mix reference by Xendra"
LUAGUI_DESC = "Unlocks non-Ultima Keyblades plus Donald and Goofy's final weapons."

-- JokCombat native Keyblade grant for the current Steam Global build.
--
-- KH1FM stores equipped weapons separately from the 0x100-byte inventory
-- count array. A unique Keyblade is therefore owned when either Sora has its
-- ID equipped or its inventory count is one. This module preserves that
-- native contract and keeps exactly one total copy of each genuine Keyblade
-- listed below.
--
-- Ultima Weapon (0x64) is intentionally absent from TARGET_WEAPONS. Neither
-- its inventory byte nor Sora's equipped-weapon byte is ever written here, so
-- Ultima remains obtainable exclusively through KH1's normal synthesis path.
-- Dream Sword, Dream Shield, Dream Rod and Wooden Sword are also excluded:
-- they are tutorial/special Sora weapons rather than normal Keyblades.
--
-- The writes are deliberate and persistent after KH1 saves. Scripted rewards,
-- chests, synthesis state and story flags are not changed. When a later native
-- reward grants a second copy of an already-unlocked target, the unique stock
-- count is normalized back to one after the menu/reward transition completes.
-- Save the Queen and Save the King use the same inventory contract. Their
-- equipped bytes come from Donald and Goofy's own 0x74-byte Character records.

local VERSION = "v0.2.0"
local EXPECTED_GAME_ID = 0xAF71841E
local FINGERPRINT = 0x7265737563697065 -- "epicures", little endian
local REPORT_DELAY_FRAMES = 30
local MAX_PLAUSIBLE_WEAPON_COUNT = 9
local ULTIMA_WEAPON_ID = 0x64

local ADDRESS = {
    fingerprint = 0x3B2271,
    playerPointer = 0x2537E48,
    -- Steam save block 0x2DE9360 + Character header 0x04 + Weapon 0x32.
    soraWeapon = 0x2DE9396,
    -- Donald and Goofy are the next two Character records (stride 0x74).
    donaldWeapon = 0x2DE940A,
    goofyWeapon = 0x2DE947E,
    -- Steam save block 0x2DE9360 + KH1FM InventoryCount offset 0x499.
    inventoryCounts = 0x2DE97F9,
    inMenu = 0x232DF80,
    saveMenuOpen = 0x232DF84,
    pauseMenuOpen = 0x2867374,
}

local PLAYER = {
    slotReference = 0x06C,
    animationTime = 0x16C,
}

local TARGET_WEAPONS = {
    { id = 0x51, name = "Kingdom Key", owner = "sora" },
    { id = 0x56, name = "Jungle King", owner = "sora" },
    { id = 0x57, name = "Three Wishes", owner = "sora" },
    { id = 0x58, name = "Fairy Harp", owner = "sora" },
    { id = 0x59, name = "Pumpkinhead", owner = "sora" },
    { id = 0x5A, name = "Crabclaw", owner = "sora" },
    { id = 0x5B, name = "Divine Rose", owner = "sora" },
    { id = 0x5C, name = "Spellbinder", owner = "sora" },
    { id = 0x5D, name = "Olympia", owner = "sora" },
    { id = 0x5E, name = "Lionheart", owner = "sora" },
    { id = 0x5F, name = "Metal Chocobo", owner = "sora" },
    { id = 0x60, name = "Oathkeeper", owner = "sora" },
    { id = 0x61, name = "Oblivion", owner = "sora" },
    { id = 0x62, name = "Lady Luck", owner = "sora" },
    { id = 0x63, name = "Wishing Star", owner = "sora" },
    { id = 0x65, name = "Diamond Dust", owner = "sora" },
    { id = 0x66, name = "One-Winged Angel", owner = "sora" },
    { id = 0x72, name = "Save the Queen", owner = "donald" },
    { id = 0x82, name = "Save the King", owner = "goofy" },
}

local canRun = false
local applied = false
local pendingReport = false
local reportFrames = 0
local waitingReason = nil

local function log(message)
    ConsolePrint("[JokCombat:native-keyblades] " .. message)
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

local function inventoryAddress(itemId)
    return ADDRESS.inventoryCounts + itemId
end

local function isSoraWeaponId(itemId)
    return itemId >= 0x51 and itemId <= 0x66
end

local function isDonaldWeaponId(itemId)
    return itemId == 0 or (itemId >= 0x67 and itemId <= 0x76)
end

local function isGoofyWeaponId(itemId)
    return itemId == 0 or (itemId >= 0x77 and itemId <= 0x86)
end

local function desiredInventoryCount(target, equippedWeapons)
    if target.id == equippedWeapons[target.owner] then return 0 end
    return 1
end

local function validateSaveLayout()
    -- Inventory entry zero is the Empty item and must never carry stock.
    if ReadByte(ADDRESS.inventoryCounts) ~= 0 then
        return false, "inventory Empty sentinel is nonzero"
    end

    local equippedWeapons = {
        sora = ReadByte(ADDRESS.soraWeapon),
        donald = ReadByte(ADDRESS.donaldWeapon),
        goofy = ReadByte(ADDRESS.goofyWeapon),
    }
    if not isSoraWeaponId(equippedWeapons.sora) then
        return false, string.format(
            "Sora weapon byte is not ready (0x%02X)",
            equippedWeapons.sora)
    end
    if not isDonaldWeaponId(equippedWeapons.donald) then
        return false, string.format(
            "Donald weapon byte is implausible (0x%02X)",
            equippedWeapons.donald)
    end
    if not isGoofyWeaponId(equippedWeapons.goofy) then
        return false, string.format(
            "Goofy weapon byte is implausible (0x%02X)",
            equippedWeapons.goofy)
    end

    for _, weapon in ipairs(TARGET_WEAPONS) do
        local count = ReadByte(inventoryAddress(weapon.id))
        if count > MAX_PLAUSIBLE_WEAPON_COUNT then
            return false, string.format(
                "%s stock is implausible (%d)", weapon.name, count)
        end
    end

    local ultimaCount = ReadByte(inventoryAddress(ULTIMA_WEAPON_ID))
    if ultimaCount > MAX_PLAUSIBLE_WEAPON_COUNT then
        return false, string.format(
            "Ultima Weapon stock is implausible (%d)", ultimaCount)
    end

    return true, equippedWeapons
end

local function restoreTargetSnapshot(snapshot)
    for index, weapon in ipairs(TARGET_WEAPONS) do
        if snapshot[index] ~= nil then
            WriteByte(inventoryAddress(weapon.id), snapshot[index])
        end
    end
end

local function verifyKeybladeInventory()
    local layoutValid, equippedOrError = validateSaveLayout()
    if not layoutValid then return false, equippedOrError end

    local equippedWeapons = equippedOrError
    for _, weapon in ipairs(TARGET_WEAPONS) do
        local expected = desiredInventoryCount(
            weapon, equippedWeapons)
        local observed = ReadByte(inventoryAddress(weapon.id))
        if observed ~= expected then
            return false, string.format(
                "%s expected stock %d, observed %d",
                weapon.name, expected, observed)
        end
    end

    return true, equippedWeapons
end

local function reconcileKeyblades()
    local layoutValid, equippedOrError = validateSaveLayout()
    if not layoutValid then return false, equippedOrError end

    local equippedWeapons = equippedOrError
    local ultimaBefore = ReadByte(inventoryAddress(ULTIMA_WEAPON_ID))
    local snapshot = {}
    local changedNames = {}

    for index, weapon in ipairs(TARGET_WEAPONS) do
        local address = inventoryAddress(weapon.id)
        local previous = ReadByte(address)
        local expected = desiredInventoryCount(
            weapon, equippedWeapons)
        snapshot[index] = previous

        if previous ~= expected then
            WriteByte(address, expected)
            if ReadByte(address) ~= expected then
                restoreTargetSnapshot(snapshot)
                return false, string.format(
                    "%s stock write failed: %d -> %d",
                    weapon.name, previous, expected)
            end
            table.insert(changedNames, weapon.name)
        end
    end

    -- This assertion guards the explicit design boundary: Ultima is observed
    -- for diagnostics only and is never part of a write loop.
    if ReadByte(inventoryAddress(ULTIMA_WEAPON_ID)) ~= ultimaBefore then
        restoreTargetSnapshot(snapshot)
        return false, "Ultima Weapon changed during reconciliation"
    end

    local verified, verifiedOrError = verifyKeybladeInventory()
    if not verified then
        restoreTargetSnapshot(snapshot)
        return false, "final verification failed: " .. verifiedOrError
    end

    if #changedNames > 0 then
        log(string.format(
            "native grant complete for %d weapon stock record(s): %s. "
                .. "Changes will persist when KH1 saves.",
            #changedNames, table.concat(changedNames, ", ")))
    else
        log("all 17 non-Ultima Keyblades plus Save the Queen/King "
            .. "already owned exactly once; no writes.")
    end

    applied = true
    pendingReport = true
    reportFrames = REPORT_DELAY_FRAMES
    return true
end

local function reportNativeState()
    local verified, equippedOrError = verifyKeybladeInventory()
    if not verified then
        log("ERROR: post-grant verification failed: "
            .. equippedOrError .. ".")
        applied = false
        return
    end

    local equippedWeapons = equippedOrError
    local ultimaCount = ReadByte(inventoryAddress(ULTIMA_WEAPON_ID))
    log(string.format(
        "verified 17/17 native Keyblades + Save the Queen/King; "
            .. "equipped=%02X/%02X/%02X; "
            .. "Ultima Weapon untouched (stock=%d%s).",
        equippedWeapons.sora,
        equippedWeapons.donald,
        equippedWeapons.goofy,
        ultimaCount,
        equippedWeapons.sora == ULTIMA_WEAPON_ID and ", equipped" or ""))
end

function _OnInit()
    canRun = false
    applied = false
    pendingReport = false
    reportFrames = 0
    waitingReason = nil

    if GAME_ID ~= EXPECTED_GAME_ID or ENGINE_TYPE ~= "BACKEND"
        or ReadLong(ADDRESS.fingerprint) ~= FINGERPRINT then
        log("unsupported game/build; native Keyblade grant disabled.")
        return
    end

    canRun = true
    log("Native Keyblades " .. VERSION
        .. " ready: 17 genuine Keyblades + Save the Queen/King; "
        .. "Ultima Weapon remains native.")
end

function _OnFrame()
    if not canRun then return end

    local reason = nil
    if menuIsOpen() then
        reason = "menu open"
    else
        local playerPointer = ReadLong(ADDRESS.playerPointer)
        if not playerIsValid(playerPointer) then
            reason = "invalid player object"
        else
            local layoutValid, layoutError = validateSaveLayout()
            if not layoutValid then reason = layoutError end
        end
    end

    if reason ~= nil then
        if waitingReason ~= reason then
            log("waiting before touching native Keyblade records: "
                .. reason .. ".")
            waitingReason = reason
        end
        return
    end
    waitingReason = nil

    if not applied then
        local reconciled, errorMessage = reconcileKeyblades()
        if not reconciled then
            log("ERROR: " .. errorMessage .. "; writes disabled.")
            canRun = false
        end
        return
    end

    -- Equipping a different weapon or receiving a later vanilla duplicate
    -- changes the desired stock pattern. Reconcile only after KH1 has closed
    -- its menu and published a stable gameplay record.
    local verified = verifyKeybladeInventory()
    if not verified then
        applied = false
        pendingReport = false
        return
    end

    if pendingReport then
        reportFrames = reportFrames - 1
        if reportFrames <= 0 then
            reportNativeState()
            pendingReport = false
        end
    end
end
