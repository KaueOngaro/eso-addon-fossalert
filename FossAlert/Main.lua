-- FossAlert v1.1
-- Composition root: cria SavedVars/locale, inicializa os modulos de feature
-- (FossilizeAlert, SquishyDetector, Trackers), monta o painel e roteia o
-- slash command.
--
-- Configuracao: /foss  (ou Settings > Addons > FossAlert)
-- Textos ficam em Locale.lua

FossAlert = FossAlert or {}

local ADDON = "FossAlert"

local sv, L, panelRef

local function Msg(s)
    d("|cffaa33[FossAlert]|r " .. s)
end
FossAlert.Msg = Msg

local function ResolveLocale()
    local code = sv and sv.locale or "auto"

    if code == "auto" then
        -- ESO nao tem cliente em portugues, entao "auto" cai em ingles
        -- para qualquer um que nao tenha escolhido pt na mao.
        code = GetCVar("Language.2") or "en"
    end

    return FossAlert.STRINGS[code] or FossAlert.STRINGS.en
end

local function GetLAM()
    if LibAddonMenu2 then return LibAddonMenu2 end
    if LibStub then
        local ok, lib = pcall(LibStub, "LibAddonMenu-2.0")
        if ok and lib then return lib end
    end
    return nil
end

local function MergeDefaultsInto(target, source)
    for k, v in pairs(source) do target[k] = v end
end

local function AppendAll(target, source)
    for _, v in ipairs(source) do table.insert(target, v) end
end

-- ---------------------------------------------------------
-- painel LibAddonMenu-2.0
-- ---------------------------------------------------------

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
            default       = "auto",
            getFunc       = function() return sv.locale end,
            setFunc       = function(v)
                sv.locale = v
                L = ResolveLocale()
                FossAlert.FossilizeAlert.SetLocale(L)
                FossAlert.SquishyDetector.SetLocale(L)
                FossAlert.Trackers.SetLocale(L)
                Msg(L.MSG_NEEDS_RELOAD)
            end,
        },
    }

    AppendAll(options, FossAlert.FossilizeAlert.BuildPanelOptions())
    AppendAll(options, FossAlert.SquishyDetector.BuildPanelOptions())
    AppendAll(options, FossAlert.Trackers.BuildPanelOptions())

    table.insert(options, { type = "header", name = L.HDR_DEBUG })
    table.insert(options, {
        type    = "checkbox",
        name    = L.SNIFFER,
        tooltip = L.SNIFFER_TT,
        default = false,
        getFunc = function() return sv.sniffing end,
        setFunc = function(v) sv.sniffing = v end,
    })
    AppendAll(options, FossAlert.FossilizeAlert.BuildDebugOptions())

    regControls(LAM, ADDON .. "_Panel", options)
end

-- ---------------------------------------------------------

local function OnLoaded(_, addonName)
    if addonName ~= ADDON then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_ADD_ON_LOADED)

    local defaults = { locale = "auto", sniffing = false }
    MergeDefaultsInto(defaults, FossAlert.FossilizeAlert.defaults)
    MergeDefaultsInto(defaults, FossAlert.SquishyDetector.defaults)
    MergeDefaultsInto(defaults, FossAlert.Trackers.defaults)

    sv = ZO_SavedVars:NewAccountWide("FossAlertSV", 1, nil, defaults)
    L  = ResolveLocale()

    FossAlert.FossilizeAlert.Initialize(sv, L)
    FossAlert.SquishyDetector.Initialize(sv, L)
    FossAlert.Trackers.Initialize(sv, L)

    BuildMenu()

    SLASH_COMMANDS["/foss"] = function(args)
        args = (args or ""):lower()
        local LAM = GetLAM()
        if FossAlert.FossilizeAlert.HandleSlashCommand(args) then
            return
        elseif FossAlert.SquishyDetector.HandleSlashCommand(args) then
            return
        elseif FossAlert.Trackers.HandleSlashCommand(args) then
            return
        elseif panelRef and LAM and LAM.OpenToPanel then
            LAM:OpenToPanel(panelRef)
        else
            Msg(L.MSG_CMDS)
        end
    end

    Msg(L.MSG_LOADED)
end

EVENT_MANAGER:RegisterForEvent(ADDON, EVENT_ADD_ON_LOADED, OnLoaded)
