# FossAlert

Addon de Elder Scrolls Online que avisa quando **Petrify / Fossilize / Shattering Rocks** entra em você, dando tempo de dar roll dodge antes do stun.

Desde a Update 49 essas habilidades não stunam mais na hora. Elas te encasulam por **1 segundo** (snare de 50% + Minor Breach) e só depois vem o stun de 4 segundos — e esse stun agora **pode ser esquivado**. Esse 1 segundo é o motivo do addon existir: o aviso visual do jogo é fácil de perder no meio da briga, então o FossAlert torna impossível não ver.

---

## Funcionalidades

- Alerta grande na tela no instante em que o efeito entra
- Rajada de som repetido (padrão 3x, ~70ms de intervalo) pra destacar do áudio de combate
- **Fica quieto se você já estiver com imunidade de CC** — não queima roll à toa
- Totalmente movível e customizável (texto, tamanho, cor, duração)
- Português e inglês, com detecção automática
- Sniffer de abilityId embutido pra achar IDs novos depois de cada patch

---

## Requisitos

- [LibAddonMenu-2.0](https://www.esoui.com/downloads/info7-LibAddonMenu.html)

---

## Instalação

1. Instale a **LibAddonMenu-2.0** dentro de `AddOns/`
2. Baixe este repositório (botão verde **Code → Download ZIP**, ou pegue o zip da aba [Releases](../../releases))
3. Descompacte e arraste a pasta **`FossAlert`** de dentro dele para `AddOns/`
4. Reinicie a interface de verdade — saia para a tela de seleção de personagem e volte (`/reloadui` não pega addon novo)

A estrutura tem que ficar assim:

```
Documentos/Elder Scrolls Online/live/AddOns/
├── FossAlert/
│   ├── FossAlert.txt
│   ├── Locale.lua
│   └── FossAlert.lua
└── LibAddonMenu-2.0/
    └── ...
```

Dois erros clássicos de instalação:

- **Arrastar a pasta errada.** O zip do GitHub vem com uma pasta externa chamada `eso-addon-fossalert-main`. O que vai para `AddOns/` é a pasta `FossAlert` que está **dentro** dela — o nome da pasta precisa bater com o nome do arquivo `.txt`, senão o jogo ignora o addon sem dar nenhum aviso.
- **Aninhar a LibAddonMenu.** Ela fica **ao lado** da `FossAlert`, não dentro dela.

---

## Comandos

| Comando | O que faz |
|---|---|
| `/foss` | Abre o painel de configuração |
| `/foss move` | Destrava o alerta pra arrastar, e trava de novo |
| `/foss test` | Dispara o alerta pra conferir posição e som |

O resto está no painel: **Settings → Addons → FossAlert**.

### Posicionamento

Rode `/foss move`, feche a janela de configuração, arraste a caixa pra onde quiser e rode `/foss move` de novo pra travar. A posição salva sozinha.

O alerta não dispara enquanto estiver destravado — lembre de travar antes de ir pra Cyrodiil.

---

## Notas de configuração

**Texto do alerta** começa vazio, o que significa "usar o padrão do idioma" (`ROLA!` em português, `ROLL!` em inglês). Se você escrever qualquer coisa, vira fixo e ignora o idioma.

**Duração na tela** controla só quanto tempo o texto fica visível, não afeta a detecção. A janela real pra reagir é 1000ms. Valores menores (600–800ms) incomodam menos — o que importa é o *instante* que ele aparece, não quanto tempo fica lá.

**Repetições de som** vêm em 3 com intervalo de 70ms. Sons curtos de UI ficam ótimos assim apertado. Sons mais encorpados tipo `DUEL_START` embolam — suba o intervalo pra 120–150ms nesses casos.

**Trocar o idioma** exige `/reloadui` pra atualizar os textos do painel. O addon avisa isso no chat na hora que você troca.

---

## Achando ability IDs

Os IDs mudam entre patches. Se o addon parar de disparar depois de uma atualização, é só sniffar de novo:

1. Ligue o **Sniffer de abilityId** no painel (seção Debug)
2. Tome a habilidade algumas vezes — duelo é o ideal, porque Cyrodiil inunda o log
3. Todo efeito que entrar em você aparece no chat com o ID
4. O **primeiro** ID da sequência é o encase, que é o gatilho
5. Adicione na tabela `WATCH` no topo do `FossAlert.lua`
6. `/reloadui` e desligue o sniffer

```lua
local WATCH = {
    [32678] = "1",
    [32685] = "2",
    [29037] = "3",
}
```

O texto do lado é só rótulo — não aparece em lugar nenhum, serve pra você se lembrar de qual é qual.

Cuidado com chave duplicada — o Lua sobrescreve calado em vez de dar erro, então um erro de copiar e colar faz uma entrada sumir sem nenhum aviso.

---

## Adicionando um idioma

Copie qualquer bloco do `Locale.lua`, troque a chave e traduza os valores. O dropdown de idioma se monta sozinho a partir dessa tabela, então você nunca precisa mexer no `FossAlert.lua`.

```lua
FossAlert.STRINGS = {
    en = { LANG_NAME = "English", ... },
    pt = { LANG_NAME = "Português", ... },
    -- seu idioma aqui
}
```

Todas as chaves precisam existir em todos os blocos.

---

## Limitações conhecidas

**O addon não rola por você.** Isso é de propósito e não tem contorno: a API Lua do ESO não expõe nenhuma forma de gerar input de combate, e automatizar por fora viola os termos de uso. O FossAlert avisa; você decide. E é melhor assim — rolar automático em todo Fossilize te deixa previsível e queima stamina que um adversário decente vai adorar baitar.

**Não dá pra usar som personalizado.** A API só toca sons que já vêm no jogo (a tabela `SOUNDS`). É limitação do cliente, não descuido.

**A imunidade de CC rastreada é a sua.** É isso que suprime alerta falso, e funciona de forma confiável. Ler a imunidade de um *player inimigo* não dá: testado via `EVENT_EFFECT_CHANGED`/`GetUnitBuffInfo` filtrado em `"reticleover"`, o buff de CC Immunity (id 28301) nunca aparece pra alvos que não são você — o servidor não replica esse dado pros outros clientes. O indicador nativo do jogo (o ícone quebrado sobre a barra do alvo) deve vir de um cálculo interno não exposto via addon. O Bandits UI bateu na mesma parede — tem um bloco de detecção disso no código deles, comentado e desativado.

---

## Ideias pro futuro

- [ ] Detectar o cast em vez do efeito já aplicado, pra ganhar tempo de reação
- [ ] Flash na tela inteira como alternativa ao texto central (pega melhor a visão periférica)
- [ ] Aviso de ID duplicado na tabela `WATCH`

---

## Licença

MIT

Sem nenhuma afiliação com a ZeniMax Online Studios. The Elder Scrolls® Online é marca registrada da ZeniMax Media Inc.
