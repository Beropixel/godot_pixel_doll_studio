# Doll Studio — tutorial

Doll Studio desenha personagens 3D com esqueleto como pixel art ao vivo: um `PixelDoll` (um `Sprite2D`) renderiza o modelo num `SubViewport` de 96×64, com cores chapadas em faixas de luz, contorno de 1 px, linhas internas e animação em passos, como um sprite desenhado à mão.

Este tutorial cobre o fluxo completo: criar um skin, encaixar peças, recolorir com paletas, ajustar o estilo, criar clips e usar o boneco no jogo.

---

## 1. Conceitos

| Recurso | O que é | Exemplo no weleven |
|---|---|---|
| `DollSkin` | A aparência: personagem 3D + peças nos ossos + malhas escondidas/recoloridas | `components/paper_doll/skins/knight.tres` |
| `DollSlot` | Uma peça presa a um osso (osso + cena + offset) | espada em `handslot.r`, escudo em `handslot.l` |
| `DollRig` | As bibliotecas de animação de um esqueleto, compartilhadas pelos skins dele | `components/paper_doll/rig_medium.tres` |
| `DollPalette` | Três tons (claro, médio, escuro) que substituem a cor-chave do skin | `components/paper_doll/palettes/team_left.tres` |
| `DollStyle` | Como todos os bonecos são desenhados: câmera, luz, faixas, linhas, FPS | `components/paper_doll/doll_style.tres` |
| `PixelDoll` | O nó que junta tudo isso na tela | `Sprite` dentro de `entities/defender/defender.tscn` |

```
DollSkin ──► character (.glb com Skeleton3D)
   │   ├──► rig: DollRig ──► { "": rig_medium_general.glb, "doll": paper_doll_animations.tres }
   │   └──► slots: [DollSlot(bone, piece, offset), …]
   │
PixelDoll ◄── skin + palette + style (+ flipped)
```

---

## 2. Instalação

1. Copie `addons/doll_studio/` para o projeto.
2. **Project › Project Settings › Plugins** → ative **Doll Studio**.
3. Aparece a aba **Doll Studio** ao lado de 2D / 3D / Script.

> No weleven isso já está feito, e `addons/doll_studio` está na regra de warnings-como-erros do `project.godot`.

---

## 3. A aba Doll Studio

**Barra de cima**

| Controle | Função |
|---|---|
| **Skin** | Todos os `DollSkin` `.tres` do projeto (a lista se atualiza sozinha quando arquivos mudam) |
| **Edit Skin** | Abre o skin no Inspector do editor |
| **Workbench** | Abre o skin na bancada 3D (seção 6) |
| **Palette** | Paleta aplicada às malhas recoloridas (ou nenhuma) |
| **Mirrored** | Liga/desliga o espelhamento do render (`flipped`) |
| **Direction** | Uma das 8 direções (o modelo gira de verdade) ou **All**: as 8 em volta de um centro, cada boneco posicionado para onde olha (seção 8.4) |
| **Clip** | Clips do rig do skin (`Death_A`, `doll/defend`, …) |
| **Style** | Estilo usado no preview; editável no painel da direita |

**Linha do tempo (embaixo)**: play/pausa, pose anterior/próxima, scrub, **Loop**, **Onion Skin** (pose anterior translúcida quando pausado), **Zoom** em pixels inteiros (1×–8×) e cor de fundo.

**Atalhos** (com a aba visível e sem campo de texto em foco):

| Tecla | Ação |
|---|---|
| Espaço | Toca / pausa |
| ← / → | Pose anterior / próxima (no ritmo do `frames_per_second` do estilo) |
| Home | Volta ao início |

Tudo o que foi escolhido (skin, paleta, espelhamento, direção, clip, estilo, zoom, fundo, loop, onion) é lembrado por projeto.

Se o preview estiver vazio, ele diz o que falta: nenhum skin no projeto, skin sem personagem ou skin sem clips.

