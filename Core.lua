local ADDON_NAME = "GearSnapshot"

local db
local ui = {}

local SLOTS = {
    { id = 1,  name = "Head" },
    { id = 2,  name = "Neck" },
    { id = 3,  name = "Shoulder" },
    { id = 5,  name = "Chest" },
    { id = 6,  name = "Waist" },
    { id = 7,  name = "Legs" },
    { id = 8,  name = "Feet" },
    { id = 9,  name = "Wrist" },
    { id = 10, name = "Hands" },
    { id = 11, name = "Ring 1" },
    { id = 12, name = "Ring 2" },
    { id = 13, name = "Trinket 1" },
    { id = 14, name = "Trinket 2" },
    { id = 15, name = "Back" },
    { id = 16, name = "Main Hand" },
    { id = 17, name = "Off Hand" },
}

local STATS = {
    { id = 7,  name = "Stamina" },
    { id = 36, name = "Haste" },
    { id = 32, name = "Crit" },
    { id = 49, name = "Mastery" },
    { id = 40, name = "Versatility" },
}

local Refresh
local CreateUI

local function Now()
    return GetServerTime()
end

local function Message(text)
    print("|cff88ccffGearSnapshot:|r " .. text)
end

local function Trim(text)
    return strtrim(text or "")
end

local function CharacterKey()
    return (UnitName("player") or "Unknown") .. "-" .. (GetRealmName() or "Unknown")
end

local function FormatDate(timestamp)
    return date("%m/%d/%y %H:%M", timestamp or Now())
end

local function GetAverageIlvl()
    local total, count = 0, 0
    for _, slot in ipairs(SLOTS) do
        local link = GetInventoryItemLink("player", slot.id)
        if link then
            local _, _, _, ilvl = GetItemInfo(link)
            if ilvl and ilvl > 0 then
                total = total + ilvl
                count = count + 1
            end
        end
    end
    if count == 0 then return 0 end
    return math.floor((total / count) + 0.5)
end

local function CaptureGear()
    local gear = {}
    for _, slot in ipairs(SLOTS) do
        local link = GetInventoryItemLink("player", slot.id)
        if link then
            local _, _, _, ilvl, _, _, _, _, _, _, _, _, _, _, _, _, _ = GetItemInfo(link)
            gear[slot.id] = {
                name = slot.name,
                link = link,
                ilvl = ilvl or 0,
            }
        end
    end
    return gear
end

local function CaptureStats()
    local stats = {}
    for _, stat in ipairs(STATS) do
        local base, posBuff, negBuff = UnitStat("player", stat.id)
        if base then
            stats[stat.id] = {
                name = stat.name,
                value = base + (posBuff or 0) + (negBuff or 0),
            }
        else
            -- For secondary stats use GetCombatRating
            local rating = GetCombatRating and GetCombatRating(stat.id) or 0
            stats[stat.id] = {
                name = stat.name,
                value = rating,
            }
        end
    end
    return stats
end

local function TakeSnapshot(label)
    local key = CharacterKey()
    db.characters[key] = db.characters[key] or { snapshots = {} }

    local _, classFile = UnitClass("player")
    local specIndex = GetSpecialization and GetSpecialization()
    local _, specName = specIndex and GetSpecializationInfo and GetSpecializationInfo(specIndex) or nil, "Unknown"

    local snapshot = {
        timestamp = Now(),
        label = Trim(label) ~= "" and Trim(label) or FormatDate(Now()),
        ilvl = GetAverageIlvl(),
        gear = CaptureGear(),
        stats = CaptureStats(),
        level = UnitLevel("player") or 0,
        class = classFile,
        spec = specName or "Unknown",
        zone = GetZoneText() or "Unknown",
    }

    table.insert(db.characters[key].snapshots, 1, snapshot)

    -- Keep max 20 snapshots per character
    while #db.characters[key].snapshots > 20 do
        table.remove(db.characters[key].snapshots)
    end

    db.characters[key].name = UnitName("player") or "Unknown"
    db.characters[key].realm = GetRealmName() or "Unknown"
    db.characters[key].class = classFile

    Message("Snapshot saved — " .. snapshot.ilvl .. " ilvl")
    Refresh()
    return snapshot
end

local function EnsureDB()
    GearSnapshotDB = GearSnapshotDB or {}
    db = GearSnapshotDB
    db.characters = db.characters or {}
    db.position = db.position or { point = "CENTER", x = 0, y = 0 }
    db.activeTab = db.activeTab or "snapshots"
    db.selectedChar = db.selectedChar or nil
    db.compareA = db.compareA or nil
    db.compareB = db.compareB or nil
end

