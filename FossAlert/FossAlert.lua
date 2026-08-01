-- FossAlert v1.1
-- Alerta quando Petrify/Fossilize/Shattering Rocks te acerta,
-- suprimido se voce ja estiver em imunidade de CC.
-- Tambem inclui o Squishy Detector: aprende sozinho a media de dano de
-- cada habilidade sua e classifica alvos mirados em super light/light/
-- medium/heavy/super heavy com base em quanto cada hit desvia dessa
-- media (ajustado pela vida do alvo).
--
-- Configuracao: /foss  (ou Settings > Addons > FossAlert)
-- Textos ficam em Locale.lua

FossAlert = FossAlert or {}

local ADDON = "FossAlert"

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

-- gradiente continuo: vermelho no tanque (evite bater) ate verde no
-- esquichy (alvo prioritario). O texto da etiqueta usa niveis fixos
-- (SQUISH_TIER), mas a cor segue o score direto, sem degraus.
local SQUISH_COLOR_TANK   = { 0.90, 0.20, 0.20 }
local SQUISH_COLOR_SQUISHY = { 0.45, 0.85, 0.35 }

-- vida "de referencia" usada pra normalizar o score: um alvo com vida
-- abaixo disso fica mais esquichy pelo mesmo dano, e vice-versa.
local SQUISH_REFERENCE_HEALTH   = 32000
local SQUISH_SCORE_SMOOTHING    = 0.18  -- peso do hit novo na media suavizada do alvo
local SQUISH_CATEGORY_HYSTERESIS = 0.04 -- margem pra nao trocar de categoria por ruido

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

    squishEnabled         = false,
    squishScoreSuperHeavyMax = 0.85,  -- abaixo disso = super heavy (mais tanque)
    squishScoreHeavyMax      = 0.95,  -- abaixo disso (e >= super heavy) = heavy
    squishScoreMediumMax     = 1.05,  -- abaixo disso (e >= heavy) = medium
    squishScoreLightMax      = 1.15,  -- abaixo disso (e >= medium) = light; >= isso = super light (mais esquichy)
    squishExpireSeconds   = 8,
    squishX               = nil,
    squishY               = nil,
    squishBaselines       = {},    -- [abilityId:tipoDeHit] = { average, samples } -- persiste entre sessoes
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

local playerName            -- nome do player, normalizado, cacheado no load
local squishData    = {}    -- [nomeNormalizado] = { value, time, tier, score, hits, maxHealth }
local squishKnownPlayers = {} -- [nomeNormalizado] = true, confirmado via IsUnitPlayer no reticulo
local squishToken   = 0     -- invalida callbacks de expiracao obsoletos
local squishUnlocked = false
local squishTLW, squishLabel, squishBackdrop

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

local function NormalizeName(name)
    return name and zo_strformat("<<1>>", name) or nil
end

local function Clamp(value, minValue, maxValue)
    if value < minValue then return minValue end
    if value > maxValue then return maxValue end
    return value
end

local function GetSquishBaselineKey(abilityId, result)
    local bucket = "hit"
    if result == ACTION_RESULT_CRITICAL_DAMAGE then bucket = "crit"
    elseif result == ACTION_RESULT_DOT_TICK then bucket = "tick"
    elseif result == ACTION_RESULT_DOT_TICK_CRITICAL then bucket = "tickCrit" end
    return string.format("%d:%s", abilityId, bucket)
end

-- media aprendida de dano dessa habilidade+tipo de hit; sem amostra
-- suficiente ainda, usa o proprio hit atual como fallback neutro
local function GetSquishExpectedDamage(abilityId, result, fallbackHitValue)
    local key = GetSquishBaselineKey(abilityId, result)
    local entry = sv.squishBaselines[key]
    if not entry or entry.samples < 3 then
        return math.max(fallbackHitValue, 1)
    end
    return math.max(entry.average, 1)
end

