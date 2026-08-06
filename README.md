# One Versus X

Addon de Elder Scrolls Online com ferramentas pra lutar 1vX em Cyrodiil: alerta de **Petrify / Fossilize / Shattering Rocks**, o **Squishy Detector**, **Trackers** de buff/debuff customizáveis e o **Resolve Reminder**. Começou como um addon só de alerta de roll dodge chamado FossAlert e cresceu pra um kit de sobrevivência solo — daí o nome novo.

## Alerta de Petrify/Fossilize

Avisa quando **Petrify / Fossilize / Shattering Rocks** te acerta, dando tempo de dar roll dodge antes do stun.

Desde a Update 49 essas habilidades não stunam mais na hora. Elas te deixam lento por **1 segundo** (snare de 50% + Minor Breach) e só depois vem o stun de 4 segundos — e esse stun agora **pode ser esquivado**. Esse 1 segundo é o motivo dessa parte do addon existir: o aviso visual do jogo é fácil de perder no meio da briga, então o alerta torna impossível não ver.

---

## Funcionalidades

- Alerta grande na tela no instante em que o efeito te acerta
- Rajada de som repetido (padrão 3x, ~70ms de intervalo) pra destacar do áudio de combate
- **Fica quieto se você já estiver com imunidade de CC** — não queima roll à toa
- Totalmente movível e customizável (texto, tamanho, cor, duração)
- **Squishy Detector**: aprende sozinho a média de dano de cada habilidade e classifica quem você mirar em cinco níveis (de Super Light a Super Heavy), com a cor da etiqueta em gradiente contínuo — verde pra alvo prioritário, vermelho pra tanque — sem precisar configurar nada
- **Trackers**: feature independente que vigia até 5 buffs/debuffs customizados (ex: Minor Mangle) e avisa quando o alvo mirado estiver com eles
- **Resolve Reminder**: mensagenzona na tela, no estilo do alerta de Fossilize, quando você está em combate sem Major Resolve — dispara na hora que cai e repete em intervalos até você reaplicar
- Português e inglês, com detecção automática
- Sniffer de abilityId embutido pra achar IDs novos depois de cada patch

---

## Requisitos

