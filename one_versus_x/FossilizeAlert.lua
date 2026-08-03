-- FossilizeAlert: alerta quando Petrify/Fossilize/Shattering Rocks te acerta,
-- suprimido se voce ja estiver em imunidade de CC.

one_versus_x = one_versus_x or {}
one_versus_x.FossilizeAlert = one_versus_x.FossilizeAlert or {}
local M = one_versus_x.FossilizeAlert

local ADDON     = "one_versus_x"
local EVENT_NS  = "one_versus_x_Fossilize"

-- =========================================================
-- IDs
-- =========================================================

local WATCH = {
    [32678] = "1",
    [32685] = "2",
    [29037] = "3",
}

local CC_IMMUNITY_ID       = 28301
local CC_IMMUNITY_FALLBACK = 7000

-- =========================================================

M.defaults = {
    x         = nil,
    y         = nil,
    text      = nil,        -- nil = usa o padrao do idioma
    fontSize  = 72,
    duration  = 1000,
    sound     = true,
    soundName = "DUEL_START",
    soundRepeat = 3,
    soundGap    = 70,
    color     = { 1, 0.25, 0.1 },
}

local SOUND_CHOICES = {
    "DUEL_START",
    "DUEL_INVITE_RECEIVED",
    "ABILITY_ULTIMATE_READY",
    "GROUP_INVITE_RECEIVED",
    "GENERAL_ALERT_ERROR",
    "CHAMPION_POINTS_COMMITTED",
}

local sv, L, Msg
local unlocked    = false
local immuneUntil = 0
local alertTLW, alertLabel, alertBackdrop

-- ---------------------------------------------------------
-- helpers
-- ---------------------------------------------------------

-- texto do alerta: o do usuario, ou o padrao do idioma
local function AlertText()
    if sv.text and sv.text ~= "" then return sv.text end
    return L.DEFAULT_ALERT
end

local function IsImmune()
    return GetGameTimeMilliseconds() < immuneUntil
end

local function ApplyStyle()
    alertLabel:SetFont(string.format("$(BOLD_FONT)|%d|soft-shadow-thick", sv.fontSize))
    alertLabel:SetColor(sv.color[1], sv.color[2], sv.color[3], 1)
end

local function ApplyPosition()
    alertTLW:ClearAnchors()
    if sv.x and sv.y then
        alertTLW:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.x, sv.y)
    else
        alertTLW:SetAnchor(CENTER, GuiRoot, CENTER, 0, -180)
    end
end

local function PlayAlertSound()
    if not sv.sound then return end

    local snd = SOUNDS[sv.soundName]
    if not snd then return end

    -- primeira toca na hora, as outras em sequencia
    PlaySound(snd)
    for i = 1, (sv.soundRepeat or 1) - 1 do
        zo_callLater(function() PlaySound(snd) end, i * (sv.soundGap or 70))
    end
end

-- ---------------------------------------------------------
-- UI
-- ---------------------------------------------------------

local function CreateUI()
    local wm = WINDOW_MANAGER

    alertTLW = wm:CreateTopLevelWindow(ADDON .. "_TLW")
    alertTLW:SetDimensions(800, 150)
    alertTLW:SetMouseEnabled(false)
    alertTLW:SetMovable(false)
    alertTLW:SetClampedToScreen(true)
    alertTLW:SetHidden(true)

    alertBackdrop = wm:CreateControl(ADDON .. "_BD", alertTLW, CT_BACKDROP)
    alertBackdrop:SetAnchorFill(alertTLW)
    alertBackdrop:SetCenterColor(0, 0, 0, 0.4)
    alertBackdrop:SetEdgeColor(1, 1, 1, 0.5)
    alertBackdrop:SetEdgeTexture("", 1, 1, 2)
    alertBackdrop:SetHidden(true)

    alertLabel = wm:CreateControl(ADDON .. "_Label", alertTLW, CT_LABEL)
    alertLabel:SetAnchor(CENTER, alertTLW, CENTER)
    alertLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)

    alertTLW:SetHandler("OnMoveStop", function()
        sv.x = alertTLW:GetLeft()
        sv.y = alertTLW:GetTop()
        Msg(string.format(L.MSG_POS_SAVED, sv.x, sv.y))
    end)
end

local function Alert()
    if unlocked then return end
    alertLabel:SetText(AlertText())
    alertTLW:SetHidden(false)
    PlayAlertSound()
    zo_callLater(function()
        if not unlocked then alertTLW:SetHidden(true) end
    end, sv.duration)
end

local function ToggleUnlock()
    unlocked = not unlocked

    alertTLW:SetMovable(unlocked)
    alertTLW:SetMouseEnabled(unlocked)
    alertBackdrop:SetHidden(not unlocked)
    alertTLW:SetHidden(not unlocked)
    alertLabel:SetText(unlocked and "<< >>" or AlertText())

    Msg(unlocked and L.MSG_UNLOCKED or L.MSG_LOCKED)
end

-- ---------------------------------------------------------
-- eventos
-- ---------------------------------------------------------

