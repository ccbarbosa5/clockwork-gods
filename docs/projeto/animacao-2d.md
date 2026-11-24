# Animação 2D por camadas (Pacote 7)

Atualizado em 12 nov. 2026. Como o código usa: docs/projeto/visual-2d-codigo.md.

## Talos: sprite visto de cima em 4 camadas

Base: `heroes/talos_top.png` (256 × 256, virado para a direita, centro do corpo em (128, 128)).
Arquivos em `heroes/camadas/` (em revisão em `D:\Ichor\assets\em-revisao\heroes\camadas\`; depois de aprovados, `D:\Ichor\assets\aprovados\heroes\camadas\`). Todas as camadas têm 256 × 256, são transparentes e usam o mesmo enquadramento do sprite original. Empilhadas na ordem abaixo, reproduzem a imagem atual (diferença máxima de 5 em 255, só no alfa das bordas).

| Ordem (de baixo para cima) | Arquivo | O que contém | Pivô (px na imagem de 256) | Movimento sugerido |
| --- | --- | --- | --- | --- |
| 1 | `talos_top_corpo.png` | Tronco, ombreiras, caldeira de Ícor, cabeça e mandíbula. Com pintura nas partes escondidas (soquete sob o escudo, tubo de latão sob o antebraço, ombreiras completas sob as chaminés) | (128, 128) | Gira com o herói; respiração leve (100–102%) |
| 2 | `talos_top_braco_escudo.png` | Escudo (hoplon) e a junta do braço | (153, 72), o ombro | De −20° (para fora) a +25° (para dentro) |
| 3 | `talos_top_braco_soco.png` | Antebraço e punho | (150, 182), o ombro | Soco: até +14 px em x e volta; ou girar ±15° |
| 4 | `talos_top_chamines.png` | As duas chaminés dos ombros | (109, 76) e (109, 176) | Pulsar de 100% a 115% em cada centro |

### Observações
- O vapor não faz parte do sprite. Para vapor, usar `fx/fumaca.png` saindo dos centros das chaminés.
- O soquete sob o escudo e o tubo sob o antebraço só aparecem quando a peça se mexe.
- Prévia: `D:\Ichor\capturas\animacao-2d\previa_camadas_talos.png`.

## Próximos heróis
Mesmo padrão (camadas 256 × 256, pivôs nas articulações, folga para o movimento) para Hércules, Ártemis, Zeus, Asclépio e Atena, depois que as camadas do Talos forem aprovadas no jogo.
