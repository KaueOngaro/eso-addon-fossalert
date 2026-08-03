# Changelog

## 1.1
- Squishy Detector: aprende sozinho a média de dano de cada habilidade sua e classifica alvos mirados em 5 níveis (Super Light/Light/Medium/Heavy/Super Heavy, sempre em inglês) com base no desvio dessa média, ajustado pela vida do alvo
- Cor da etiqueta em gradiente contínuo verde→vermelho direto pelo score, não só por nível
- Etiqueta colorida perto do reticulo, movível via `/foss squishmove` ou botão no painel
- Sliders de score (%) e tempo de expiração da leitura configuráveis no painel
- Médias aprendidas por habilidade persistem entre sessões
- Modo de exibição configurável: texto (nível) ou barrinhas coloridas tipo medidor de sinal — quanto mais barra acesa (e mais vermelha), mais mitigação o alvo tem
- Etiqueta/barrinhas somem na hora se o alvo mirado morrer
- Trackers: feature independente (arquivo e seção de painel próprios) que vigia até 5 nomes de buff/debuff no alvo mirado, com aviso numa janela própria e movível (`/foss trackermove`) — vem com "Minor Mangle" cadastrado por padrão no slot 1
- Refactor: addon dividido em módulos por feature (`FossilizeAlert.lua`, `SquishyDetector.lua`, `Trackers.lua`) com `Main.lua` como composition root

## 1.0
- Alerta na tela quando Petrify / Fossilize / Shattering Rocks te acerta
- Rajada de som configurável (repetições e intervalo)
- Suprime o alerta quando você já está com imunidade de CC
- Painel de configuração via LibAddonMenu-2.0
- Português e inglês, com detecção automática do idioma do cliente
- Sniffer de abilityId embutido
- Arquivos do addon movidos para a subpasta `FossAlert/`