-- UI helpers
local function ClearRows()
    ui.rows = ui.rows or {}
    for _, row in ipairs(ui.rows) do row:Hide() end
end

local function EnsureRow(index)
    ui.rows = ui.rows or {}
    local row = ui.rows[index]
    if not row then
        row = CreateFrame("Button", nil, ui.content)
        row:SetHeight(44)
        row.left = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        row.left:SetPoint("LEFT", 8, 6)
        row.left:SetPoint("RIGHT", -160, 6)
        row.left:SetJustifyH("LEFT")
        row.right = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.right:SetPoint("RIGHT", -8, 6)
        row.right:SetJustifyH("RIGHT")
        row.sub = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        row.sub:SetPoint("LEFT", 8, -10)
        row.sub:SetPoint("RIGHT", -8, -10)
        row.sub:SetJustifyH("LEFT")
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints()
        row.bg:SetColorTexture(1, 1, 1, index % 2 == 0 and 0.03 or 0)
        ui.rows[index] = row
    end
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", 0, -((index - 1) * 44))
    row:SetPoint("RIGHT", 0, 0)
    row:SetScript("OnClick", nil)
    row:SetScript("OnEnter", nil)
    row:SetScript("OnLeave", nil)
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self) self.bg:SetColorTexture(1, 1, 1, 0.1) end)
    row:SetScript("OnLeave", function(self) self.bg:SetColorTexture(1, 1, 1, index % 2 == 0 and 0.03 or 0) end)
    row:Show()
    return row
end

local function IlvlColor(ilvl)
    if ilvl >= 600 then return 1, 0.5, 0 end
    if ilvl >= 550 then return 0.6, 0.4, 1 end
    if ilvl >= 500 then return 0.1, 0.4, 0.9 end
    if ilvl >= 450 then return 0.1, 0.8, 0.1 end
    return 1, 1, 1
end