local function UpdateSquishBaseline(abilityId, result, hitValue)
    local key = GetSquishBaselineKey(abilityId, result)
    local entry = sv.squishBaselines[key]
    if not entry then
        sv.squishBaselines[key] = { average = hitValue, samples = 1 }
        return
    end
    entry.average = (entry.average * 0.85) + (hitValue * 0.15)
    entry.samples = entry.samples + 1
end

local function ComputeSquishScore(maxHealth, hitValue, expectedDamage)
    local damageRatio = hitValue / math.max(expectedDamage, 1)
    local healthFactor = 1

    if maxHealth and maxHealth > 0 then
        healthFactor = Clamp(SQUISH_REFERENCE_HEALTH / maxHealth, 0.85, 1.15)
    end

    return damageRatio * healthFactor
end

local function ClassifyScore(score)
    if score < sv.squishScoreSuperHeavyMax then return "superheavy"
    elseif score < sv.squishScoreHeavyMax then return "heavy"
    elseif score < sv.squishScoreMediumMax then return "medium"
    elseif score < sv.squishScoreLightMax then return "light"
    else return "superlight" end
end

-- mantem a categoria anterior a nao ser que o score va claramente pra
-- outra faixa, pra nao ficar piscando de categoria por ruido de hit a hit
local function AssignSquishCategory(entry)
    local score = entry.score or 1
    local previous = entry.tier
    local margin = SQUISH_CATEGORY_HYSTERESIS

    if previous == "superlight" and score >= (sv.squishScoreLightMax - margin) then
        entry.tier = "superlight"
        return
    end
    if previous == "light" and score >= (sv.squishScoreMediumMax - margin)
            and score < (sv.squishScoreLightMax + margin) then
        entry.tier = "light"
        return
    end
    if previous == "medium" and score >= (sv.squishScoreHeavyMax - margin)
            and score < (sv.squishScoreMediumMax + margin) then
        entry.tier = "medium"
        return
    end
    if previous == "heavy" and score >= (sv.squishScoreSuperHeavyMax - margin)
            and score < (sv.squishScoreHeavyMax + margin) then
        entry.tier = "heavy"
        return
    end
    if previous == "superheavy" and score < (sv.squishScoreSuperHeavyMax + margin) then
        entry.tier = "superheavy"
        return
    end

    entry.tier = ClassifyScore(score)
end

-- interpola entre vermelho (tanque) e verde (esquichy) direto pelo score,
-- sem depender do nivel/degrau (fica mais suave que cor fixa por tier)
local function GetSquishColor(score)
    local lo, hi = sv.squishScoreSuperHeavyMax, sv.squishScoreLightMax
    local t = 0.5
    if hi > lo then
        t = Clamp((score - lo) / (hi - lo), 0, 1)
    end
    return SQUISH_COLOR_TANK[1] + (SQUISH_COLOR_SQUISHY[1] - SQUISH_COLOR_TANK[1]) * t,
           SQUISH_COLOR_TANK[2] + (SQUISH_COLOR_SQUISHY[2] - SQUISH_COLOR_TANK[2]) * t,
           SQUISH_COLOR_TANK[3] + (SQUISH_COLOR_SQUISHY[3] - SQUISH_COLOR_TANK[3]) * t
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

local function ApplySquishPosition()
    squishTLW:ClearAnchors()
    if sv.squishX and sv.squishY then
        squishTLW:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.squishX, sv.squishY)
    else
        squishTLW:SetAnchor(CENTER, GuiRoot, CENTER, 0, 60)
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
-- squishy detector: UI da etiqueta
-- ---------------------------------------------------------

