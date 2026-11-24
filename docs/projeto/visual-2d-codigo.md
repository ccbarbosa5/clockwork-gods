# Pacote 7 — salto visual em 2D (Código)

Publicado no PR #37 (12 nov. 2026); PR #38 tirou o anel do time e aumentou os sprites 12%. O protótipo 3D foi cancelado. Capturas: `docs/capturas/visual-2d/`.

## O que mudou na tela
- **Animação procedural** (todos os heróis; `scripts/hero.gd`):
  - ao andar: balança para os lados e achata/estica no sentido do movimento;
  - ao atacar: avanço curto (0,16 s);
  - ao levar dano: recuo na direção do golpe e clarão branco;
  - ao usar habilidade: pulinho (0,3 s);
  - ao cair: o corpo cresce, clareia e some, soltando peças de bronze;
  - ao renascer: cresce de 60% a 100%, com coluna de luz e anel na cor do time.
- **Impacto:**
  - tremor de tela leve só em ultimates (5 px) e Investida (3 px), com o HUD parado;
  - faíscas em cada acerto;
  - números de dano e cura maiores, com contorno, um por herói: acertos seguidos em até 0,6 s somam num número só, por no máximo ~1,2 s.
- **HUD mais limpo:**
  - registro de habilidades com no máximo 3 linhas, letra menor, sumindo em 4 s;
  - avisos (ultimate inimiga, ponto liberado, prorrogação) numa faixa curta no topo da arena;
  - menos anéis: ultimate pronta só no HUD; lentidão vira arco azul embaixo; reforço do próximo básico vira 3 brilhos dourados.
- **Ambiente:** sombra suave em degradê sob os heróis (com tom da cor do time desde o PR #38; encolhe quando o corpo sobe) e escurecimento leve nas bordas da arena.
- **Sorteios:** os efeitos visuais usam um gerador de números próprio, então a partida e a simulação sorteiam igual com ou sem eles.

## Animação por peças (`scripts/rig.gd`)
- Cada herói pode ter camadas em `assets/heroes/camadas/`, 256 × 256, mesmo enquadramento do sprite inteiro, cada uma com um pivô. As poses são funções do estado do herói (parado, andando, ataque, Muralha, dano, ultimate), então rodam iguais no jogo, nos testes e na web.
- **Fallback:** faltando qualquer camada, o herói usa o sprite inteiro.
- **Talos** (pivôs de docs/projeto/animacao-2d.md): parado respira 100–102%; andando, braço do escudo ±8° e o do soco vai e volta 4 px; soco avança até 14 px; Muralha de Bronze gira o escudo +25° e 6 px à frente; dano abre os braços; chaminés pulsam (mais forte depois da ultimate).
- **Situação das camadas:** em `D:\Ichor\assets\em-revisao\heroes\camadas\`, ainda não aprovadas. O jogo publicado usa o sprite inteiro do Talos. A prévia `docs/capturas/visual-2d/talos_camadas_previa.gif` foi gerada com elas. Quando forem aprovadas (`D:\Ichor\assets\aprovados\heroes\camadas\`), basta copiá-las para `assets/heroes/camadas/` e publicar.
- **Outro herói:** acrescentar as camadas em `RIGS` (rig.gd) e as poses em `pose()`.

## Capturas (`docs/capturas/visual-2d/`)
- `antes_20s/45s/70s.png` e `depois_20s/45s/70s.png`; `luta.gif` (4 s entre bots); `talos_camadas_previa.gif`.
- Ferramenta: `tools/visual_capture.gd` (modos `luta` e `talos`).