local function SortedCharKeys()
    local currentKey = CharacterKey()
    local keys = {}
    for key in pairs(db.characters) do
        keys[#keys + 1] = key
    end
    table.sort(keys, function(a, b)
        if a == currentKey then return true end
        if b == currentKey then return false end
        return a < b
    end)
    return keys
end

local function RenderSnapshots()
    local key = db.selectedChar or CharacterKey()
    local char = db.characters[key]

    if not char or not char.snapshots or #char.snapshots == 0 then
        local row = EnsureRow(1)
        row.left:SetText("No snapshots yet.")
        row.right:SetText("")
        row.sub:SetText("Use /gs snap or click Take Snapshot.")
        return 2
    end

    for index, snap in ipairs(char.snapshots) do
        local row = EnsureRow(index)
        local r, g, b = IlvlColor(snap.ilvl)
        row.left:SetText(snap.label)
        row.right:SetText(snap.ilvl .. " ilvl")
        row.right:SetTextColor(r, g, b)
        row.sub:SetText(snap.spec .. "  |  Level " .. snap.level .. "  |  " .. snap.zone)
        row:SetScript("OnClick", function()
            db.compareA = { key = key, index = index }
            Message("Snapshot A set to: " .. snap.label .. " — click another to compare.")
            if db.compareA and db.compareB and db.compareA.key == db.compareB.key and db.compareA.index ~= db.compareB.index then
                db.activeTab = "compare"
            end
            Refresh()
        end)
    end

    return #char.snapshots + 1
end

local function RenderCharacters()
    local keys = SortedCharKeys()
    if #keys == 0 then
        local row = EnsureRow(1)
        row.left:SetText("No characters recorded yet.")
        row.right:SetText("")
        row.sub:SetText("Take a snapshot to get started.")
        return 2
    end

    for index, key in ipairs(keys) do
        local char = db.characters[key]
        local snapCount = char.snapshots and #char.snapshots or 0
        local latest = char.snapshots and char.snapshots[1]
        local row = EnsureRow(index)
        local r, g, b = latest and IlvlColor(latest.ilvl) or 1, 1, 1

        row.left:SetText((char.name or key) .. " — " .. (char.realm or ""))
        row.right:SetText(latest and (latest.ilvl .. " ilvl") or "No data")
        row.right:SetTextColor(r, g, b)
        row.sub:SetText(snapCount .. " snapshot" .. (snapCount == 1 and "" or "s") .. (latest and ("  |  Last: " .. FormatDate(latest.timestamp)) or ""))
        row:SetScript("OnClick", function()
            db.selectedChar = key
            db.activeTab = "snapshots"
            Refresh()
        end)
    end

    return #keys + 1
end

local function RenderCompare()
    if not db.compareA or not db.compareB then
        local row = EnsureRow(1)
        row.left:SetText("Select two snapshots to compare.")
        row.right:SetText("")
        row.sub:SetText("Click a snapshot to set A, then click another to set B.")
        return 2
    end

    local charA = db.characters[db.compareA.key]
    local charB = db.characters[db.compareB.key]
    if not charA or not charB then return 2 end

    local snapA = charA.snapshots[db.compareA.index]
    local snapB = charB.snapshots[db.compareB.index]
    if not snapA or not snapB then return 2 end

    local rowIndex = 1

    -- Header
    local header = EnsureRow(rowIndex)
    header.left:SetText("Stat")
    header.right:SetText(snapA.label .. "  →  " .. snapB.label)
    header.right:SetTextColor(1, 0.82, 0.1)
    header.sub:SetText(FormatDate(snapA.timestamp) .. "  →  " .. FormatDate(snapB.timestamp))
    rowIndex = rowIndex + 1

    -- ilvl diff
    local ilvlRow = EnsureRow(rowIndex)
    local diff = snapB.ilvl - snapA.ilvl
    local diffText = diff > 0 and ("|cff44ff44+" .. diff .. "|r") or diff < 0 and ("|cffff4444" .. diff .. "|r") or "|cffaaaaaa0|r"
    ilvlRow.left:SetText("Item Level")
    ilvlRow.right:SetText(snapA.ilvl .. "  →  " .. snapB.ilvl .. "  (" .. diffText .. ")")
    ilvlRow.right:SetTextColor(1, 1, 1)
    ilvlRow.sub:SetText("Average equipped ilvl")
    rowIndex = rowIndex + 1

    -- Stat diffs
    for _, stat in ipairs(STATS) do
        local valA = snapA.stats and snapA.stats[stat.id] and snapA.stats[stat.id].value or 0
        local valB = snapB.stats and snapB.stats[stat.id] and snapB.stats[stat.id].value or 0
        local statDiff = valB - valA
        local statDiffText = statDiff > 0 and ("|cff44ff44+" .. statDiff .. "|r") or statDiff < 0 and ("|cffff4444" .. statDiff .. "|r") or "|cffaaaaaa0|r"
        local row = EnsureRow(rowIndex)
        row.left:SetText(stat.name)
        row.right:SetText(valA .. "  →  " .. valB .. "  (" .. statDiffText .. ")")
        row.right:SetTextColor(1, 1, 1)
        row.sub:SetText("")
        rowIndex = rowIndex + 1
    end

    return rowIndex
end

local function SetTab(tab)
    db.activeTab = tab
    Refresh()
end

local function UpdateTabs()
    if not ui.tabs then return end
    for tab, button in pairs(ui.tabs) do
        button:SetButtonState(db.activeTab == tab and "PUSHED" or "NORMAL", db.activeTab == tab)
    end
end

Refresh = function()
    if not ui.frame or not ui.frame:IsShown() then return end
    ClearRows()
    UpdateTabs()

    local rowIndex
    if db.activeTab == "characters" then
        rowIndex = RenderCharacters()
    elseif db.activeTab == "compare" then
        rowIndex = RenderCompare()
    else
        rowIndex = RenderSnapshots()
    end

    ui.content:SetHeight(math.max((rowIndex - 1) * 44, ui.frame.scroll:GetHeight()))

    -- Update summary
    local key = db.selectedChar or CharacterKey()
    local char = db.characters[key]
    local latest = char and char.snapshots and char.snapshots[1]
    if latest then
        ui.frame.summary:SetText((char.name or key) .. "  —  " .. latest.ilvl .. " ilvl  —  " .. latest.spec)
    else
        ui.frame.summary:SetText("No snapshot taken yet.")
    end
end

CreateUI = function()
    local frame = CreateFrame("Frame", "GearSnapshotFrame", UIParent, "BackdropTemplate")
    frame:SetSize(580, 500)
    frame:SetPoint(db.position.point, UIParent, db.position.point, db.position.x, db.position.y)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetClampedToScreen(true)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 10, right = 10, top = 10, bottom = 10 },
    })
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, _, x, y = self:GetPoint(1)
        db.position.point = point
        db.position.x = x
        db.position.y = y
    end)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOPLEFT", 18, -16)
    frame.title:SetText("|cff88ccffGear|rSnapshot")

    frame.close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    frame.close:SetPoint("TOPRIGHT", -8, -8)

    -- Tabs
    ui.tabs = {}
    local tabDefs = {
        { "snapshots",   "Snapshots" },
        { "characters",  "Characters" },
        { "compare",     "Compare" },
    }
    local prev
    for _, tab in ipairs(tabDefs) do
        local btn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        btn:SetSize(110, 22)
        if prev then
            btn:SetPoint("LEFT", prev, "RIGHT", 5, 0)
        else
            btn:SetPoint("TOPLEFT", 18, -52)
        end
        btn:SetText(tab[2])
        btn:SetScript("OnClick", function() SetTab(tab[1]) end)
        ui.tabs[tab[1]] = btn
        prev = btn
    end

    frame.summary = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.summary:SetPoint("TOPLEFT", 18, -82)
    frame.summary:SetPoint("RIGHT", -18, -82)
    frame.summary:SetJustifyH("LEFT")

    frame.scroll = CreateFrame("ScrollFrame", "GearSnapshotScrollFrame", frame, "UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", 14, -104)
    frame.scroll:SetPoint("BOTTOMRIGHT", -32, 52)

    ui.content = CreateFrame("Frame", nil, frame.scroll)
    ui.content:SetSize(520, 300)
    frame.scroll:SetScrollChild(ui.content)
    frame.scroll:SetScript("OnSizeChanged", function(_, w, h)
        ui.content:SetWidth(w)
        ui.content:SetHeight(math.max(ui.content:GetHeight(), h))
    end)

    -- Snap button
    frame.snapBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.snapBtn:SetSize(130, 26)
    frame.snapBtn:SetPoint("BOTTOMLEFT", 18, 16)
    frame.snapBtn:SetText("Take Snapshot")
    frame.snapBtn:SetScript("OnClick", function()
        TakeSnapshot("")
        db.activeTab = "snapshots"
        db.selectedChar = CharacterKey()
        Refresh()
    end)

    -- Compare B button
    frame.compareBBtn = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.compareBBtn:SetSize(130, 26)
    frame.compareBBtn:SetPoint("LEFT", frame.snapBtn, "RIGHT", 8, 0)
    frame.compareBBtn:SetText("Set Compare B")
    frame.compareBBtn:SetScript("OnClick", function()
        if db.compareA then
            -- Set B to the currently hovered/selected snapshot
            local key = db.selectedChar or CharacterKey()
            local char = db.characters[key]
            if char and char.snapshots and #char.snapshots > 1 then
                db.compareB = { key = key, index = 2 }
                db.activeTab = "compare"
                Refresh()
                Message("Compare B set. Switch to Compare tab.")
            else
                Message("Need at least 2 snapshots to compare.")
            end
        else
            Message("Click a snapshot first to set Compare A.")
        end
    end)

    ui.frame = frame
    frame:Hide()
