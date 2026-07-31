-- FossAlert - textos / strings
--
-- Para adicionar um idioma novo, copie um bloco inteiro e traduza.
-- As chaves precisam ser identicas entre os idiomas.

FossAlert = FossAlert or {}

FossAlert.STRINGS = {

    en = {
        LANG_NAME       = "English",

        DESC            = "Warns you on screen when a Fossilize/Petrify lands on you, " ..
                          "giving you time to roll before the stun. Stays quiet if you " ..
                          "already have CC immunity.",

        HDR_GENERAL     = "General",
        HDR_APPEARANCE  = "Appearance",
        HDR_SOUND       = "Sound",
        HDR_DEBUG       = "Debug",

        LANGUAGE        = "Language",
        LANGUAGE_TT     = "Changing the language requires a UI reload to take effect.",
        LANG_AUTO       = "Auto (client language)",

        ALERT_TEXT      = "Alert text",
        ALERT_TEXT_TT   = "What shows up on screen when the effect lands.",
        DEFAULT_ALERT   = "ROLL!",

        FONT_SIZE       = "Font size",
        TEXT_COLOR      = "Text color",

        DURATION        = "On-screen duration (ms)",
        DURATION_TT     = "Only affects how long the text stays visible, not detection. " ..
                          "The real window to roll is 1000ms.",

        BTN_MOVE        = "Move alert",
        BTN_MOVE_TT     = "Unlocks the alert so you can drag it. Close settings after clicking.",
        BTN_TEST        = "Test",

        PLAY_SOUND      = "Play sound",
        ALERT_SOUND     = "Alert sound",
        SOUND_REPEAT    = "Repeats",
        SOUND_REPEAT_TT = "How many times the sound fires. Repeating it makes the alert " ..
                          "stand out from the game's own audio.",
        SOUND_GAP       = "Gap between repeats (ms)",
        SOUND_GAP_TT    = "Shorter = tighter burst. If the sound you picked is long, " ..
                          "a short gap will just smear them together.",

        SNIFFER         = "AbilityId sniffer",
        SNIFFER_TT      = "Prints every effect that lands on you, with its ID. " ..
                          "Use it to find new IDs. Keep it OFF during normal play.",

        BTN_IMMUNE      = "Check CC immunity state",

        -- mensagens de chat
        MSG_LOADED      = "v1.0 loaded. Type /foss to open settings.",
        MSG_POS_SAVED   = "position saved (%d, %d)",
        MSG_UNLOCKED    = "UNLOCKED - close settings and drag it where you want",
        MSG_LOCKED      = "locked",
        MSG_IMMUNE_YES  = "IMMUNE for another %dms",
        MSG_IMMUNE_NO   = "not immune",
        MSG_IMM_ON      = "immunity ON (%dms)",
        MSG_IMM_OFF     = "immunity OFF",
        MSG_NEEDS_RELOAD= "Language changed. Type /reloadui to apply it to the menu.",
        MSG_NO_LAM      = "LibAddonMenu-2.0 not found. The addon still works, but there is no options panel.",
        MSG_BAD_LAM     = "Incompatible LibAddonMenu. Run this in chat:",
        MSG_CMDS        = "commands: /foss move | /foss test",
    },

    pt = {
        LANG_NAME       = "Português",

        DESC            = "Avisa na tela quando um Fossilize/Petrify entra em você, " ..
                          "dando tempo de rolar antes do stun. Fica quieto se você já " ..
                          "estiver com imunidade de CC.",

        HDR_GENERAL     = "Geral",
        HDR_APPEARANCE  = "Aparência",
        HDR_SOUND       = "Som",
        HDR_DEBUG       = "Debug",

        LANGUAGE        = "Idioma",
        LANGUAGE_TT     = "Trocar o idioma exige um reload da interface pra valer.",
        LANG_AUTO       = "Automático (idioma do cliente)",

        ALERT_TEXT      = "Texto do alerta",
        ALERT_TEXT_TT   = "O que aparece na tela quando o efeito entra.",
        DEFAULT_ALERT   = "ROLA!",

        FONT_SIZE       = "Tamanho da fonte",
        TEXT_COLOR      = "Cor do texto",

        DURATION        = "Duração na tela (ms)",
        DURATION_TT     = "Só afeta quanto tempo o texto fica visível, não a detecção. " ..
                          "A janela real pra rolar é 1000ms.",

        BTN_MOVE        = "Mover alerta",
        BTN_MOVE_TT     = "Destrava o alerta pra arrastar. Feche as opções depois de clicar.",
        BTN_TEST        = "Testar",

        PLAY_SOUND      = "Tocar som",
        ALERT_SOUND     = "Som do alerta",
        SOUND_REPEAT    = "Repetições",
        SOUND_REPEAT_TT = "Quantas vezes o som dispara. Repetir faz o alerta destacar " ..
                          "do áudio normal do jogo.",
        SOUND_GAP       = "Intervalo entre repetições (ms)",
        SOUND_GAP_TT    = "Menor = rajada mais seca. Se o som escolhido for longo, " ..
                          "intervalo curto só embola tudo.",

        SNIFFER         = "Sniffer de abilityId",
        SNIFFER_TT      = "Printa no chat todo efeito que entra em você, com o ID. " ..
                          "Use pra descobrir IDs novos. Deixe DESLIGADO no dia a dia.",

        BTN_IMMUNE      = "Ver estado da imunidade",

        MSG_LOADED      = "v1.0 carregado. Digite /foss pra abrir as opções.",
        MSG_POS_SAVED   = "posição salva (%d, %d)",
        MSG_UNLOCKED    = "DESTRAVADO - feche as opções e arraste onde quiser",
        MSG_LOCKED      = "travado",
        MSG_IMMUNE_YES  = "IMUNE por mais %dms",
        MSG_IMMUNE_NO   = "não está imune",
        MSG_IMM_ON      = "imunidade ON (%dms)",
        MSG_IMM_OFF     = "imunidade OFF",
        MSG_NEEDS_RELOAD= "Idioma alterado. Digite /reloadui pra aplicar no menu.",
        MSG_NO_LAM      = "LibAddonMenu-2.0 não encontrada. O addon funciona, mas sem painel de opções.",
        MSG_BAD_LAM     = "LibAddonMenu incompatível. Rode isso no chat:",
        MSG_CMDS        = "comandos: /foss move | /foss test",
    },
}
