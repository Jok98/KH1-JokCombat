LUAGUI_NAME = "JokCombat Command Menu Probe"
LUAGUI_AUTH = "Jok"
LUAGUI_DESC = "Read-only Steam probe for KH1's native four-row Command Menu."

-- This probe only reads memory. It maps the native Command Menu controller,
-- its four visual rows, and the currently loaded World message table so that
-- JokCombat can later replace the four labels without hijacking vanilla input.

local EXPECTED_GAME_ID = 0xAF71841E
local FINGERPRINT = 0x7265737563697065 -- "epicures", little endian
local VERSION = "v0.1.0"
local SETTLE_FRAMES = 18
local TEXT_RECHECK_FRAMES = 300
local HEARTBEAT_FRAMES = 900

local ADDRESS = {
    fingerprint = 0x3B2271,
    dpadButtons = 0x22C9300,
    rawButtons = 0x22C9301,

    -- Steam Global ports of Critical Mix's currentCommandMenu and
    -- currentCommandMenuSlot globals.
    currentMenu = 0x2852790,
    currentSlot = 0x28527AC,
    lastSlot = 0x28527B0,
    menuVisibility = 0x285280C,

    -- This global points into the live World message-resource owner. On the
    -- validated executable the World text base is owner-0x50 and its byte
    -- length is owner-0x48.
    worldTextOwner = 0x2F11838,
}

local ROWS = {
    { name = "attack", address = 0x2855F60, resource = "com_fra_c" },
    { name = "magic", address = 0x2856020, resource = "com_fra_c" },
    { name = "items", address = 0x28560E0, resource = "com_fra_c" },
    { name = "summon", address = 0x2856E60, resource = "com_fra_d" },
}

-- Detailed diffs are intentionally bounded. The first range contains the
-- menu controller; the remaining ranges cover the native command HUD objects.
local WATCH_RANGES = {
    { name = "controller", address = 0x2852780, size = 0x500, detail = 40 },
    { name = "command-ui", address = 0x2854000, size = 0x1600, detail = 12 },
    { name = "four-rows", address = 0x2855E00, size = 0x1400, detail = 12 },
    { name = "selection", address = 0x2857C00, size = 0x1A00, detail = 12 },
}