---

## 4. Criando um skin do zero

### 4.1 O rig (uma vez por esqueleto)

1. FileSystem → botão direito numa pasta → **Create New › Resource… › DollRig**.
2. Em **Animations**, adicione entradas `nome da biblioteca → AnimationLibrary`:
   - `""` (biblioteca padrão) → as animações importadas do `.glb` (ex.: `rig_medium_general.glb`). Os clips aparecem sem prefixo: `Idle`, `Death_A`…
   - `"doll"` → uma `AnimationLibrary` `.tres` sua, para clips feitos à mão. Os clips aparecem como `doll/defend`.

> Bibliotecas importadas de `.glb` são **somente leitura**. Clips novos só podem ir para bibliotecas `.tres`.

### 4.2 O skin

1. FileSystem → **Create New › Resource… › DollSkin**. Salve, ex.: `skins/templar.tres`.
2. No Inspector:
   - **Display Name** — nome em inglês (traduzido onde aparece).
   - **Character** — uma cena com um `Skeleton3D` dentro (ex.: `knight.glb`).
   - **Rig** — o `DollRig` do passo anterior.
   - **Mirrored** — espelha o modelo. Útil para que o braço do escudo fique virado para a câmera depois do giro do estilo.
3. Assim que o personagem é definido, o topo do Inspector mostra uma **miniatura animada** (toca o primeiro clip com "idle" no nome) e o botão **Open in Workbench**.

### 4.3 Peças (slots)

1. Em **Slots**, adicione um elemento → **New DollSlot**.
2. **Bone** — um seletor com os ossos do esqueleto do personagem (ossos que sumiram do esqueleto aparecem como `(missing)`).
3. **Piece** — qualquer cena 3D: um modelo importado (`sword_1handed.gltf`) ou uma montada com primitivas (`components/paper_doll/pieces/great_helm.tscn`).
4. **Offset** — posição/rotação da peça no espaço do osso. Não precisa digitar: ajuste com os gizmos na bancada (seção 6).

### 4.4 Malhas escondidas e recoloridas

As duas listas viram **checklists** agrupadas por origem (Character, Slot 0, Slot 1…):

- **Hidden Meshes** — malhas do personagem que não são desenhadas (ex.: o elmo original quando um slot põe outro elmo).
- **Recolored Meshes** — malhas (do personagem ou das peças) cujos texels próximos da **Recolor Key** recebem a paleta.

**Recolor Key** é a cor que a paleta substitui. Cada texel perto dessa cor vira o tom claro, médio ou escuro da paleta conforme o próprio brilho. Escolha a cor de destaque do modelo, ex.: o vermelho da capa do cavaleiro.

Toda mudança no skin atualiza na hora a aba, a miniatura e qualquer `PixelDoll` aberto no editor.

---

## 5. Paletas

1. **Create New › Resource… › DollPalette**.
2. Defina **Light**, **Mid** e **Dark** (do mais claro ao mais escuro).
3. Escolha a paleta na aba (**Palette**) para conferir.

Paletas só aparecem na aba se forem salvas como `.tres`. Bonecos que compartilham uma paleta compartilham os materiais.

---

## 6. A bancada (Workbench)

A bancada monta o skin no **editor 3D** para usar as ferramentas nativas do Godot: gizmos de mover/girar e o painel de Animação.

**Abrir:** botão **Workbench** na aba, ou **Open in Workbench** no Inspector do skin. O editor troca para 3D com a cena `doll_workbench.tscn` aberta.

### 6.1 Encaixar peças

1. No Scene dock, expanda `Character › … › Skeleton3D › Slot0_handslot.r › Piece0`.
2. Mova/gire `PieceN` com os gizmos do 3D.
3. O `offset` do `DollSlot` acompanha automaticamente.

> A bancada mostra o personagem **sem** espelhamento (`mirrored` é ignorado aqui), virado para +Z.

