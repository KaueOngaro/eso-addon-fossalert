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
        HDR_SQUISHY     = "Squishy Detector",
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

        -- squishy detector
        SQUISH_DESC     = "Learns the average damage of every ability you use against enemy " ..
                          "players, then scores each new hit against that learned average " ..
                          "(adjusted for the target's max health). No skill to pick, no manual " ..
                          "calibration -- it gets more accurate the more you fight. Shows a " ..
                          "colored label near the reticle when you aim at a target with a " ..
                          "recent reading.",
        SQUISH_ENABLE   = "Enable Squishy Detector",
        SQUISH_ENABLE_TT= "Turns on damage tracking for all your abilities and the label near the reticle.",
        SQUISH_THRESHOLD_SUPERHEAVY  = "Super Heavy max score (%)",
        SQUISH_THRESHOLD_SUPERHEAVY_TT = "Score below this classifies the target as Super Heavy (extremely " ..
                          "tanky, avoid wasting time on them). 100% = exactly your learned average.",
        SQUISH_THRESHOLD_HEAVY  = "Heavy max score (%)",
        SQUISH_THRESHOLD_HEAVY_TT = "Score below this (and at/above Super Heavy max) classifies as Heavy.",
        SQUISH_THRESHOLD_MEDIUM = "Medium max score (%)",
        SQUISH_THRESHOLD_MEDIUM_TT = "Score below this (and at/above Heavy max) classifies as Medium.",
        SQUISH_THRESHOLD_LIGHT  = "Light max score (%)",
        SQUISH_THRESHOLD_LIGHT_TT = "Score below this (and at/above Medium max) classifies as Light. " ..
                          "Anything at or above it is Super Light (priority target). The label's color " ..
                          "also follows a red (Super Heavy) to green (Super Light) gradient based on the " ..
                          "exact score, not just the tier. Keep Super Heavy max < Heavy max < Medium max < Light max.",
        SQUISH_DISPLAY_MODE = "Display mode",
        SQUISH_DISPLAY_MODE_TT = "Text shows the tier name (SUPER LIGHT, LIGHT, etc). Bars shows a 5-segment " ..
                          "signal-strength style meter next to the reticle instead (like a ping/signal " ..
                          "indicator), using the same color gradient, without text.",
        SQUISH_DISPLAY_MODE_TEXT = "Text",
        SQUISH_DISPLAY_MODE_BARS = "Colored bars",
        SQUISH_EXPIRE   = "Reading expires after (s)",
        SQUISH_EXPIRE_TT= "How long a target's classification stays valid without a new hit.",
        BTN_SQUISH_MOVE = "Move label",
        BTN_SQUISH_MOVE_TT = "Unlocks the squishy label so you can drag it. Close settings after clicking.",
        BTN_SQUISH_RESET= "Reset data",
        SQUISH_TIER     = {
            superlight = "SUPER LIGHT",
            light      = "LIGHT",
            medium     = "MEDIUM",
            heavy      = "HEAVY",
            superheavy = "SUPER HEAVY",
        },

        -- mensagens de chat
        MSG_LOADED      = "v1.1 loaded. Type /foss to open settings.",
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
        MSG_CMDS        = "commands: /foss move | /foss test | /foss squishmove",
        MSG_SQUISH_RESET= "squishy data reset",
        MSG_SQUISH_HIT  = "[squish] %s: %d dmg (%s)",
    },

    pt = {
        LANG_NAME       = "Português",

        DESC            = "Avisa na tela quando um Fossilize/Petrify te acerta, " ..
                          "dando tempo de rolar antes do stun. Fica quieto se você já " ..
                          "estiver com imunidade de CC.",

        HDR_GENERAL     = "Geral",
        HDR_APPEARANCE  = "Aparência",
        HDR_SOUND       = "Som",
        HDR_SQUISHY     = "Squishy Detector",
        HDR_DEBUG       = "Debug",

        LANGUAGE        = "Idioma",
        LANGUAGE_TT     = "Trocar o idioma exige um reload da interface pra valer.",
        LANG_AUTO       = "Automático (idioma do cliente)",

        ALERT_TEXT      = "Texto do alerta",
        ALERT_TEXT_TT   = "O que aparece na tela quando o efeito te acerta.",
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
        SNIFFER_TT      = "Printa no chat todo efeito aplicado em você, com o ID. " ..
                          "Use pra descobrir IDs novos. Deixe DESLIGADO no dia a dia.",

        BTN_IMMUNE      = "Ver estado da imunidade",

        -- squishy detector
        SQUISH_DESC     = "Aprende sozinho a média de dano de cada habilidade que você usa " ..
                          "em jogadores inimigos, e classifica cada hit novo comparando com " ..
                          "essa média aprendida (ajustada pela vida máxima do alvo). Sem " ..
                          "escolher skill, sem calibrar na mão -- fica mais preciso quanto " ..
                          "mais você luta. Mostra uma etiqueta colorida perto do reticulo " ..
                          "quando você mira um alvo com leitura recente.",
        SQUISH_ENABLE   = "Ativar Squishy Detector",
        SQUISH_ENABLE_TT= "Liga o rastreamento de dano de todas as suas habilidades e a etiqueta perto do reticulo.",
        SQUISH_THRESHOLD_SUPERHEAVY  = "Score máx. Super Heavy (%)",
        SQUISH_THRESHOLD_SUPERHEAVY_TT = "Score abaixo disso classifica o alvo como Super Heavy (tanque " ..
                          "extremo, evite perder tempo nele). 100% = exatamente a sua média aprendida.",
        SQUISH_THRESHOLD_HEAVY  = "Score máx. Heavy (%)",
        SQUISH_THRESHOLD_HEAVY_TT = "Score abaixo disso (e igual/acima do máx. Super Heavy) classifica como Heavy.",
        SQUISH_THRESHOLD_MEDIUM = "Score máx. Medium (%)",
        SQUISH_THRESHOLD_MEDIUM_TT = "Score abaixo disso (e igual/acima do máx. Heavy) classifica como Medium.",
        SQUISH_THRESHOLD_LIGHT  = "Score máx. Light (%)",
        SQUISH_THRESHOLD_LIGHT_TT = "Score abaixo disso (e igual/acima do máx. Medium) classifica como Light. " ..
                          "Igual ou acima disso vira Super Light (alvo prioritário). A cor da etiqueta " ..
                          "também segue um gradiente vermelho (Super Heavy) até verde (Super Light) direto " ..
                          "pelo score, não só pelo nível. Mantenha máx. Super Heavy < máx. Heavy < máx. Medium < máx. Light.",
        SQUISH_DISPLAY_MODE = "Modo de exibição",
        SQUISH_DISPLAY_MODE_TT = "Texto mostra o nome do nível (SUPER LIGHT, LIGHT, etc). Barrinhas mostra " ..
                          "um medidor de 5 barras tipo sinal de celular/ping do lado do reticulo em vez " ..
                          "disso, com o mesmo gradiente de cor, sem texto.",
        SQUISH_DISPLAY_MODE_TEXT = "Texto",
        SQUISH_DISPLAY_MODE_BARS = "Barrinhas coloridas",
        SQUISH_EXPIRE   = "Leitura expira depois de (s)",
        SQUISH_EXPIRE_TT= "Quanto tempo a classificação de um alvo continua válida sem novo hit.",
        BTN_SQUISH_MOVE = "Mover etiqueta",
        BTN_SQUISH_MOVE_TT = "Destrava a etiqueta pra arrastar. Feche as opções depois de clicar.",
        BTN_SQUISH_RESET= "Resetar dados",
        SQUISH_TIER     = {
            superlight = "SUPER LIGHT",
            light      = "LIGHT",
            medium     = "MEDIUM",
            heavy      = "HEAVY",
            superheavy = "SUPER HEAVY",
        },

        MSG_LOADED      = "v1.1 carregado. Digite /foss pra abrir as opções.",
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
        MSG_CMDS        = "comandos: /foss move | /foss test | /foss squishmove",
        MSG_SQUISH_RESET= "dados do squishy resetados",
        MSG_SQUISH_HIT  = "[squish] %s: %d dano (%s)",
    },
}
