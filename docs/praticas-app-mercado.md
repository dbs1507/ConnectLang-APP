# Boas práticas de app, lidas no protótipo

O HTML de referência é o protótipo do **RESPOSTA** (sistema Fonte 5a), não do ConnectLang. O valor para o nosso app não é copiar índigo e laranja — é o **sistema**: uma cor de base, uma de ação, uma de crescimento; 5 destinos na barra; overlay certo para cada tipo de tarefa.

> **Regra que o mercado usa.** Marca e ação não são a mesma cor. A cor da marca pinta chrome (fundo, nav, títulos). A cor de ação pinta o único botão que importa na tela. Verde só confirma que algo deu certo. Se tudo for teal, nada é prioridade.

---

## As 3 cores, por papel — não por gosto

Fonte: paleta extraída do protótipo RESPOSTA (índigo `#1D2254`, âmbar `#F08019`, verde `#2F7A52`). No ConnectLang os hex são outros; os papéis são os mesmos.

### Base / chrome — `#1D2254` (índigo profundo)

Splash, app bar, texto forte, tab ativa, identidade. Quase nunca é o botão principal — é o chão da interface.

**ConnectLang:** heading `#1A1A1A` + primary teal só no acento (nav ativa, progresso).

### Ação — `#F08019` (laranja / âmbar)

Um CTA preenchido por tela: Entrar, Marcar como feito, Salvar fruto, Publicar. Hover/pressed usa o tom mais escuro (`#D96C0B`).

**ConnectLang:** teal `#349993` no filled; preto `#1A1A1A` quando o CTA não pode competir com o acento.

### Crescimento — `#2F7A52` (verde suave)

Feito, sequência, fruto, check-in. Nunca pede clique. Se o verde virar botão, o usuário não distingue “já está ok” de “faça agora”.

**ConnectLang:** success `#3F8F5C` e destructive `#D64545` — manter só para estado, não para CTA.

### Neutros (80% da tela)

O protótipo quase não usa cor fora desses três papéis. O resto é superfície clara (`#F7F8FC`), card (`#E9EBF6` / `#EDEFFA`), texto secundário (`#6A6F94`), texto mudo (`#9BA0BE`). Mercado (iOS HIG + Material 3 + Refactoring UI): hierarquia por contraste e espaço, não por arco-íris.

| Papel | RESPOSTA | ConnectLang hoje | Prática |
| --- | --- | --- | --- |
| Fundo | Off-white azulado | Branco `#FFFFFF` + muted `#F9FAFB` | Um fundo, um muted. Sem segundo “tema” no meio do fluxo. |
| Texto | Índigo no título, cinza-azul no corpo | Heading `#1A1A1A`, body `#6B6761` | Título mais escuro que o corpo. Nunca título na cor de ação. |
| Borda | Lilás-cinza fino | `#E5E7EB` | Hairline. Card não precisa de sombra se o raio e o espaço já separam. |
| Aviso / erro | Vermelho pontual (`#C0392B`) | destructive `#D64545` | Só em falha e exclusão. Nunca como cor de marca. |

---

## Menu — 5 destinos, nenhum “botão disfarçado”

O protótipo repete a mesma barra em 8 telas: **Início · Missão · Mapa · Comunidade · Perfil**. Isso é o padrão de mercado (Instagram, Duolingo, Headspace, iOS HIG): 3 a 5 abas, todas lugares onde a pessoa mora, não ações pontuais.

| Aba RESPOSTA | Por que está na barra | Equivalente ConnectLang |
| --- | --- | --- |
| Início | O dia: uma palavra + uma missão. Não é dashboard. | Início — continuar de onde parou. Já está certo. |
| Missão | Tarefa diária, o job-to-be-done do produto. | Vocabulário — revisão SRS, uso diário. |
| Mapa | Descoberta no mundo real (eventos). | Biblioteca — descoberta de conteúdo. |
| Comunidade | Feed social, destino frequente. | Ditado — prática recorrente. |
| Perfil | Identidade, selos, settings. Aba de primeira classe. | Hoje cai em “Mais” (sheet). Mercado prefere Perfil na 5ª aba. |

> **Onde o ConnectLang foge do mercado.** “Mais” é overflow de Android, não destino. Perfil, Caderno e LIA competem por um sheet. Apps de estudo que performam (Duolingo, Babbel, Headspace) deixam Perfil visível e empurram o resto para dentro dele (assinatura, sair, nivelamento). Cinco abas reais batem Lei de Hick; “Mais” esconde o que a pessoa precisa achar de novo.

### Regras da barra que o protótipo (e o mercado) seguem

