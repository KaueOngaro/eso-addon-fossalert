-- SquishyDetector: aprende sozinho a media de dano de cada habilidade sua e
-- classifica o alvo mirado em super light/light/medium/heavy/super heavy com
-- base em quanto cada hit desvia dessa media (ajustado pela vida do alvo).

FossAlert = FossAlert or {}
FossAlert.SquishyDetector = FossAlert.SquishyDetector or {}
local M = FossAlert.SquishyDetector

local ADDON    = "FossAlert"
local EVENT_NS = "FossAlert_Squishy"

-- gradiente continuo: vermelho no tanque (evite bater) ate verde no
-- esquichy (alvo prioritario). O texto da etiqueta usa niveis fixos
-- (SQUISH_TIER), mas a cor segue o score direto, sem degraus.
local SQUISH_COLOR_TANK    = { 0.90, 0.20, 0.20 }
local SQUISH_COLOR_SQUISHY = { 0.45, 0.85, 0.35 }
local SQUISH_COLOR_UNLIT   = { 0.30, 0.30, 0.30, 0.35 }

-- modo "barrinhas": medidor tipo sinal de celular/ping, altura crescente.
-- quanto mais barra acesa (e mais vermelho), mais mitigacao o alvo tem;
-- esquichy acende so a primeira (verde).
local SQUISH_BAR_HEIGHTS = { 14, 20, 26, 32, 38 }
local SQUISH_TIER_ORDER = {
    superheavy = 5,
    heavy      = 4,
    medium     = 3,
    light      = 2,
    superlight = 1,
}

-- vida "de referencia" usada pra normalizar o score: um alvo com vida
-- abaixo disso fica mais esquichy pelo mesmo dano, e vice-versa.
local SQUISH_REFERENCE_HEALTH    = 32000
local SQUISH_SCORE_SMOOTHING     = 0.18  -- peso do hit novo na media suavizada do alvo
local SQUISH_CATEGORY_HYSTERESIS = 0.04  -- margem pra nao trocar de categoria por ruido

local SQUISH_SCORE_RESULTS = {
    [ACTION_RESULT_DAMAGE] = true,
    [ACTION_RESULT_CRITICAL_DAMAGE] = true,
    [ACTION_RESULT_DOT_TICK] = true,
    [ACTION_RESULT_DOT_TICK_CRITICAL] = true,
}

-- =========================================================

M.defaults = {
    squishEnabled            = false,
    squishScoreSuperHeavyMax = 0.85,  -- abaixo disso = super heavy (mais tanque)
    squishScoreHeavyMax      = 0.95,  -- abaixo disso (e >= super heavy) = heavy
    squishScoreMediumMax     = 1.05,  -- abaixo disso (e >= heavy) = medium
    squishScoreLightMax      = 1.15,  -- abaixo disso (e >= medium) = light; >= isso = super light (mais esquichy)
    squishExpireSeconds      = 8,
    squishDisplayMode        = "text",  -- "text" ou "bars"
    squishX                  = nil,
    squishY                  = nil,
    squishBaselines          = {},    -- [abilityId:tipoDeHit] = { average, samples } -- persiste entre sessoes
}

local sv, L, Msg
local playerName            -- nome do player, normalizado, cacheado no load
local squishData    = {}    -- [nomeNormalizado] = { value, time, tier, score, hits, maxHealth }
local squishKnownPlayers = {} -- [nomeNormalizado] = true, confirmado via IsUnitPlayer no reticulo
local squishToken   = 0     -- invalida callbacks de expiracao obsoletos
local squishUnlocked = false
local squishTLW, squishLabel, squishBackdrop
local squishBars = {} -- 5 segmentos tipo medidor de sinal, altura crescente

-- ---------------------------------------------------------
-- helpers
-- ---------------------------------------------------------

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

