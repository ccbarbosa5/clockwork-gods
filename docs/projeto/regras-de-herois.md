# Clockwork Gods — Regras para criar heróis

Documento único. Vale para TODO herói novo (lore, arte e código). Em caso de conflito com outro documento, vale este. Decisões do usuário de 9 nov. 2026 (atualizado em 12 nov. 2026: o anel do time saiu do jogo).

## 1. Escolha do herói
- Figuras **conhecidas** da mitologia grega (deuses, semideuses, heróis e monstros famosos). Nome reconhecível vale mais do que um personagem obscuro.
- O elenco é equilibrado por função: cada leva nova traz, de preferência, 1 Tanque, 1 Dano e 1 Suporte.
- Hefesto não é jogável (é o Mestre dos Ritos).

## 2. Aparência
- **Aparência clássica do mito:** corpo e rosto humanos (ou da criatura, no caso de monstros), reconhecíveis à primeira vista.
- **O steampunk fica no equipamento:** armas, armaduras e acessórios com latão, bronze, engrenagens, rebites, vapor e Ícor.
- **Marca de corpo forjado:** veias finas de Ícor dourado brilhando de leve na pele (ou detalhe equivalente). É discreta e nunca domina.
- **Exceção, os autômatos:** personagens que são máquinas no próprio mito (ex.: Talos) são 100% mecânicos.
- **Nada de genérico:** evitar elementos de catálogo (engrenagem solta no cinto, martelo comum, armadura de placas sem história).

## 3. Os três ganchos (obrigatório)
Todo herói tem três marcas que **nenhum outro herói tem**:
1. **Silhueta única:** reconhecível mesmo pintado de preto.
2. **Objeto-assinatura:** algo que só ele carrega e que diz quem ele é.
3. **Detalhe de história:** uma marca que só faz sentido para ele e faz o jogador perguntar "por que ele tem isso?".

Os ganchos precisam aparecer também no sprite visto de cima (45 a 62 px na tela, hoje ~12% maiores sem o anel do time).

| Herói | Silhueta | Objeto-assinatura | Detalhe de história |
| --- | --- | --- | --- |
| Talos | Corpo quadrado de autômato, chaminés nos ombros | Escudo redondo (hoplon) | Caldeira de Ícor no peito (a veia única do mito) |
| Ártemis | Esguia, capa roxa curta | Arco-rifle de pressão | Diadema de lua crescente |
| Asclépio | Dois braços mecânicos extras | Cajado com serpente mecânica | Frascos de Ícor |
| Hércules | Corrente de bronze enrolada no braço, com gancho de três pontas | Clava de oliveira com pistões | Troféus dos doze trabalhos no cinto; doze marcas na braçadeira |
| Zeus | Coroa de bobinas quebrada ao meio, com raios saltando | Águia de latão com raio nas garras | Cicatriz de raio em Ícor do peito ao rosto; um olho dourado |
| Atena | Elmo coríntio no alto da cabeça, crista de oliveira | Égide com a Medusa (cobras mecânicas) | Coruja de latão de asas abertas; olhos cinza-claros |

## 4. Cores
- **Cor da função só como destaque** (faixas, detalhes, brilho), nunca como base do corpo: Tanque #F59933, Dano #B873FF, Suporte #54D973.
- **Proibido azul ou vermelho dominante** (são as cores dos times, aplicadas pelo jogo na barra de vida e na sombra sob o herói).
- Cada herói tem uma paleta-base própria que o distingue dos outros da mesma função.
- Raios, energia e brilhos mágicos são **dourados** (Ícor), não azuis.

## 5. Teste antes de aprovar a arte
- **Teste da silhueta:** todos os heróis pintados de preto, lado a lado; todos reconhecíveis.
- **Teste de tamanho:** o sprite lido no tamanho da tela e o ícone a 24 px.
- **Teste de vizinhança:** comparar com os heróis da mesma função; não pode lembrar nenhum.

## 6. Kit (habilidades)
- 3 cartas + 1 ultimate. Tipos: Dano, Cura, Proteção, Controle ou Mobilidade. Custo das cartas: 2 a 4 de Ícor.
- **Diferente dos heróis já existentes,** principalmente os da mesma função. Cada herói tem um estilo de IA (frontline, dive, flank, backline_dps, backline_support, battle_support), de preferência um ainda não usado na função.
- **Nada de reviver ou impedir a morte** (já é a Segunda Chance do Asclépio).
- Números comparados aos da mesma função; o equilíbrio é confirmado na simulação (docs/projeto/balanceamento.md).
- Distâncias em metros para o jogador (1 m = 30 px). Texto curto da carta: até 20 caracteres em PT e EN.
- Cada carta entra numa engrenagem da Roda do Destino (docs/projeto/sistema-engrenar.md); todo time possível precisa ter as 4 engrenagens.
- As habilidades nascem do mito do personagem e se ligam aos três ganchos sempre que possível.

## 7. Lore
- Ficha no modelo "Personagem" da Bíblia de Lore: quem é nos Ritos, aparência (seções 2 a 4), relação com o Ícor e com o próprio eco, 3 traços de personalidade, motivação, relações (com a família do mito e com o elenco), frase marcante e ligação de cada habilidade com a história.
- Cada um dos três ganchos tem uma explicação na ficha.
- Textos da galeria em PT e EN: epíteto (até 30 caracteres), origem, bio (até 220 caracteres) e frase.

## 8. Identificadores e arquivos
- id do herói e das habilidades: minúsculas, sem acento, uma palavra, sem repetir um id existente. Definidos antes da arte e do código.
- Imagens por herói (7): `heroes/{id}_top.png` 256 × 256, `heroes/{id}_portrait.png` 256 × 256, `heroes/{id}_full.png` 512 × 768 e `icons/{habilidade}.png` 256 × 256 (4, a ultimate com contorno dourado). Com animação por peças, também as camadas em `heroes/camadas/` (docs/projeto/animacao-2d.md). Regras técnicas em docs/projeto/decisoes-tecnicas-arte.md.
- Passo a passo técnico: docs/projeto/como-adicionar-heroi.md.

## 9. Ordem de trabalho
1. Escolher os heróis com o usuário e definir os ids.
2. **Lore:** ficha + kit + ganchos + textos → aprovação do usuário → docs/projeto/herois-pacote-N.md.
3. **Arte:** retrato e ilustração primeiro (para aprovar o design) → teste da silhueta → sprite (e camadas) → ícones.
4. **Código:** implementa, simula o equilíbrio, põe os textos em i18n/textos.csv.
5. **Tradução EN** do que faltar.