local function CreateSquishUI()
    local wm = WINDOW_MANAGER

    squishTLW = wm:CreateTopLevelWindow(ADDON .. "_SquishTLW")
    squishTLW:SetDimensions(400, 60)
    squishTLW:SetMouseEnabled(false)
    squishTLW:SetMovable(false)
    squishTLW:SetClampedToScreen(true)
    squishTLW:SetHidden(true)

    squishBackdrop = wm:CreateControl(ADDON .. "_SquishBD", squishTLW, CT_BACKDROP)
    squishBackdrop:SetAnchorFill(squishTLW)
    squishBackdrop:SetCenterColor(0, 0, 0, 0.4)
    squishBackdrop:SetEdgeColor(1, 1, 1, 0.5)
    squishBackdrop:SetEdgeTexture("", 1, 1, 2)
    squishBackdrop:SetHidden(true)

    squishLabel = wm:CreateControl(ADDON .. "_SquishLabel", squishTLW, CT_LABEL)
    squishLabel:SetAnchor(CENTER, squishTLW, CENTER)
    squishLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    squishLabel:SetFont("$(BOLD_FONT)|28|soft-shadow-thick")

    squishTLW:SetHandler("OnMoveStop", function()
        sv.squishX = squishTLW:GetLeft()
        sv.squishY = squishTLW:GetTop()
        Msg(string.format(L.MSG_POS_SAVED, sv.squishX, sv.squishY))
    end)
end

local function HideSquishLabel()
    squishTLW:SetHidden(true)
end

local function ToggleSquishUnlock()
    squishUnlocked = not squishUnlocked

    squishTLW:SetMovable(squishUnlocked)
    squishTLW:SetMouseEnabled(squishUnlocked)
    squishBackdrop:SetHidden(not squishUnlocked)
    squishTLW:SetHidden(not squishUnlocked)
    squishLabel:SetText(squishUnlocked and "<< >>" or "")

    Msg(squishUnlocked and L.MSG_UNLOCKED or L.MSG_LOCKED)

    if not squishUnlocked then
        squishToken = squishToken + 1
        HideSquishLabel()
    end
end

local function RefreshReticleLabel()
    squishToken = squishToken + 1
    local myToken = squishToken

    if not sv.squishEnabled or squishUnlocked or not DoesUnitExist("reticleover") then
        HideSquishLabel()
        return
    end

    local target = NormalizeName(GetUnitName("reticleover"))
    local entry = target and squishData[target]
    if not entry or (entry.hits or 0) < 1 then
        HideSquishLabel()
        return
    end

    local expireMs = sv.squishExpireSeconds * 1000
    local age = GetGameTimeMilliseconds() - entry.time

    if age >= expireMs then
        squishData[target] = nil
        HideSquishLabel()
        return
    end

    local r, g, b = GetSquishColor(entry.score or 1)
    squishLabel:SetText(L.SQUISH_TIER[entry.tier])
    squishLabel:SetColor(r, g, b, 1)
    squishTLW:SetHidden(false)

    zo_callLater(function()
        if myToken == squishToken then RefreshReticleLabel() end
    end, expireMs - age + 50)
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

local SQUISH_SCORE_RESULTS = {
    [ACTION_RESULT_DAMAGE] = true,
    [ACTION_RESULT_CRITICAL_DAMAGE] = true,
    [ACTION_RESULT_DOT_TICK] = true,
    [ACTION_RESULT_DOT_TICK_CRITICAL] = true,
}

