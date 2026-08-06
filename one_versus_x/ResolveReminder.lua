-- ResolveReminder: mensagenzona na tela (estilo FossilizeAlert) avisando que
-- voce esta em combate sem Major Resolve ativo. Dispara na hora que o buff
-- cai e continua repetindo em intervalos enquanto voce ficar sem ele em
-- combate; some na hora que voce reaplica ou sai de combate.

one_versus_x = one_versus_x or {}
one_versus_x.ResolveReminder = one_versus_x.ResolveReminder or {}
local M = one_versus_x.ResolveReminder

local ADDON    = "one_versus_x"
local EVENT_NS = "one_versus_x_Resolve"

local WATCHED_BUFF = "Major Resolve"

-- =========================================================

M.defaults = {
    resolveEnabled    = false,
    resolveX          = nil,
    resolveY          = nil,
    resolveText       = nil,   -- nil = usa o padrao do idioma
    resolveFontSize   = 72,
    resolveColor      = { 1, 0.25, 0.1 },
    resolveDuration   = 1000,
    resolveNagInterval = 5000,
}

local sv, L, Msg
local unlocked  = false
local nagToken  = 0
local resolveTLW, resolveLabel, resolveBackdrop

-- ---------------------------------------------------------
-- helpers
-- ---------------------------------------------------------

local function NormalizeName(name)
    return name and zo_strformat("<<1>>", name) or nil
end

local function PlayerHasResolve()
    local wanted = NormalizeName(WATCHED_BUFF):lower()
    for i = 1, GetNumBuffs("player") do
        local n = GetUnitBuffInfo("player", i)
        if n and NormalizeName(n):lower() == wanted then
            return true
        end
    end
    return false
end

local function AlertText()
    if sv.resolveText and sv.resolveText ~= "" then return sv.resolveText end
    return L.DEFAULT_RESOLVE_ALERT
end

local function ApplyStyle()
    resolveLabel:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thick", sv.resolveFontSize))
    resolveLabel:SetColor(sv.resolveColor[1], sv.resolveColor[2], sv.resolveColor[3], 1)
end

local function ApplyPosition()
    resolveTLW:ClearAnchors()
    if sv.resolveX and sv.resolveY then
        resolveTLW:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.resolveX, sv.resolveY)
    else
        resolveTLW:SetAnchor(CENTER, GuiRoot, CENTER, 0, -260)
    end
end

-- ---------------------------------------------------------
-- UI
-- ---------------------------------------------------------

local function CreateUI()
    local wm = WINDOW_MANAGER

    resolveTLW = wm:CreateTopLevelWindow(ADDON .. "_ResolveTLW")
    resolveTLW:SetDimensions(800, 150)
    resolveTLW:SetMouseEnabled(false)
    resolveTLW:SetMovable(false)
    resolveTLW:SetClampedToScreen(true)
    resolveTLW:SetHidden(true)

    resolveBackdrop = wm:CreateControl(ADDON .. "_ResolveBD", resolveTLW, CT_BACKDROP)
    resolveBackdrop:SetAnchorFill(resolveTLW)
    resolveBackdrop:SetCenterColor(0, 0, 0, 0.4)
    resolveBackdrop:SetEdgeColor(1, 1, 1, 0.5)
    resolveBackdrop:SetEdgeTexture("", 1, 1, 2)
    resolveBackdrop:SetHidden(true)

    resolveLabel = wm:CreateControl(ADDON .. "_ResolveLabel", resolveTLW, CT_LABEL)
    resolveLabel:SetAnchor(CENTER, resolveTLW, CENTER)
    resolveLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    resolveTLW:SetHandler("OnMoveStop", function()
        sv.resolveX = resolveTLW:GetLeft()
        sv.resolveY = resolveTLW:GetTop()
        Msg(string.format(L.MSG_POS_SAVED, sv.resolveX, sv.resolveY))
    end)
end

local function HideAlert()
    if not unlocked then resolveTLW:SetHidden(true) end
end

local function Alert()
    if unlocked then return end
    resolveLabel:SetText(AlertText())
    resolveTLW:SetHidden(false)
    zo_callLater(function()
        if not unlocked then resolveTLW:SetHidden(true) end
    end, sv.resolveDuration)
end

local function ToggleUnlock()
    unlocked = not unlocked

    resolveTLW:SetMovable(unlocked)
    resolveTLW:SetMouseEnabled(unlocked)
    resolveBackdrop:SetHidden(not unlocked)
    resolveTLW:SetHidden(not unlocked)
    resolveLabel:SetText(unlocked and "<< >>" or AlertText())

    Msg(unlocked and L.MSG_UNLOCKED or L.MSG_LOCKED)
end

-- ---------------------------------------------------------
-- lembrete periodico
-- ---------------------------------------------------------

local function StopNag()
    nagToken = nagToken + 1
end

local function NagLoop(myToken)
    if myToken ~= nagToken then return end
    if not sv.resolveEnabled or not IsUnitInCombat("player") or PlayerHasResolve() then
        return
    end

    Alert()
    zo_callLater(function() NagLoop(myToken) end, sv.resolveNagInterval)
end