local EXPECTED_WORLD_PREFIX = {
    "Attack", "Magic", "Items", "Talk", "Examine", "Summon",
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

local DPAD = {
    { mask = 0x10, name = "UP" },
    { mask = 0x20, name = "RIGHT" },
    { mask = 0x40, name = "DOWN" },
    { mask = 0x80, name = "LEFT" },
}

local canRun = false
local frame = 0
local lastInputRaw = -1
local lastInputDpad = -1
local lastStateKey = nil
local lastStableSnapshots = nil
local pendingStateKey = nil
local pendingFrames = 0
local firstSettledSnapshots = nil
local captureNumber = 0
local lastTextOwner = 0
local lastTextBase = 0
local textWaitingLogged = false

local function u32(value)
    return value & 0xFFFFFFFF
end

local function isPlausiblePointer(value)
    return value ~= nil
        and value >= 0x10000
        and value <= 0x00007FFFFFFFFFFF
end

local function readAsciiRva(address, maximum)
    local chars = {}
    for index = 0, maximum - 1 do
        local value = ReadByte(address + index)
        if value == 0 then break end
        if value < 0x20 or value > 0x7E then return nil end
        chars[#chars + 1] = string.char(value)
    end
    return table.concat(chars)
end

local function readAsciiAbsolute(address, maximum)
    local chars = {}
    for index = 0, maximum - 1 do
        local value = ReadByte(address + index, true)
        if value == 0 then
            return table.concat(chars), address + index + 1
        end
        if value < 0x20 or value > 0x7E then return nil, nil end
        chars[#chars + 1] = string.char(value)
    end
    return nil, nil
end

local function namesFor(value, catalog)
    if value == 0 then return "released" end
    local names = {}
    for _, button in ipairs(catalog) do
        if (value & button.mask) ~= 0 then
            names[#names + 1] = button.name
        end
    end
    if #names == 0 then return "unknown" end
    return table.concat(names, "+")
end

local function menuName(value)
    local names = {
        [0] = "root",
        [1] = "menu-1",
        [2] = "menu-2",
        [3] = "menu-3",
        [4] = "menu-4",
        [5] = "shortcuts",
    }
    return names[value] or "other"
end

local function readMenuState()
    return {
        menu = ReadByte(ADDRESS.currentMenu),
        slot = ReadByte(ADDRESS.currentSlot),
        lastSlot = ReadByte(ADDRESS.lastSlot),
        visibility = u32(ReadInt(ADDRESS.menuVisibility)),
        raw = ReadByte(ADDRESS.rawButtons),
        dpad = ReadByte(ADDRESS.dpadButtons),
    }
end

local function keyFor(state)
    return string.format("%02X:%02X:%02X",
        state.menu, state.slot, state.lastSlot)
end

local function logMenuState(state, reason)
    ConsolePrint(string.format(
        "[JokCombat:cmdprobe:%s] menu=%d(%s) slot=%d last=%d "
        .. "visibility=0x%08X raw=0x%02X dpad=0x%02X",
        reason,
        state.menu,
        menuName(state.menu),
        state.slot,
        state.lastSlot,
        state.visibility,
        state.raw,
        state.dpad))
end

local function validateRows()
    local valid = true
    for _, row in ipairs(ROWS) do
        local actual = readAsciiRva(row.address + 0xA0, 16)
        local matches = actual == row.resource
        ConsolePrint(string.format(
            "[JokCombat:cmdprobe:row] %s=0x%X resource=%s expected=%s %s",
            row.name,
            row.address,
            tostring(actual),
            row.resource,
            matches and "OK" or "MISMATCH"))
        valid = matches and valid
    end
    return valid
end

local function inspectWorldText(forceLog)
    local owner = ReadLong(ADDRESS.worldTextOwner)
    if not isPlausiblePointer(owner) then
        if forceLog or not textWaitingLogged then
            ConsolePrint(
                "[JokCombat:cmdprobe:text] World text owner unavailable; "
                .. "load a playable room and the probe will retry.")
            textWaitingLogged = true
        end
        lastTextOwner = 0
        lastTextBase = 0
        return false
    end

    local textBase = ReadLong(owner - 0x50, true)
    local byteLength = ReadInt(owner - 0x48, true)
    if not isPlausiblePointer(textBase)
        or byteLength <= 0 or byteLength > 0x1000000 then
        if forceLog or owner ~= lastTextOwner or not textWaitingLogged then
            ConsolePrint(string.format(
                "[JokCombat:cmdprobe:text] owner=0x%X has no sane World "
                .. "text table yet (base=0x%X length=%d).",
                owner, textBase, byteLength))
            textWaitingLogged = true
        end
        lastTextOwner = owner
        lastTextBase = 0
        return false
    end

    if not forceLog and owner == lastTextOwner and textBase == lastTextBase then
        return true
    end

    local cursor = textBase
    local names = {}
    local prefixValid = true
    for index, expected in ipairs(EXPECTED_WORLD_PREFIX) do
        local actual, nextAddress = readAsciiAbsolute(cursor, 64)
        names[#names + 1] = actual or "<invalid>"
        if actual ~= expected or nextAddress == nil then
            prefixValid = false
            break
        end
        cursor = nextAddress
    end

    ConsolePrint(string.format(
        "[JokCombat:cmdprobe:text] owner=0x%X base=0x%X length=%d "
        .. "prefix=%s %s",
        owner,
        textBase,
        byteLength,
        table.concat(names, "|"),
        prefixValid and "OK" or "MISMATCH"))

    lastTextOwner = owner
    lastTextBase = textBase
    textWaitingLogged = not prefixValid
    return prefixValid
end

local function takeSnapshots()
    local snapshots = {}
    for rangeIndex, range in ipairs(WATCH_RANGES) do
        local values = {}
        local hash = 0x811C9DC5
        local count = range.size // 4
        for index = 0, count - 1 do
            local value = u32(ReadInt(range.address + index * 4))
            values[index + 1] = value
            hash = u32((hash ~ value) * 0x01000193)
        end
        snapshots[rangeIndex] = {
            values = values,
            hash = hash,
        }
    end
    return snapshots
end

local function logDiffDetails(range, previous, first, second)
    local details = {}
    local changed = 0
    local volatile = 0
    for index = 1, #second.values do
        local unstableNow = first.values[index] ~= second.values[index]
        if unstableNow then volatile = volatile + 1 end

        if previous ~= nil
            and previous.values[index] ~= second.values[index]
            and not unstableNow then
            changed = changed + 1
            if #details < range.detail then
                details[#details + 1] = string.format(
                    "+%03X:%08X>%08X",
                    (index - 1) * 4,
                    previous.values[index],
                    second.values[index])
            end
        end
    end

    ConsolePrint(string.format(
        "[JokCombat:cmdprobe:range] %s RVA=0x%X hash=%08X "
        .. "stableChanges=%d volatileNow=%d",
        range.name,
        range.address,
        second.hash,
        changed,
        volatile))

    local cursor = 1
    while cursor <= #details do
        local group = {}
        for index = cursor, math.min(cursor + 5, #details) do
            group[#group + 1] = details[index]
        end
        ConsolePrint(string.format(
            "[JokCombat:cmdprobe:diff] %s %s",
            range.name,
            table.concat(group, " ")))
        cursor = cursor + 6
    end

    if changed > #details then
        ConsolePrint(string.format(
            "[JokCombat:cmdprobe:diff] %s ... %d more stable change(s)",
            range.name,
            changed - #details))
    end
end

local function finishSettledCapture(state, secondSnapshots)
    captureNumber = captureNumber + 1
    ConsolePrint(string.format(
        "[JokCombat:cmdprobe:capture] #%d menu=%d(%s) slot=%d last=%d",
        captureNumber,
        state.menu,
        menuName(state.menu),
        state.slot,
        state.lastSlot))

    for index, range in ipairs(WATCH_RANGES) do
        local previous = lastStableSnapshots
            and lastStableSnapshots[index] or nil
        logDiffDetails(
            range,
            previous,
            firstSettledSnapshots[index],
            secondSnapshots[index])
    end

    lastStableSnapshots = secondSnapshots
    firstSettledSnapshots = nil
end

local function scheduleCapture(state)
    pendingStateKey = keyFor(state)
    pendingFrames = SETTLE_FRAMES
    firstSettledSnapshots = nil
end

function _OnInit()
    canRun = false
    frame = 0
    lastInputRaw = -1
    lastInputDpad = -1
    lastStateKey = nil
    lastStableSnapshots = nil
    pendingStateKey = nil
    pendingFrames = 0
    firstSettledSnapshots = nil
    captureNumber = 0
    lastTextOwner = 0
    lastTextBase = 0
    textWaitingLogged = false

    if GAME_ID ~= EXPECTED_GAME_ID or ENGINE_TYPE ~= "BACKEND" then
        ConsolePrint(
            "JokCombat Command Menu Probe - wrong game or Lua engine; disabled.")
        return
    end
    if ReadLong(ADDRESS.fingerprint) ~= FINGERPRINT then
        ConsolePrint(
            "JokCombat Command Menu Probe - unsupported executable; disabled.")
        return
    end

    local rowsValid = validateRows()
    inspectWorldText(true)
    if not rowsValid then
        ConsolePrint(
            "JokCombat Command Menu Probe - row signatures failed; "
            .. "deep capture disabled for safety.")
        return
    end

    canRun = true
    local initial = readMenuState()
    lastStateKey = keyFor(initial)
    scheduleCapture(initial)
    logMenuState(initial, "ready")
    ConsolePrint(
        "JokCombat Command Menu Probe " .. VERSION
        .. " initialized (read-only; native four-row mapping).")
end

function _OnFrame()
    if not canRun then return end
    frame = frame + 1

    local state = readMenuState()
    local stateKey = keyFor(state)
    if state.raw ~= lastInputRaw or state.dpad ~= lastInputDpad then
        ConsolePrint(string.format(
            "[JokCombat:cmdprobe:input] raw=0x%02X(%s) dpad=0x%02X(%s) "
            .. "menu=%d slot=%d",
            state.raw,
            namesFor(state.raw, BUTTONS),
            state.dpad,
            namesFor(state.dpad, DPAD),
            state.menu,
            state.slot))
        lastInputRaw = state.raw
        lastInputDpad = state.dpad
    end

    if stateKey ~= lastStateKey then
        logMenuState(state, "transition")
        scheduleCapture(state)
        lastStateKey = stateKey
    end

    if pendingStateKey ~= nil then
        if stateKey ~= pendingStateKey then
            scheduleCapture(state)
        elseif pendingFrames > 0 then
            pendingFrames = pendingFrames - 1
        elseif firstSettledSnapshots == nil then
            firstSettledSnapshots = takeSnapshots()
        else
            local secondSnapshots = takeSnapshots()
            finishSettledCapture(state, secondSnapshots)
            pendingStateKey = nil
        end
    end

    if frame % TEXT_RECHECK_FRAMES == 0 then
        inspectWorldText(false)
    end
    if HEARTBEAT_FRAMES > 0 and frame % HEARTBEAT_FRAMES == 0 then
        logMenuState(state, "heartbeat")
    end
end