local function OnSquishCombatEvent(_, result, isError, abilityName, abilityGraphic,
        abilityActionSlotType, sourceName, sourceType, targetName, targetType,
        hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId, overflow)

    if not SQUISH_SCORE_RESULTS[result] then return end
    if not abilityId or hitValue == nil or hitValue <= 0 then return end
    if sourceType ~= COMBAT_UNIT_TYPE_PLAYER then return end
    if NormalizeName(sourceName) ~= playerName then return end

    local target = NormalizeName(targetName)
    if not target then return end

    -- COMBAT_UNIT_TYPE_PLAYER significa "eu mesmo", nao "qualquer jogador",
    -- entao nao da pra usar targetType pra saber se o alvo e um jogador
    -- inimigo (o combat event nao expoe isso). Em vez disso, confirma via
    -- IsUnitPlayer sempre que o alvo bate com o reticulo, e "lembra" quem
    -- ja foi confirmado jogador pra continuar contando os hits mesmo fora
    -- da mira. NPC nunca entra nessa lista, entao fica de fora pra sempre.
    local reticleNow = DoesUnitExist("reticleover") and NormalizeName(GetUnitName("reticleover")) == target

    if reticleNow then
        if IsUnitPlayer("reticleover") then
            squishKnownPlayers[target] = true
        else
            return
        end
    end

    if not squishKnownPlayers[target] then return end

    if sv.sniffing then
        Msg(string.format("[squish raw] %s -> %s  id=%d  dano=%d",
            tostring(abilityName), target, abilityId, hitValue))
    end

    local ok, err = pcall(function()
        local value = hitValue + (overflow or 0)
        local entry = squishData[target]
        if not entry then
            entry = { hits = 0, tier = "medium" }
            squishData[target] = entry
        end

        if reticleNow then
            local _, maxHealth = GetUnitPower("reticleover", COMBAT_MECHANIC_FLAGS_HEALTH)
            entry.maxHealth = maxHealth
        end

        local expected = GetSquishExpectedDamage(abilityId, result, value)
        local rawScore = ComputeSquishScore(entry.maxHealth, value, expected)

        entry.hits = entry.hits + 1
        if entry.hits <= 1 then
            entry.score = rawScore
        else
            entry.score = (entry.score * (1 - SQUISH_SCORE_SMOOTHING)) + (rawScore * SQUISH_SCORE_SMOOTHING)
        end
        AssignSquishCategory(entry)

        entry.value = value
        entry.time = GetGameTimeMilliseconds()

        UpdateSquishBaseline(abilityId, result, value)

        if sv.sniffing then
            Msg(string.format(L.MSG_SQUISH_HIT, target, value, entry.tier))
        end

        RefreshReticleLabel()
    end)

    if not ok then
        Msg("|cff0000[squish ERROR]|r " .. tostring(err))
    end
end