local function StartNag()
    nagToken = nagToken + 1
    NagLoop(nagToken)
end

-- ---------------------------------------------------------
-- eventos
-- ---------------------------------------------------------

local function OnEffectChanged(_, changeType, _, effectName, _, _, _, _, _, _, _, _, _, _, _, _)
    if not sv.resolveEnabled then return end
    if NormalizeName(effectName):lower() ~= WATCHED_BUFF:lower() then return end

    if changeType == EFFECT_RESULT_GAINED then
        StopNag()
        HideAlert()
    elseif changeType == EFFECT_RESULT_FADED then
        if IsUnitInCombat("player") then StartNag() end
    end
end

local function OnCombatStateChanged(_, inCombat)
    if not sv.resolveEnabled then return end

    if inCombat then
        if not PlayerHasResolve() then StartNag() end
    else
        StopNag()
        HideAlert()
    end
end

-- ---------------------------------------------------------
-- contrato do modulo
-- ---------------------------------------------------------

function M.Initialize(newSv, newL)
    sv, L, Msg = newSv, newL, one_versus_x.Msg

    CreateUI()
    ApplyStyle()
    ApplyPosition()
    resolveLabel:SetText(AlertText())

    EVENT_MANAGER:RegisterForEvent(EVENT_NS, EVENT_EFFECT_CHANGED, OnEffectChanged)
    EVENT_MANAGER:AddFilterForEvent(EVENT_NS, EVENT_EFFECT_CHANGED,
        REGISTER_FILTER_UNIT_TAG, "player")
    EVENT_MANAGER:RegisterForEvent(EVENT_NS, EVENT_PLAYER_COMBAT_STATE, OnCombatStateChanged)
end

function M.SetLocale(newL)
    L = newL
    if not unlocked then resolveLabel:SetText(AlertText()) end
end

function M.BuildPanelOptions()
    return {
        { type = "header", name = L.HDR_RESOLVE },
        { type = "description", text = L.RESOLVE_DESC },
        {
            type    = "checkbox",
            name    = L.RESOLVE_ENABLE,
            tooltip = L.RESOLVE_ENABLE_TT,
            default = M.defaults.resolveEnabled,
            getFunc = function() return sv.resolveEnabled end,
            setFunc = function(v)
                sv.resolveEnabled = v
                if not v then StopNag(); HideAlert() end
            end,
        },
        {
            type     = "editbox",
            name     = L.ALERT_TEXT,
            tooltip  = L.ALERT_TEXT_TT,
            default  = "",
            getFunc  = function() return sv.resolveText or "" end,
            setFunc  = function(v)
                sv.resolveText = (v ~= "" and v) or nil
                if not unlocked then resolveLabel:SetText(AlertText()) end
            end,
            disabled = function() return not sv.resolveEnabled end,
        },
        {
            type     = "slider",
            name     = L.FONT_SIZE,
            min      = 20, max = 160, step = 2,
            default  = M.defaults.resolveFontSize,
            getFunc  = function() return sv.resolveFontSize end,
            setFunc  = function(v) sv.resolveFontSize = v; ApplyStyle() end,
            disabled = function() return not sv.resolveEnabled end,
        },
        {
            type     = "colorpicker",
            name     = L.TEXT_COLOR,
            default  = { r = M.defaults.resolveColor[1], g = M.defaults.resolveColor[2], b = M.defaults.resolveColor[3] },
            getFunc  = function() return sv.resolveColor[1], sv.resolveColor[2], sv.resolveColor[3] end,
            setFunc  = function(r, g, b) sv.resolveColor = { r, g, b }; ApplyStyle() end,
            disabled = function() return not sv.resolveEnabled end,
        },
        {
            type     = "slider",
            name     = L.DURATION,
            tooltip  = L.RESOLVE_DURATION_TT,
            min      = 200, max = 3000, step = 100,
            default  = M.defaults.resolveDuration,
            getFunc  = function() return sv.resolveDuration end,
            setFunc  = function(v) sv.resolveDuration = v end,
            disabled = function() return not sv.resolveEnabled end,
        },
        {
            type     = "slider",
            name     = L.RESOLVE_NAG_INTERVAL,
            tooltip  = L.RESOLVE_NAG_INTERVAL_TT,
            min      = 2000, max = 15000, step = 500,
            default  = M.defaults.resolveNagInterval,
            getFunc  = function() return sv.resolveNagInterval end,
            setFunc  = function(v) sv.resolveNagInterval = v end,
            disabled = function() return not sv.resolveEnabled end,
        },
        {
            type     = "button",
            name     = L.BTN_MOVE,
            tooltip  = L.BTN_MOVE_TT,
            func     = ToggleUnlock,
            width    = "half",
            disabled = function() return not sv.resolveEnabled end,
        },
        {
            type     = "button",
            name     = L.BTN_TEST,
            func     = Alert,
            width    = "half",
            disabled = function() return not sv.resolveEnabled end,
        },
    }
end

function M.HandleSlashCommand(arg)
    if arg == "resolvemove" then
        ToggleUnlock()
        return true
    elseif arg == "resolvetest" then
        Alert()
        return true
    end
    return false
end
