-- One Versus X v2.0
-- Composition root: cria SavedVars/locale, inicializa os modulos de feature
-- (FossilizeAlert, SquishyDetector, Trackers), monta o painel e roteia o
-- slash command.
--
-- Configuracao: /vx  (ou Settings > Addons > One Versus X)
-- Textos ficam em Locale.lua

one_versus_x = one_versus_x or {}

local ADDON       = "one_versus_x"
local DISPLAY_NAME = "One Versus X"

local sv, L, panelRef

local function Msg(s)
    d("|cffaa33[" .. DISPLAY_NAME .. "]|r " .. s)
end
one_versus_x.Msg = Msg

local function ResolveLocale()
    local code = sv and sv.locale or "auto"

    if code == "auto" then
        -- ESO nao tem cliente em portugues, entao "auto" cai em ingles
        -- para qualquer um que nao tenha escolhido pt na mao.
        code = GetCVar("Language.2") or "en"
    end

    return one_versus_x.STRINGS[code] or one_versus_x.STRINGS.en
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
        name                = DISPLAY_NAME,
        displayName         = "|cffaa33" .. DISPLAY_NAME .. "|r",
        author              = "Kaue",
        version             = "2.0",
        registerForRefresh  = true,
        registerForDefaults = true,
    })

    -- monta a lista de idiomas a partir da propria tabela de strings
    local langValues = { "auto" }
    local langLabels = { L.LANG_AUTO }
    for code, tbl in pairs(one_versus_x.STRINGS) do
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
                one_versus_x.FossilizeAlert.SetLocale(L)
                one_versus_x.SquishyDetector.SetLocale(L)
                one_versus_x.Trackers.SetLocale(L)
                one_versus_x.ResolveReminder.SetLocale(L)
                Msg(L.MSG_NEEDS_RELOAD)
            end,
        },
    }

    AppendAll(options, one_versus_x.FossilizeAlert.BuildPanelOptions())
    AppendAll(options, one_versus_x.SquishyDetector.BuildPanelOptions())
    AppendAll(options, one_versus_x.Trackers.BuildPanelOptions())
    AppendAll(options, one_versus_x.ResolveReminder.BuildPanelOptions())

    table.insert(options, { type = "header", name = L.HDR_DEBUG })
    table.insert(options, {
        type    = "checkbox",
        name    = L.SNIFFER,
        tooltip = L.SNIFFER_TT,
        default = false,
        getFunc = function() return sv.sniffing end,
        setFunc = function(v) sv.sniffing = v end,
    })
    AppendAll(options, one_versus_x.FossilizeAlert.BuildDebugOptions())

    regControls(LAM, ADDON .. "_Panel", options)
end

-- ---------------------------------------------------------

local function OnLoaded(_, addonName)
    if addonName ~= ADDON then return end
    EVENT_MANAGER:UnregisterForEvent(ADDON, EVENT_ADD_ON_LOADED)

    local defaults = { locale = "auto", sniffing = false }
    MergeDefaultsInto(defaults, one_versus_x.FossilizeAlert.defaults)
    MergeDefaultsInto(defaults, one_versus_x.SquishyDetector.defaults)
    MergeDefaultsInto(defaults, one_versus_x.Trackers.defaults)
    MergeDefaultsInto(defaults, one_versus_x.ResolveReminder.defaults)

    sv = ZO_SavedVars:NewAccountWide("one_versus_xSV", 1, nil, defaults)
    L  = ResolveLocale()

    one_versus_x.FossilizeAlert.Initialize(sv, L)
    one_versus_x.SquishyDetector.Initialize(sv, L)
    one_versus_x.Trackers.Initialize(sv, L)
    one_versus_x.ResolveReminder.Initialize(sv, L)

    BuildMenu()

    SLASH_COMMANDS["/vx"] = function(args)
        args = (args or ""):lower()
        local LAM = GetLAM()
        if one_versus_x.FossilizeAlert.HandleSlashCommand(args) then
            return
        elseif one_versus_x.SquishyDetector.HandleSlashCommand(args) then
            return
        elseif one_versus_x.Trackers.HandleSlashCommand(args) then
            return
        elseif one_versus_x.ResolveReminder.HandleSlashCommand(args) then
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