local function OnEffectChanged(_, changeType, _, effectName, _,
        beginTime, endTime, _, _, _, _, _, _, _, _, abilityId)

    if abilityId == CC_IMMUNITY_ID then
        if changeType == EFFECT_RESULT_GAINED then
            local dur = (endTime - beginTime) * 1000
            if dur <= 0 then dur = CC_IMMUNITY_FALLBACK end
            immuneUntil = GetGameTimeMilliseconds() + dur
            if sv.sniffing then Msg(string.format(L.MSG_IMM_ON, dur)) end
        elseif changeType == EFFECT_RESULT_FADED then
            immuneUntil = 0
            if sv.sniffing then Msg(L.MSG_IMM_OFF) end
        end
        return
    end

    if changeType ~= EFFECT_RESULT_GAINED then return end

    if sv.sniffing then
        d(zo_strformat("|c66ccff[SNIFF]|r <<1>>  ->  id = <<2>>", effectName, abilityId))
    end

    if WATCH[abilityId] then
        if IsImmune() then return end
        Alert()
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
    alertLabel:SetText(AlertText())

    EVENT_MANAGER:RegisterForEvent(EVENT_NS, EVENT_EFFECT_CHANGED, OnEffectChanged)
    EVENT_MANAGER:AddFilterForEvent(EVENT_NS, EVENT_EFFECT_CHANGED,
        REGISTER_FILTER_UNIT_TAG, "player")
end

function M.SetLocale(newL)
    L = newL
    if not unlocked then alertLabel:SetText(AlertText()) end
end

function M.BuildPanelOptions()
    return {
        { type = "header", name = L.HDR_APPEARANCE },
        {
            type    = "editbox",
            name    = L.ALERT_TEXT,
            tooltip = L.ALERT_TEXT_TT,
            default = "",
            getFunc = function() return sv.text or "" end,
            setFunc = function(v)
                sv.text = (v ~= "" and v) or nil
                if not unlocked then alertLabel:SetText(AlertText()) end
            end,
        },
        {
            type    = "slider",
            name    = L.FONT_SIZE,
            min     = 20, max = 160, step = 2,
            default = M.defaults.fontSize,
            getFunc = function() return sv.fontSize end,
            setFunc = function(v) sv.fontSize = v; ApplyStyle() end,
        },
        {
            type    = "colorpicker",
            name    = L.TEXT_COLOR,
            default = { r = M.defaults.color[1], g = M.defaults.color[2], b = M.defaults.color[3] },
            getFunc = function() return sv.color[1], sv.color[2], sv.color[3] end,
            setFunc = function(r, g, b) sv.color = { r, g, b }; ApplyStyle() end,
        },
        {
            type    = "slider",
            name    = L.DURATION,
            tooltip = L.DURATION_TT,
            min     = 200, max = 3000, step = 100,
            default = M.defaults.duration,
            getFunc = function() return sv.duration end,
            setFunc = function(v) sv.duration = v end,
        },
        {
            type    = "button",
            name    = L.BTN_MOVE,
            tooltip = L.BTN_MOVE_TT,
            func    = ToggleUnlock,
            width   = "half",
        },
        {
            type  = "button",
            name  = L.BTN_TEST,
            func  = Alert,
            width = "half",
        },

        { type = "header", name = L.HDR_SOUND },
        {
            type    = "checkbox",
            name    = L.PLAY_SOUND,
            default = M.defaults.sound,
            getFunc = function() return sv.sound end,
            setFunc = function(v) sv.sound = v end,
        },
        {
            type     = "dropdown",
            name     = L.ALERT_SOUND,
            choices  = SOUND_CHOICES,
            default  = M.defaults.soundName,
            getFunc  = function() return sv.soundName end,
            setFunc  = function(v) sv.soundName = v; PlayAlertSound() end,
            disabled = function() return not sv.sound end,
        },
        {
            type     = "slider",
            name     = L.SOUND_REPEAT,
            tooltip  = L.SOUND_REPEAT_TT,
            min      = 1, max = 5, step = 1,
            default  = M.defaults.soundRepeat,
            getFunc  = function() return sv.soundRepeat end,
            setFunc  = function(v) sv.soundRepeat = v; PlayAlertSound() end,
            disabled = function() return not sv.sound end,
        },
        {
            type     = "slider",
            name     = L.SOUND_GAP,
            tooltip  = L.SOUND_GAP_TT,
            min      = 30, max = 250, step = 10,
            default  = M.defaults.soundGap,
            getFunc  = function() return sv.soundGap end,
            setFunc  = function(v) sv.soundGap = v; PlayAlertSound() end,
            disabled = function() return not sv.sound or sv.soundRepeat < 2 end,
        },
    }
end

function M.BuildDebugOptions()
    return {
        {
            type = "button",
            name = L.BTN_IMMUNE,
            func = function()
                if IsImmune() then
                    Msg(string.format(L.MSG_IMMUNE_YES, immuneUntil - GetGameTimeMilliseconds()))
                else
                    Msg(L.MSG_IMMUNE_NO)
                end
            end,
        },
    }
end

function M.HandleSlashCommand(arg)
    if arg == "move" then
        ToggleUnlock()
        return true
    elseif arg == "test" then
        Alert()
        return true
    end
    return false
end