### 6.2 Pixel Preview

Com a bancada aberta, o painel lateral direito do editor 3D mostra o **Pixel Preview**: o skin como `PixelDoll` no estilo do projeto, copiando a pose do esqueleto da bancada no ritmo do estilo. Uma pose feita à mão ou um clip tocando no painel de Animação aparece como pixel art na hora, com ou sem keyframe.

Opções: **Flip** (espelhar), **Zoom** (1×–6×), a **direção** (uma das 8, para conferir o clip de todos os ângulos) e a paleta. Ficam lembradas por projeto.

### 6.3 Criar ou editar clips

1. Selecione o nó `AnimationPlayer` da bancada. Ele já tem as bibliotecas do rig do skin.
2. No painel **Animation**, escolha um clip de uma biblioteca `.tres` (ex.: `doll/defend`) ou crie um novo nessa biblioteca.
3. Selecione o `Skeleton3D`, pose os ossos e insira keyframes como em qualquer animação do Godot.
4. Use o Pixel Preview para ver o resultado em pixels enquanto trabalha.

### 6.4 Salvar

**Ctrl+S** na bancada (ou o botão **Save Skin and Clips** no Inspector do nó raiz da bancada) grava:

- o **skin**, se alguma peça foi movida;
- as **bibliotecas `.tres`** do rig (onde ficam os keyframes).

O personagem montado, as peças e o skin escolhido **nunca** vão para o arquivo da cena: `doll_workbench.tscn` continua vazia e reutilizável.

Se o skin mudar por fora (ex.: no Inspector), a bancada se remonta sozinha.

---

## 7. Estilo

O `DollStyle` define como **todos** os bonecos sem estilo próprio são desenhados. Mudar o estilo reestiliza todos de uma vez.

### 7.1 Estilo do projeto

O estilo que vem com o addon é **somente leitura** (assim uma atualização do addon não desfaz seus ajustes). Para ajustar:

1. Na aba, escolha o estilo do addon em **Style**.
2. Clique em **Create Project Style…** e salve (ex.: `components/paper_doll/doll_style.tres`).
3. A cópia vira o estilo do projeto (**Project Settings › Doll Studio › Default Style**) e já fica selecionada.

Ordem de prioridade: `PixelDoll.style` → estilo do projeto → estilo do addon.

### 7.2 Parâmetros

| Parâmetro | Efeito |
|---|---|
| **Turn Degrees** | Quanto o boneco gira do perfil em direção à câmera (0–90°); nas diagonais, proporcionalmente (seção 8.4) |
| **Pitch Degrees** | Quanto a câmera olha de cima (0–60°) |
| **Camera Size** | Unidades do mundo que cabem nos 64 px de altura: maior = boneco menor |
| **Feet Offset** | Pixels do centro do render até os pés |
| **Frames Per Second** | Poses por segundo: a animação anda em passos, como sprite |
| **Light Direction** | Direção da luz no espaço da vista (espelhada quando o boneco vira) |
| **Light Bands** | Quantas faixas de luz (2–6) |
| **Shadow / Highlight Brightness** | Brilho da faixa mais escura / mais clara |
| **Shadow / Highlight Tint** | Matiz das sombras / luzes (rampas de pixel art mudam de matiz, não só de brilho) |
| **Albedo Steps** | Quantos tons chapados sobram de cada gradiente da textura (0 mantém os gradientes) |
| **Inner Line Threshold** | Diferença de profundidade (em unidades) para desenhar linha interna entre partes |
| **Inner Line Brightness** | Quanto da cor sobra no pixel da linha interna (1 esconde as linhas) |

Edite no painel da direita da aba com o preview tocando para ver o efeito na hora.

---

## 8. Usando no jogo

### 8.1 Na cena

