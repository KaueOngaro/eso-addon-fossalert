-- FossAlert v0.6
-- Alerta quando Petrify/Fossilize/Shattering Rocks entra em voce,
-- suprimido se voce ja estiver em imunidade de CC.
--
-- Configuracao: /foss  (ou Settings > Addons > FossAlert)
-- Textos ficam em Locale.lua

FossAlert = FossAlert or {}

local ADDON = "FossAlert"

-- =========================================================
-- IDs
-- =========================================================

local WATCH = {
    [32678] = "Shattering Rocks",
    [32678] = "Fossilize",
    [29037] = "Petrify"
}

local CC_IMMUNITY_ID       = 28301
local CC_IMMUNITY_FALLBACK = 7000

-- =========================================================

local defaults = {
    x         = nil,
    y         = nil,
    locale    = "auto",
    text      = nil,        -- nil = usa o padrao do idioma
    fontSize  = 72,
    duration  = 1000,
    sound     = true,
    soundName = "DUEL_START",
    soundRepeat = 3,
    soundGap    = 70,
    sniffing  = false,
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

local sv
local L                       -- tabela de strings do idioma ativo
local unlocked    = false
local immuneUntil = 0
local panelRef
local alertTLW, alertLabel, alertBackdrop

-- ---------------------------------------------------------
-- idioma
-- ---------------------------------------------------------

local function ResolveLocale()
    local code = sv and sv.locale or "auto"

    if code == "auto" then
        -- ESO nao tem cliente em portugues, entao "auto" cai em ingles
        -- para qualquer um que nao tenha escolhido pt na mao.
        code = GetCVar("Language.2") or "en"
    end

    return FossAlert.STRINGS[code] or FossAlert.STRINGS.en
end

-- texto do alerta: o do usuario, ou o padrao do idioma
local function AlertText()
    if sv.text and sv.text ~= "" then return sv.text end
    return L.DEFAULT_ALERT
end

-- ---------------------------------------------------------
-- helpers
-- ---------------------------------------------------------

local function Msg(s)
    d("|cffaa33[FossAlert]|r " .. s)
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
-- painel LibAddonMenu-2.0
-- ---------------------------------------------------------

local function GetLAM()
    if LibAddonMenu2 then return LibAddonMenu2 end
    if LibStub then
        local ok, lib = pcall(LibStub, "LibAddonMenu-2.0")
        if ok and lib then return lib end
    end
    return nil
end

local function BuildMenu()
    local LAM = GetLAM()
    if not LAM then
        Msg(L.MSG_NO_LAM)
        return
    end

    local regPanel    = LAM.RegisterAddonPanel
    local regControls = LAM.RegisterOptionsControls or LAM.RegisterOptionControls

    if not (regPanel and regControls) then
        Msg(L.MSG_BAD_LAM)
        d("/script for k,v in pairs(LibAddonMenu2) do d(k) end")
        return
    end

    panelRef = regPanel(LAM, ADDON .. "_Panel", {
        type                = "panel",
        name                = "FossAlert",
        displayName         = "|cffaa33FossAlert|r",
        author              = "Kaue",
        version             = "0.6",
        registerForRefresh  = true,
        registerForDefaults = true,
    })

    -- monta a lista de idiomas a partir da propria tabela de strings
    local langValues = { "auto" }
    local langLabels = { L.LANG_AUTO }
    for code, tbl in pairs(FossAlert.STRINGS) do
        table.insert(langValues, code)
        table.insert(langLabels, tbl.LANG_NAME)
    end

    regControls(LAM, ADDON .. "_Panel", {
        { type = "description", text = L.DESC },

        { type = "header", name = L.HDR_GENERAL },
        {
            type          = "dropdown",
            name          = L.LANGUAGE,
            tooltip       = L.LANGUAGE_TT,
            choices       = langLabels,
            choicesValues = langValues,
            default       = defaults.locale,
            getFunc       = function() return sv.locale end,
            setFunc       = function(v)
                sv.locale = v
                L = ResolveLocale()
                if not unlocked then alertLabel:SetText(AlertText()) end
                Msg(L.MSG_NEEDS_RELOAD)
            end,
        },

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
            default = defaults.fontSize,
            getFunc = function() return sv.fontSize end,
            setFunc = function(v) sv.fontSize = v; ApplyStyle() end,
        },
        {
            type    = "colorpicker",
            name    = L.TEXT_COLOR,
            default = { r = defaults.color[1], g = defaults.color[2], b = defaults.color[3] },
            getFunc = function() return sv.color[1], sv.color[2], sv.color[3] end,
            setFunc = function(r, g, b) sv.color = { r, g, b }; ApplyStyle() end,
        },
        {
            type    = "slider",
            name    = L.DURATION,
            tooltip = L.DURATION_TT,
            min     = 200, max = 3000, step = 100,
            default = defaults.duration,
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
            default = defaults.sound,
            getFunc = function() return sv.sound end,
            setFunc = function(v) sv.sound = v end,
        },
        {
            type     = "dropdown",
            name     = L.ALERT_SOUND,
            choices  = SOUND_CHOICES,
            default  = defaults.soundName,
            getFunc  = function() return sv.soundName end,
            setFunc  = function(v) sv.soundName = v; PlayAlertSound() end,
            disabled = function() return not sv.sound end,
        },
        {
            type     = "slider",
            name     = L.SOUND_REPEAT,
            tooltip  = L.SOUND_REPEAT_TT,
            min      = 1, max = 5, step = 1,
            default  = defaults.soundRepeat,
            getFunc  = function() return sv.soundRepeat end,
            setFunc  = function(v) sv.soundRepeat = v; PlayAlertSound() end,
            disabled = function() return not sv.sound end,
        },
        {
            type     = "slider",
            name     = L.SOUND_GAP,
            tooltip  = L.SOUND_GAP_TT,
            min      = 30, max = 250, step = 10,
            default  = defaults.soundGap,
            getFunc  = function() return sv.soundGap end,
            setFunc  = function(v) sv.soundGap = v; PlayAlertSound() end,
            disabled = function() return not sv.sound or sv.soundRepeat < 2 end,
        },

        { type = "header", name = L.HDR_DEBUG },
        {
            type    = "checkbox",
            name    = L.SNIFFER,
            tooltip = L.SNIFFER_TT,
            default = defaults.sniffing,
            getFunc = function() return sv.sniffing end,
            setFunc = function(v) sv.sniffing = v end,
        },
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
    })
end

-- ---------------------------------------------------------

local function OnLoaded(_, addonName)
    if addonName ~= ADDON then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_ADD_ON_LOADED)

    sv = ZO_SavedVars:NewAccountWide("FossAlertSV", 1, nil, defaults)
    L  = ResolveLocale()

    CreateUI()
    ApplyStyle()
    ApplyPosition()
    alertLabel:SetText(AlertText())

    EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_EFFECT_CHANGED, OnEffectChanged)
    EVENT_MANAGER:AddFilterForEvent(ADDON, EVENT_EFFECT_CHANGED,
        REGISTER_FILTER_UNIT_TAG, "player")

    BuildMenu()

    SLASH_COMMANDS["/foss"] = function(args)
        args = (args or ""):lower()
        local LAM = GetLAM()
        if args == "move" then
            ToggleUnlock()
        elseif args == "test" then
            Alert()
        elseif panelRef and LAM and LAM.OpenToPanel then
            LAM:OpenToPanel(panelRef)
        else
            Msg(L.MSG_CMDS)
        end
    end

    Msg(L.MSG_LOADED)
end

EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_ADD_ON_LOADED, OnLoaded)
