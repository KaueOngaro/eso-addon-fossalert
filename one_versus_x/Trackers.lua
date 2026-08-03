-- Trackers: vigia ate 5 buffs/debuffs customizados (por nome, nao ID) no
-- alvo mirado, e mostra uma etiqueta empilhada pra cada um que estiver ativo.
-- Independente do Squishy Detector -- so precisa do reticulo.

one_versus_x = one_versus_x or {}
one_versus_x.Trackers = one_versus_x.Trackers or {}
local M = one_versus_x.Trackers

local ADDON    = "one_versus_x"
local EVENT_NS = "one_versus_x_Trackers"

local SLOT_COUNT  = 5
local ROW_HEIGHT  = 22
local WIDTH       = 220
local POLL_MS     = 1000 -- buffs no alvo podem mudar sem voce trocar de mira

-- =========================================================

M.defaults = {
    trackerEnabled = false,
    customTrackers = { "Minor Mangle", "", "", "", "" },
    trackerX       = nil,
    trackerY       = nil,
}

local sv, L, Msg
local unlocked = false
local token    = 0 -- invalida callbacks de refresh obsoletos
local trackerTLW, trackerBackdrop
local trackerLabels = {} -- ate SLOT_COUNT linhas, empilhadas

-- ---------------------------------------------------------
-- helpers
-- ---------------------------------------------------------

local function NormalizeName(name)
    return name and zo_strformat("<<1>>", name) or nil
end

local function TargetHasBuffNamed(unitTag, buffName)
    if not DoesUnitExist(unitTag) then return false end
    local wanted = NormalizeName(buffName):lower()
    for i = 1, GetNumBuffs(unitTag) do
        local n = GetUnitBuffInfo(unitTag, i)
        if n and NormalizeName(n):lower() == wanted then
            return true
        end
    end
    return false
end

-- lista, na ordem dos slots, os nomes configurados que estao ativos
-- no alvo mirado agora (slots vazios ou sem match ficam de fora)
local function GetActiveTrackerTexts()
    local texts = {}
    if not DoesUnitExist("reticleover") then return texts end
    for i = 1, SLOT_COUNT do
        local name = sv.customTrackers[i]
        if name and name ~= "" and TargetHasBuffNamed("reticleover", name) then
            table.insert(texts, name)
        end
    end
    return texts
end

local function ApplyPosition()
    trackerTLW:ClearAnchors()
    if sv.trackerX and sv.trackerY then
        trackerTLW:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.trackerX, sv.trackerY)
    else
        trackerTLW:SetAnchor(CENTER, GuiRoot, CENTER, 90, 60)
    end
end

-- ---------------------------------------------------------
-- UI
-- ---------------------------------------------------------

local function CreateUI()
    local wm = WINDOW_MANAGER

    trackerTLW = wm:CreateTopLevelWindow(ADDON .. "_TrackerTLW")
    trackerTLW:SetDimensions(WIDTH, ROW_HEIGHT * SLOT_COUNT + 12)
    trackerTLW:SetMouseEnabled(false)
    trackerTLW:SetMovable(false)
    trackerTLW:SetClampedToScreen(true)
    trackerTLW:SetHidden(true)

    trackerBackdrop = wm:CreateControl(ADDON .. "_TrackerBD", trackerTLW, CT_BACKDROP)
    trackerBackdrop:SetAnchorFill(trackerTLW)
    trackerBackdrop:SetCenterColor(0, 0, 0, 0.4)
    trackerBackdrop:SetEdgeColor(1, 1, 1, 0.5)
    trackerBackdrop:SetEdgeTexture("", 1, 1, 2)
    trackerBackdrop:SetHidden(true)

    for i = 1, SLOT_COUNT do
        local label = wm:CreateControl(ADDON .. "_TrackerLabel" .. i, trackerTLW, CT_LABEL)
        label:SetAnchor(TOP, trackerTLW, TOP, 0, 6 + (i - 1) * ROW_HEIGHT)
        label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
        label:SetFont("$(BOLD_FONT)|18|soft-shadow-thick")
        label:SetColor(1, 0.55, 0.15, 1)
        label:SetHidden(true)
        trackerLabels[i] = label
    end

    trackerTLW:SetHandler("OnMoveStop", function()
        sv.trackerX = trackerTLW:GetLeft()
        sv.trackerY = trackerTLW:GetTop()
        Msg(string.format(L.MSG_POS_SAVED, sv.trackerX, sv.trackerY))
    end)