local function SyncSquishFilter()
    EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_COMBAT_EVENT)

    if not sv.squishEnabled then return end

    -- sem AddFilterForEvent de proposito: toda a checagem acontece em Lua
    -- dentro de OnSquishCombatEvent (mais robusto contra combinacoes de
    -- filtro que o motor do jogo pode nao aceitar como esperado).
    EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_COMBAT_EVENT, OnSquishCombatEvent)
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
        version             = "1.1",
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

    local options = {
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

        { type = "header", name = L.HDR_SQUISHY },
        { type = "description", text = L.SQUISH_DESC },
        {
            type    = "checkbox",
            name    = L.SQUISH_ENABLE,
            tooltip = L.SQUISH_ENABLE_TT,
            default = defaults.squishEnabled,
            getFunc = function() return sv.squishEnabled end,
            setFunc = function(v)
                sv.squishEnabled = v
                SyncSquishFilter()
                if not v then squishToken = squishToken + 1; HideSquishLabel() end
            end,
        },
        {
            type     = "slider",
            name     = L.SQUISH_THRESHOLD_SUPERHEAVY,
            tooltip  = L.SQUISH_THRESHOLD_SUPERHEAVY_TT,
            min      = 50, max = 200, step = 1,
            default  = defaults.squishScoreSuperHeavyMax * 100,
            getFunc  = function() return math.floor(sv.squishScoreSuperHeavyMax * 100 + 0.5) end,
            setFunc  = function(v) sv.squishScoreSuperHeavyMax = v / 100 end,
            disabled = function() return not sv.squishEnabled end,
        },
        {
            type     = "slider",
            name     = L.SQUISH_THRESHOLD_HEAVY,
            tooltip  = L.SQUISH_THRESHOLD_HEAVY_TT,
            min      = 50, max = 200, step = 1,
            default  = defaults.squishScoreHeavyMax * 100,
            getFunc  = function() return math.floor(sv.squishScoreHeavyMax * 100 + 0.5) end,
            setFunc  = function(v) sv.squishScoreHeavyMax = v / 100 end,
            disabled = function() return not sv.squishEnabled end,
        },
        {
            type     = "slider",
            name     = L.SQUISH_THRESHOLD_MEDIUM,
            tooltip  = L.SQUISH_THRESHOLD_MEDIUM_TT,
            min      = 50, max = 200, step = 1,
            default  = defaults.squishScoreMediumMax * 100,
            getFunc  = function() return math.floor(sv.squishScoreMediumMax * 100 + 0.5) end,
            setFunc  = function(v) sv.squishScoreMediumMax = v / 100 end,
            disabled = function() return not sv.squishEnabled end,
        },
        {
            type     = "slider",
            name     = L.SQUISH_THRESHOLD_LIGHT,
            tooltip  = L.SQUISH_THRESHOLD_LIGHT_TT,
            min      = 50, max = 200, step = 1,
            default  = defaults.squishScoreLightMax * 100,
            getFunc  = function() return math.floor(sv.squishScoreLightMax * 100 + 0.5) end,
            setFunc  = function(v) sv.squishScoreLightMax = v / 100 end,
            disabled = function() return not sv.squishEnabled end,
        },
        {
            type     = "slider",
            name     = L.SQUISH_EXPIRE,
            tooltip  = L.SQUISH_EXPIRE_TT,
            min      = 3, max = 30, step = 1,
            default  = defaults.squishExpireSeconds,
            getFunc  = function() return sv.squishExpireSeconds end,
            setFunc  = function(v) sv.squishExpireSeconds = v end,
            disabled = function() return not sv.squishEnabled end,
        },
        {
            type     = "button",
            name     = L.BTN_SQUISH_MOVE,
            tooltip  = L.BTN_SQUISH_MOVE_TT,
            func     = ToggleSquishUnlock,
            width    = "half",
            disabled = function() return not sv.squishEnabled end,
        },
        {
            type     = "button",
            name     = L.BTN_SQUISH_RESET,
            func     = function()
                squishData = {}
                squishKnownPlayers = {}
                squishToken = squishToken + 1
                HideSquishLabel()
                Msg(L.MSG_SQUISH_RESET)
            end,
            width    = "half",
            disabled = function() return not sv.squishEnabled end,
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
    }

    regControls(LAM, ADDON .. "_Panel", options)
end

-- ---------------------------------------------------------

local function OnLoaded(_, addonName)
    if addonName ~= ADDON then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_ADD_ON_LOADED)

    sv = ZO_SavedVars:NewAccountWide("FossAlertSV", 1, nil, defaults)
    sv.squishBaselines = sv.squishBaselines or {}
    L  = ResolveLocale()
    playerName = NormalizeName(GetUnitName("player"))

    CreateUI()
    ApplyStyle()
    ApplyPosition()
    alertLabel:SetText(AlertText())

    CreateSquishUI()
    ApplySquishPosition()

    EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_EFFECT_CHANGED, OnEffectChanged)
    EVENT_MANAGER:AddFilterForEvent(ADDON, EVENT_EFFECT_CHANGED,
        REGISTER_FILTER_UNIT_TAG, "player")

    EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_RETICLE_TARGET_CHANGED, RefreshReticleLabel)

    SyncSquishFilter()

    BuildMenu()

    SLASH_COMMANDS["/foss"] = function(args)
        args = (args or ""):lower()
        local LAM = GetLAM()
        if args == "move" then
            ToggleUnlock()
        elseif args == "test" then
            Alert()
        elseif args == "squishmove" then
            ToggleSquishUnlock()
        elseif panelRef and LAM and LAM.OpenToPanel then
            LAM:OpenToPanel(panelRef)
        else
            Msg(L.MSG_CMDS)
        end
    end

    Msg(L.MSG_LOADED)
end

EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_ADD_ON_LOADED, OnLoaded)