Instancie `res://addons/doll_studio/runtime/pixel_doll.tscn` (não use `PixelDoll.new()`: o nó precisa do `Viewport`, da câmera e do `AnimationPlayer` da cena). No Inspector, defina **Skin**, **Palette**, **Flipped** e, se quiser, **Style**.

### 8.2 Por código

```gdscript
const TEAM_PALETTE := preload("res://components/paper_doll/palettes/team_left.tres")

@onready var doll: PixelDoll = $Sprite


func _ready() -> void:
	doll.skin = preload("res://components/paper_doll/skins/knight.tres")
	doll.palette = TEAM_PALETTE
	doll.flipped = true  # vira para a esquerda (render e luz espelhados)
	doll.animation_player.play(&"doll/defend")
```

Outras funções úteis:

- `doll.pose(&"Death_A", 0.4)` — congela o clip num instante (para scrub).
- `doll.match_pose(skeleton)` — copia a pose de outro `Skeleton3D` do mesmo rig.

### 8.3 Por uma animação de fora

Como no Defender: um `AnimationPlayer` do nó pai dispara os clips do boneco com uma **Animation Playback Track** apontando para `Sprite/Viewport/AnimationPlayer`, com o nome do clip na chave (ex.: `doll/defend`).

Por ser um `Sprite2D`, o boneco aceita tremer, virar, `modulate`/`self_modulate` etc. como qualquer sprite.

### 8.4 Oito direções

`direction` gira o **modelo** para olhar para um dos 8 lados da tela: `RIGHT`, `DOWN_RIGHT`, `DOWN`, `DOWN_LEFT`, `LEFT`, `UP_LEFT`, `UP`, `UP_RIGHT`. "Baixo" é em direção à câmera e "cima" é de costas.

```gdscript
func _physics_process(_delta: float) -> void:
	if velocity.length() > 0.1:
		doll.direction = PixelDoll.direction_of(velocity)  # direção mais próxima do vetor (+y para baixo)
```

**`direction` × `flipped`**

| | `flipped` | `direction = LEFT` |
|---|---|---|
| Como vira | Espelha o render | Gira o modelo 3D |
| Mão da arma | Troca de lado (por isso existe `mirrored` no skin) | Continua a mesma; aparece o outro lado do personagem |
| Custo | Igual | Igual |

Os dois se combinam: `flipped` espelha o que `direction` mostrar. Para um jogo com dois lados espelhados (como o weleven hoje), `flipped` basta. Para personagens que andam livremente pelo campo, use `direction`.

**Como o `turn_degrees` entra:** o estilo puxa a vista em direção à câmera proporcionalmente ao quanto a direção é lateral (`turn × cos(ângulo)`). Assim `RIGHT` fica igual ao padrão, `LEFT` é o simétrico verdadeiro, `DOWN` fica de frente e `UP` de costas. Com `turn` alto, as vistas da frente ficam mais parecidas entre si e as de costas mais separadas. Com `turn = 0`, as 8 vistas ficam a exatos 45° uma da outra.

A luz continua fixa na tela para todas as direções (o mesmo lado ilumina todo mundo).

---

## 9. Problemas comuns

| Sintoma | Causa provável |
|---|---|
| Preview diz "No DollSkin in the project yet" | Nenhum `.tres` com script `DollSkin` salvo |
| "This skin has no character" | **Character** vazio no skin |
| "This skin has no clips to play" | Skin sem **Rig**, ou rig sem bibliotecas |
| Erro `has no mesh named … to hide` | Nome em **Hidden Meshes** que não existe mais no personagem |
| Osso aparece como `(missing)` | O osso do slot não existe no esqueleto do personagem atual |
| A paleta não pega | Malha fora de **Recolored Meshes**, ou **Recolor Key** longe da cor real da textura |
| Keyframes não salvam | O clip está numa biblioteca importada (`.glb`); mova-o para uma `.tres` |
| Peça no lado errado no jogo | A bancada mostra sem espelhar; confira **Mirrored** no preview da aba |