end

local function HideWindow()
    trackerTLW:SetHidden(true)
end

local function ToggleUnlock()
    unlocked = not unlocked

    trackerTLW:SetMovable(unlocked)
    trackerTLW:SetMouseEnabled(unlocked)
    trackerBackdrop:SetHidden(not unlocked)
    trackerTLW:SetHidden(not unlocked)

    if unlocked then
        trackerTLW:SetDimensions(WIDTH, ROW_HEIGHT + 12)
        trackerLabels[1]:SetHidden(false)
        trackerLabels[1]:SetText("<< >>")
        for i = 2, SLOT_COUNT do
            trackerLabels[i]:SetHidden(true)
        end
    end

    Msg(unlocked and L.MSG_UNLOCKED or L.MSG_LOCKED)

    if not unlocked then
        trackerTLW:SetHidden(true)
    end
end

local function RefreshWindow()
    token = token + 1
    local myToken = token

    if not sv.trackerEnabled or unlocked or not DoesUnitExist("reticleover")
            or IsUnitDead("reticleover") then
        HideWindow()
        return
    end

    local activeTexts = GetActiveTrackerTexts()
    if #activeTexts == 0 then
        HideWindow()
    else
        trackerTLW:SetDimensions(WIDTH, ROW_HEIGHT * #activeTexts + 12)
        for i = 1, SLOT_COUNT do
            if i <= #activeTexts then
                trackerLabels[i]:SetText(activeTexts[i]:upper())
                trackerLabels[i]:SetHidden(false)
            else
                trackerLabels[i]:SetHidden(true)
            end
        end
        trackerTLW:SetHidden(false)
    end

    -- buffs no alvo podem mudar sem voce trocar de mira (aplicar/cair no
    -- meio da luta), entao reavalia periodicamente enquanto estiver olhando
    zo_callLater(function()
        if myToken == token then RefreshWindow() end
    end, POLL_MS)
end

-- ---------------------------------------------------------
-- contrato do modulo
-- ---------------------------------------------------------

function M.Initialize(newSv, newL)
    sv, L, Msg = newSv, newL, one_versus_x.Msg

    CreateUI()
    ApplyPosition()

    EVENT_MANAGER:RegisterForEvent(EVENT_NS, EVENT_RETICLE_TARGET_CHANGED, RefreshWindow)
    EVENT_MANAGER:RegisterForEvent(EVENT_NS, EVENT_UNIT_DEATH_STATE_CHANGED, function(_, unitTag)
        if unitTag == "reticleover" then RefreshWindow() end
    end)
end

function M.SetLocale(newL)
    L = newL
end

function M.BuildPanelOptions()
    local options = {
        { type = "header", name = L.HDR_TRACKER },
        { type = "description", text = L.TRACKER_DESC },
        {
            type    = "checkbox",
            name    = L.TRACKER_ENABLE,
            tooltip = L.TRACKER_ENABLE_TT,
            default = M.defaults.trackerEnabled,
            getFunc = function() return sv.trackerEnabled end,
            setFunc = function(v)
                sv.trackerEnabled = v
                RefreshWindow()
            end,
        },
    }

    for i = 1, SLOT_COUNT do
        table.insert(options, {
            type     = "editbox",
            name     = string.format(L.TRACKER_SLOT, i),
            tooltip  = L.TRACKER_SLOT_TT,
            default  = M.defaults.customTrackers[i] or "",
            getFunc  = function() return sv.customTrackers[i] or "" end,
            setFunc  = function(v) sv.customTrackers[i] = v end,
            disabled = function() return not sv.trackerEnabled end,
        })
    end

    table.insert(options, {
        type     = "button",
        name     = L.BTN_TRACKER_MOVE,
        tooltip  = L.BTN_TRACKER_MOVE_TT,
        func     = ToggleUnlock,
        disabled = function() return not sv.trackerEnabled end,
    })

    return options
end

function M.HandleSlashCommand(arg)
    if arg == "trackermove" then
        ToggleUnlock()
        return true
    end
    return false
end