end

local function ToggleUI()
    if not ui.frame then CreateUI() end
    if ui.frame:IsShown() then
        ui.frame:Hide()
    else
        db.selectedChar = db.selectedChar or CharacterKey()
        Refresh()
        ui.frame:Show()
    end
end

local function PrintHelp()
    Message("/gs — Toggle the window.")
    Message("/gs snap — Take a snapshot of current gear.")
    Message("/gs snap My Label — Take a labeled snapshot.")
end

SLASH_GEARSNAPSHOT1 = "/gs"
SLASH_GEARSNAPSHOT2 = "/gearsnapshot"
SlashCmdList.GEARSNAPSHOT = function(message)
    message = Trim(message)
    local lower = string.lower(message)

    if lower == "help" then
        PrintHelp()
    elseif lower == "snap" or string.sub(lower, 1, 5) == "snap " then
        local label = string.sub(message, 6)
        TakeSnapshot(label)
        db.selectedChar = CharacterKey()
        db.activeTab = "snapshots"
    else
        ToggleUI()
    end
end

EventUtil.ContinueOnAddOnLoaded(ADDON_NAME, function()
    EnsureDB()
    -- Auto snapshot on login if no snapshot today
    C_Timer.After(2, function()
        local key = CharacterKey()
        local char = db.characters[key]
        local latest = char and char.snapshots and char.snapshots[1]
        local today = date("%Y-%m-%d", Now())
        local lastDate = latest and date("%Y-%m-%d", latest.timestamp) or ""
        if lastDate ~= today then
            TakeSnapshot("Login " .. date("%m/%d", Now()))
        end
    end)
end)

EventRegistry:RegisterCallback("PLAYER_ENTERING_WORLD", function()
    if not db then EnsureDB() end
end, {})

-- Armada Addons hub registration
C_Timer.After(0, function()
    if ArmadaAddons and ArmadaAddons.Register then
        ArmadaAddons.Register({
            name    = "GearSnapshot",
            version = "1.0.0",
            desc    = "Track gear and ilvl progression over time across all alts.",
            color   = { 0.53, 0.8, 1 },
            open    = function()
                ToggleUI()
            end,
        })
    end
end)