- Ícone de contorno inativo, preenchido ativo — Jakob: o usuário já sabe ler isso.
- Label sempre visível (não só ícone). iOS 18 ainda rotula; apps de aprendizado não apostam em ícone só.
- A barra some em fluxos imersivos (missão em andamento, simulador, onboarding). Não some numa lista.
- Tocar a aba atual rola para o topo — não abre outro stack. No ConnectLang a nav ainda dá push e volta o índice para 0; isso quebra o modelo mental de “estou neste lugar”.

---

## Overlays — 4 camadas, cada uma com um job

O protótipo nomeia os dois casos no próprio canvas: modal “em breve” e sheet “registrar fruto”. O resto é push de tela. Essa taxonomia é a que Apple, Google e os apps de hábito usam.

| Camada | Quando | No protótipo | No ConnectLang |
| --- | --- | --- | --- |
| Bottom sheet | 1 job, 1–2 toques, formulário curto. Gesto de puxar para fechar. | Registrar fruto (tipo + texto + salvar). | `showAppBottomSheet` (40–90%). LIA, Nova palavra, Mais. |
| Dialog / modal | Interrompe. 1 decisão. 2 botões (primário + Agora não). | “Em breve” — Avise-me / Agora não. | Ainda misturado com sheet. Mercado: AlertDialog ou card central. |
| Full-screen modal | Mini-fluxo com etapas. X no topo, sem swipe como única saída. | Onboarding, tema, simulador de conversa. | `showAppFullscreenModal` — nivelamento, conta. Certo. |
| Push (tela cheia) | Conteúdo para ler/fazer. Voltar, não fechar. | Detalhe da missão, apoio, desafio, post. | Vocabulário, Biblioteca, Ditado. Certo — não são overlay. |

### Sheet bem feito

- Handle de 36×4 no topo (affordance de arrastar).
- Título da ação, não da feature (“Registrar fruto”).
- CTA filled no fundo, Cancelar como texto.
- Não empilha sheet em cima de sheet.

### Modal bem feito

- Fundo escurecido; toque fora fecha só se a ação for descartável.
- Um título + um parágrafo + no máximo dois botões.
- Primário à direita (iOS) ou full-width empilhado (Material).
- Nunca um formulário longo — isso é sheet ou full-screen.

---

## Home — uma coisa hoje, não um painel

A home do RESPOSTA é Palavra de hoje + Missão de hoje + um próximo passo. Comunidade e desafios entram como cartões secundários. Headspace e Duolingo fazem o mesmo: o primeiro viewport responde “o que eu faço agora?”. Dashboard de métricas fica no Perfil.

- 1 CTA por tela
- Secundário é texto / outline
- Verde só depois do feito
- Home = hoje
- Perfil = histórico

---

## Forma, tipo e toque (o que o mercado espera em 2026)

| Decisão | RESPOSTA / mercado | ConnectLang | Nota |
| --- | --- | --- | --- |
| Raio | Cards 16px, pills 99px, avatares 50% | Zero na UI funcional; 20px só no topo do sheet | Zero é marca (landing). Manter. Não importar o 16px do RESPOSTA. |
| Tipo | Figtree (UI) + Newsreader (versículo) | Messina Sans + Recife Text | Par certo: sans no chrome, serif só em conteúdo especial. |
| Alvo de toque | Botões altos, chips 44px, nav 64px | min 48px no tema, nav 64px | HIG 44 / Material 48. Já ok — não reduzir para caber label. |
| Tema claro/escuro | Pergunta no onboarding; índigo permanece nos dois | Só claro hoje | Escuro é opcional. A paleta de papéis precisa funcionar nos dois. |

---

## O que levar para o ConnectLang

Ordem de impacto, sem redesenhar a marca.

### Já está alinhado

- Uma cor de acento (teal), resto neutro.
- Bottom nav 5 itens, home = continuar.
- 5ª aba é Perfil. LIA entra pelo chip no topo da home, não pela barra.
- Bottom nav persiste nas 5 abas (StatefulShellRoute). Caderno e LIA não se repetem em Estudo e conta.
- Pares de botão: um filled + um outline (não dois filled na mesma tela).
- Sheet vs full-screen já tipados no design system.
- Verde/vermelho só semânticos.
- Par tipográfico UI + display.

### Gap vs. mercado

- Modal de interrupção (confirmação, “em breve”) ainda não é um componente próprio — cai em sheet ou não existe.
- 5 telas ainda chamam `showModalBottomSheet` bruto em vez de `showAppBottomSheet`.

> **O que não copiar.** Não pintar o ConnectLang de índigo/âmbar. Não arredondar cards para 16px. Não criar aba “Missão” se o job diário já é Vocabulário + Início. O protótipo ensina arquitetura de decisão, não skin.

---

Fonte: RESPOSTA — Protótipo (offline), sistema Fonte 5a. Cruzado com iOS HIG (Tab Bars), Material 3 (NavigationBar), e o design system atual em `lib/design_system/`.