- [LibAddonMenu-2.0](https://www.esoui.com/downloads/info7-LibAddonMenu.html)

---

## Instalação

1. Instale a **LibAddonMenu-2.0** dentro de `AddOns/`
2. Baixe este repositório (botão verde **Code → Download ZIP**, ou pegue o zip da aba [Releases](../../releases))
3. Descompacte e arraste a pasta **`one_versus_x`** de dentro dele para `AddOns/`
4. Reinicie a interface de verdade — saia para a tela de seleção de personagem e volte (`/reloadui` não pega addon novo)

A estrutura tem que ficar assim:

```
Documentos/Elder Scrolls Online/live/AddOns/
├── one_versus_x/
│   ├── one_versus_x.txt
│   ├── Locale.lua
│   ├── FossilizeAlert.lua
│   ├── SquishyDetector.lua
│   ├── Trackers.lua
│   ├── ResolveReminder.lua
│   └── Main.lua
└── LibAddonMenu-2.0/
    └── ...
```

Dois erros clássicos de instalação:

- **Arrastar a pasta errada.** O zip do GitHub vem com uma pasta externa. O que vai para `AddOns/` é a pasta `one_versus_x` que está **dentro** dela — o nome da pasta precisa bater com o nome do arquivo `.txt`, senão o jogo ignora o addon sem dar nenhum aviso.
- **Aninhar a LibAddonMenu.** Ela fica **ao lado** da `one_versus_x`, não dentro dela.

### Já tinha o FossAlert instalado?

Pode apagar a pasta antiga (`FossAlert`) depois de instalar a `one_versus_x`. Não tem migração automática de configurações — o ESO nomeia o arquivo de `SavedVariables` pela identidade da pasta/manifesto do addon, não pelo nome da variável salva, então a versão nova não enxerga o arquivo antigo. Posição das janelas, thresholds e médias aprendidas do Squishy Detector voltam ao padrão e recalibram sozinhas com o uso normal.

---

## Comandos

| Comando | O que faz |
|---|---|
| `/vx` | Abre o painel de configuração |
| `/vx move` | Destrava o alerta pra arrastar, e trava de novo |
| `/vx test` | Dispara o alerta pra conferir posição e som |
| `/vx squishmove` | Destrava a etiqueta do Squishy Detector pra arrastar, e trava de novo |
| `/vx trackermove` | Destrava a lista de trackers pra arrastar, e trava de novo |
| `/vx resolvemove` | Destrava o aviso de Resolve pra arrastar, e trava de novo |
| `/vx resolvetest` | Dispara o aviso de Resolve pra conferir posição |

O resto está no painel: **Settings → Addons → One Versus X**.

### Posicionamento

Rode `/vx move`, feche a janela de configuração, arraste a caixa pra onde quiser e rode `/vx move` de novo pra travar. A posição salva sozinha.

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
5. Adicione na tabela `WATCH` no topo do `FossilizeAlert.lua`
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

## Squishy Detector

Classifica alvos em 5 níveis, do mais esquichy pro mais tanque — **Super
Light, Light, Medium, Heavy, Super Heavy** (os rótulos ficam sempre em inglês,
mesmo com o cliente em português) — com base em quanto cada hit seu se desvia
da sua própria média de dano, e mostra uma etiqueta perto do centro da tela
quando você mira um alvo já classificado. A cor da etiqueta segue um gradiente
contínuo direto do score, não do nível: **verde** nos alvos esquichy
(prioridade de ataque), **vermelho** nos alvos tanque (evite perder tempo
neles).

**Não precisa escolher skill nem calibrar nada.** O addon aprende sozinho: pra
cada habilidade sua (separada por tipo de hit — normal, crítico, tick de DoT),
ele guarda uma média móvel do dano causado. Cada hit novo é comparado com essa
média:

- Hit **acima** da média = o alvo tomou mais dano que o normal → mais esquichy
  (Super Light/Light)
- Hit **abaixo** da média = o alvo mitigou mais que o normal → mais tanque
  (Heavy/Super Heavy)

O score também é ajustado pela **vida máxima do alvo** (o mesmo hit pesa mais
contra alguém com vida baixa do que contra alguém com vida alta), e é
suavizado ao longo de vários hits no mesmo alvo pra não ficar trocando de
categoria a cada hit isolado (crítico, resistido, etc.).

**Como usar:**

1. Ative **Squishy Detector** no painel (`Settings → Addons → One Versus X`)
2. Lute normalmente — os primeiros hits de cada habilidade servem só pra
   aprender a média (são necessárias pelo menos 3 amostras antes do score
   ficar confiável)
3. Mire um alvo que você já bateu: a etiqueta aparece com a cor do momento e
   some sozinha depois do tempo configurado em **"Leitura expira depois de"**
4. Se quiser, ajuste os sliders de score (em %, onde 100% é exatamente a sua
   média aprendida) — os defaults (85/95/105/115%) já vêm calibrados pra fazer
   sentido sem mexer em nada

As médias aprendidas ficam salvas entre sessões (`squishBaselines`), então o
addon fica mais preciso com o tempo em vez de resetar a cada login. O botão
**"Resetar dados"** limpa só as classificações dos alvos atuais (e o cache de
quem já foi confirmado como jogador), não as médias aprendidas.

**Limitações:**

- Só conta dano contra **jogadores inimigos**, nunca NPC — mas pra confirmar
  isso o addon precisa te ver mirando no alvo pelo menos uma vez (usa
  `IsUnitPlayer` no reticulo). Depois de confirmado, ele "lembra" esse nome
  pelo resto da sessão e continua contando os hits mesmo fora da mira — ou
  seja, não dá pra "treinar" batendo num boneco de treino, e o primeiro hit
  num alvo totalmente fora da mira (por exemplo um AOE em alguém que você
  nunca olhou) ainda não conta
- Uma habilidade nova (ou uma que você quase nunca usa) ainda não tem média
  suficiente — os primeiros hits dela contam como neutros (score ~1.0) até
  acumular pelo menos 3 amostras
- O ajuste pela vida do alvo só é possível enquanto você está mirando nele no
  momento do hit — dano em alvo fora da mira usa um fator neutro

---

## Trackers

Feature independente do Squishy Detector — não precisa dele ativado, só do
reticulo. Vigia até 5 nomes de buff/debuff no alvo mirado e, sempre que um
deles estiver ativo, mostra uma etiqueta com o nome numa lista empilhada,
numa janela própria e movível (`/vx trackermove` ou botão no painel).

**Como usar:**

1. Ative **Trackers** no painel (`Settings → Addons → One Versus X` → seção
   Trackers)
2. Preencha "Tracker 1" a "Tracker 5" com o nome exato do buff/debuff que
   quer vigiar (o nome precisa bater com o que aparece no jogo — o client só
   tem inglês). Slot vazio = desativado
3. Mire um alvo que tenha algum deles ativo: a etiqueta aparece na hora

Por padrão o Tracker 1 já vem preenchido com **"Minor Mangle"**; os outros 4
slots começam vazios. A leitura é direto do buff do alvo via
`GetUnitBuffInfo` — não depende de dano, então funciona mesmo sem nunca ter
acertado o alvo.

---

## Resolve Reminder

Mensagenzona na tela, no mesmo estilo visual do alerta de Fossilize, pra
lembrar de manter o **Major Resolve** ativo em combate. Só é relevante
enquanto você está em combate — fora dele fica quieto.

**Como funciona:**

1. Ative **Resolve Reminder** no painel (`Settings → Addons → One Versus X`
   → seção Resolve Reminder)
2. Assim que o Major Resolve cair **em combate**, o aviso dispara na hora
3. Enquanto você continuar em combate sem o buff, o aviso repete no
   intervalo configurado em **"Repetir a cada"** (padrão 5s) — cobre tanto
   quem perdeu o buff no meio da luta quanto quem simplesmente esqueceu de
   aplicar
4. O aviso some assim que você reaplica o Major Resolve ou sai de combate

Texto, fonte, cor e duração na tela são customizáveis igual ao alerta de
Fossilize; a posição é independente e move com `/vx resolvemove` (ou botão
no painel).

---

## Adicionando um idioma

Copie qualquer bloco do `Locale.lua`, troque a chave e traduza os valores. O dropdown de idioma se monta sozinho a partir dessa tabela, então você nunca precisa mexer nos outros arquivos `.lua`.

```lua
one_versus_x.STRINGS = {
    en = { LANG_NAME = "English", ... },
    pt = { LANG_NAME = "Português", ... },
    -- seu idioma aqui
}
```

Todas as chaves precisam existir em todos os blocos.

---

## Limitações conhecidas

**O addon não rola por você.** Isso é de propósito e não tem contorno: a API Lua do ESO não expõe nenhuma forma de gerar input de combate, e automatizar por fora viola os termos de uso. O addon avisa; você decide. E é melhor assim — rolar automático em todo Fossilize te deixa previsível e queima stamina que um adversário decente vai adorar baitar.

**Não dá pra usar som personalizado.** A API só toca sons que já vêm no jogo (a tabela `SOUNDS`). É limitação do cliente, não descuido.

**A imunidade de CC rastreada é a sua.** É isso que suprime alerta falso, e funciona de forma confiável. Ler a imunidade de um *player inimigo* não dá: testado via `EVENT_EFFECT_CHANGED`/`GetUnitBuffInfo` filtrado em `"reticleover"`, o buff de CC Immunity (id 28301) nunca aparece pra alvos que não são você — o servidor não replica esse dado pros outros clientes. O indicador nativo do jogo (o ícone quebrado sobre a barra do alvo) deve vir de um cálculo interno não exposto via addon. O Bandits UI bateu na mesma parede — tem um bloco de detecção disso no código deles, comentado e desativado.

---

## Ideias pro futuro

- [ ] Detectar o cast em vez do efeito já aplicado, pra ganhar tempo de reação
- [ ] Flash na tela inteira como alternativa ao texto central (pega melhor a visão periférica)
- [ ] Aviso de ID duplicado na tabela `WATCH`
- [ ] Cor e tamanho de fonte configuráveis pra etiqueta do Squishy Detector
- [ ] Comando pra ver as médias aprendidas do Squishy Detector (hoje só dá pra ver ligando o sniffer)

---

## Licença

MIT

Sem nenhuma afiliação com a ZeniMax Online Studios. The Elder Scrolls® Online é marca registrada da ZeniMax Media Inc.