local function ApplySquishPosition()
    squishTLW:ClearAnchors()
    if sv.squishX and sv.squishY then
        squishTLW:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, sv.squishX, sv.squishY)
    else
        squishTLW:SetAnchor(CENTER, GuiRoot, CENTER, 0, 60)
    end
end

local function ApplySquishDisplayMode()
    local isBars = sv.squishDisplayMode == "bars"
    squishLabel:SetHidden(isBars)
    for i = 1, #squishBars do
        squishBars[i]:SetHidden(not isBars)
    end
end

-- ---------------------------------------------------------
-- UI
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

    local barWidth, barGap = 8, 4
    local totalWidth = (#SQUISH_BAR_HEIGHTS * barWidth) + ((#SQUISH_BAR_HEIGHTS - 1) * barGap)
    local startX = -totalWidth / 2 + barWidth / 2

    for i = 1, #SQUISH_BAR_HEIGHTS do
        local bar = wm:CreateControl(ADDON .. "_SquishBar" .. i, squishTLW, CT_BACKDROP)
        bar:SetDimensions(barWidth, SQUISH_BAR_HEIGHTS[i])
        bar:SetAnchor(BOTTOM, squishTLW, CENTER, startX + (i - 1) * (barWidth + barGap), 20)
        bar:SetEdgeColor(1, 1, 1, 0.5)
        bar:SetEdgeTexture("", 1, 1, 2)
        bar:SetHidden(true)
        squishBars[i] = bar
    end

    ApplySquishDisplayMode()

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

    if squishUnlocked then
        -- mostra sempre o texto placeholder enquanto arrasta, independente do modo
        squishLabel:SetHidden(false)
        squishLabel:SetText("<< >>")
        for i = 1, #squishBars do
            squishBars[i]:SetHidden(true)
        end
    else
        squishLabel:SetText("")
        ApplySquishDisplayMode()
    end

    Msg(squishUnlocked and L.MSG_UNLOCKED or L.MSG_LOCKED)

    if not squishUnlocked then
        squishToken = squishToken + 1
        HideSquishLabel()
    end
end

local function RefreshReticleLabel()
    squishToken = squishToken + 1
    local myToken = squishToken

    if not sv.squishEnabled or squishUnlocked or not DoesUnitExist("reticleover")
            or IsUnitDead("reticleover") then
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

    local litCount = SQUISH_TIER_ORDER[entry.tier] or 3
    for i = 1, #squishBars do
        if i <= litCount then
            squishBars[i]:SetCenterColor(r, g, b, 1)
        else
            squishBars[i]:SetCenterColor(SQUISH_COLOR_UNLIT[1], SQUISH_COLOR_UNLIT[2],
                SQUISH_COLOR_UNLIT[3], SQUISH_COLOR_UNLIT[4])
        end
    end

    squishTLW:SetHidden(false)

    zo_callLater(function()
        if myToken == squishToken then RefreshReticleLabel() end
    end, expireMs - age + 50)
end

-- ---------------------------------------------------------
-- eventos
-- ---------------------------------------------------------

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
    EVENT_MANAGER:UnregisterForEvent(EVENT_NS, EVENT_COMBAT_EVENT)

    if not sv.squishEnabled then return end

    -- sem AddFilterForEvent de proposito: toda a checagem acontece em Lua
    -- dentro de OnSquishCombatEvent (mais robusto contra combinacoes de
    -- filtro que o motor do jogo pode nao aceitar como esperado).
    EVENT_MANAGER:RegisterForEvent(EVENT_NS, EVENT_COMBAT_EVENT, OnSquishCombatEvent)
end

-- ---------------------------------------------------------
-- contrato do modulo
-- ---------------------------------------------------------

function M.Initialize(newSv, newL)
    sv, L, Msg = newSv, newL, FossAlert.Msg

    sv.squishBaselines = sv.squishBaselines or {}
    playerName = NormalizeName(GetUnitName("player"))

    CreateSquishUI()
    ApplySquishPosition()

    EVENT_MANAGER:RegisterForEvent(EVENT_NS, EVENT_RETICLE_TARGET_CHANGED, RefreshReticleLabel)
    EVENT_MANAGER:RegisterForEvent(EVENT_NS, EVENT_UNIT_DEATH_STATE_CHANGED, function(_, unitTag)
        if unitTag == "reticleover" then RefreshReticleLabel() end
    end)

    SyncSquishFilter()
end

function M.SetLocale(newL)
    L = newL
end

function M.BuildPanelOptions()
    return {
        { type = "header", name = L.HDR_SQUISHY },
        { type = "description", text = L.SQUISH_DESC },
        {
            type    = "checkbox",
            name    = L.SQUISH_ENABLE,
            tooltip = L.SQUISH_ENABLE_TT,
            default = M.defaults.squishEnabled,
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
            default  = M.defaults.squishScoreSuperHeavyMax * 100,
            getFunc  = function() return math.floor(sv.squishScoreSuperHeavyMax * 100 + 0.5) end,
            setFunc  = function(v) sv.squishScoreSuperHeavyMax = v / 100 end,
            disabled = function() return not sv.squishEnabled end,
        },
        {
            type     = "slider",
            name     = L.SQUISH_THRESHOLD_HEAVY,
            tooltip  = L.SQUISH_THRESHOLD_HEAVY_TT,
            min      = 50, max = 200, step = 1,
            default  = M.defaults.squishScoreHeavyMax * 100,
            getFunc  = function() return math.floor(sv.squishScoreHeavyMax * 100 + 0.5) end,
            setFunc  = function(v) sv.squishScoreHeavyMax = v / 100 end,
            disabled = function() return not sv.squishEnabled end,
        },
        {
            type     = "slider",
            name     = L.SQUISH_THRESHOLD_MEDIUM,
            tooltip  = L.SQUISH_THRESHOLD_MEDIUM_TT,
            min      = 50, max = 200, step = 1,
            default  = M.defaults.squishScoreMediumMax * 100,
            getFunc  = function() return math.floor(sv.squishScoreMediumMax * 100 + 0.5) end,
            setFunc  = function(v) sv.squishScoreMediumMax = v / 100 end,
            disabled = function() return not sv.squishEnabled end,
        },
        {
            type     = "slider",
            name     = L.SQUISH_THRESHOLD_LIGHT,
            tooltip  = L.SQUISH_THRESHOLD_LIGHT_TT,
            min      = 50, max = 200, step = 1,
            default  = M.defaults.squishScoreLightMax * 100,
            getFunc  = function() return math.floor(sv.squishScoreLightMax * 100 + 0.5) end,
            setFunc  = function(v) sv.squishScoreLightMax = v / 100 end,
            disabled = function() return not sv.squishEnabled end,
        },
        {
            type          = "dropdown",
            name          = L.SQUISH_DISPLAY_MODE,
            tooltip       = L.SQUISH_DISPLAY_MODE_TT,
            choices       = { L.SQUISH_DISPLAY_MODE_TEXT, L.SQUISH_DISPLAY_MODE_BARS },
            choicesValues = { "text", "bars" },
            default       = M.defaults.squishDisplayMode,
            getFunc       = function() return sv.squishDisplayMode end,
            setFunc       = function(v)
                sv.squishDisplayMode = v
                ApplySquishDisplayMode()
            end,
            disabled      = function() return not sv.squishEnabled end,
        },
        {
            type     = "slider",
            name     = L.SQUISH_EXPIRE,
            tooltip  = L.SQUISH_EXPIRE_TT,
            min      = 3, max = 30, step = 1,
            default  = M.defaults.squishExpireSeconds,
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
    }
end

function M.HandleSlashCommand(arg)
    if arg == "squishmove" then
        ToggleSquishUnlock()
        return true
    end
    return false
end
