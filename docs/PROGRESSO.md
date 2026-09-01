# Progresso — retomar a partir daqui

Resumo do que já foi decidido e feito até agora, pra continuar numa sessão nova (abrindo o Claude Code direto nesta pasta, `~/ConnectLang-APP`). O plano completo está em [planejamento.md](planejamento.md); este arquivo é só o "estado atual".

**Atenção — o projeto mudou de lugar:** era `~/Documents/ConnectLang-APP`, agora é `~/ConnectLang-APP`. O iCloud Drive (sincronização de Área de Trabalho e Documentos) estava ativo e sincronizando a pasta antiga, causando arquivos duplicados com sufixo " 2" toda vez que o Gradle escrevia muito rápido — isso derrubou vários builds numa sessão (`DexArchiveMergerException`, `Stale NFS file handle` no próprio `flutter pub get`, e até um arquivo duplicado dentro de `.git/refs/`, embora sem chegar a corromper o repositório). Tentei excluir só a pasta do sync via `xattr -w com.apple.fileprovider.ignore#P 1 <pasta>`, mas essa API não é garantida pro provedor nativo de Área de Trabalho/Documentos da Apple e não resolveu de fato — a única solução que funcionou foi mover a pasta pra fora de `~/Documents` inteiramente. Se algum editor (Cursor, VS Code etc.) ainda estiver com o caminho antigo aberto, é só reabrir a pasta no novo local.

## Decisões já fechadas (não perguntar de novo)

- **Escopo**: só perfis **Aluno** e **Assinante** no app mobile (Professor/Admin continuam só no site).
- **Paridade total**: dentro desses dois perfis, o app entrega exatamente as mesmas funcionalidades do web — sem MVP reduzido, sem fasear por funcionalidade.
- **Compra de assinatura**: fica só pelo site na v1 (política de IAP da Apple/Google — ver seção 1 do planejamento.md). O app só usa quem já assina.
- **Nome/identidade**: app "ConnectLang", org `com.connectlang`, projeto Flutter `connectlang_app`.
- **Backend**: mesmo projeto Supabase do repo web (`verb-flow-hub`) — nenhum backend novo, nenhuma tabela nova.
- **Repo**: `github.com/dbs1507/ConnectLang-APP`, branch `main`.

## O que já está pronto

- Projeto Flutter criado e no ar (commit inicial já enviado pro GitHub).
- Dependências instaladas: `supabase_flutter`, `go_router`, `flutter_riverpod`, `flutter_dotenv`.
- `lib/core/supabase_client.dart`: inicializa o Supabase lendo `assets/.env` (gitignored — só `assets/.env.example` foi commitado).
- Estrutura de pastas por feature em `lib/features/` já criada (só esqueletos com `.gitkeep`, nenhuma tela implementada ainda): `auth`, `dictation`, `vocabulary`, `library`, `notebook`, `placement`, `study_coach`, `production_demand`, `student_activities`, `student_lessons`, `student_feedback`.
- **Base de autenticação implementada** (item 1 da seção 4 do planejamento.md):
  - `lib/core/session/`: `AppRole`, `SubscriptionInfo`/`SubscriptionStatus`, `AppUser`, e `AuthController` (Riverpod `AsyncNotifier`) — espelha `AuthContext.tsx` do web (sessão + `profiles` + `subscriptions` quando `role == subscriber`, com o mesmo fallback de perfil mínimo em caso de falha de leitura).
  - `lib/features/auth/`: `LoginPage` (e-mail/senha com validação), `ForgotPasswordPage` (`resetPasswordForEmail`, ainda sem deep link nativo — o link abre no site).
  - `lib/app/router.dart`: `go_router` com guard único (`redirect`) que replica `homeForRole`/`RequireRole`/`RequireActiveSubscription` do `App.tsx`, restrito a `student`/`subscriber`. Contas `teacher`/`admin` caem em `UnsupportedRolePage` (`/acesso-nao-suportado`); assinante sem assinatura ativa cai em `SubscriptionInactivePage` (`/assinatura`, sem link de checkout — ver seção 1 do planejamento.md).
  - `lib/app/home_shell.dart`: `StudentHomePage` ainda é atalhos; `SubscriberHomePage` abre o dashboard.
  - **Não implementado ainda nesta etapa**: deep links nativos (`connectlang://reset-password`), `ConfirmEmailPage` equivalente, testes automatizados.
- Testado ponta a ponta no emulador Android (`connectlang_pixel`): tela de login renderiza, validação de campos vazios funciona, submit contra o Supabase real retorna e exibe "Invalid login credentials" para credenciais inválidas, navegação para "Esqueci minha senha" funciona. `flutter analyze` sem erros/warnings.
- **Vocabulário — só "Minhas palavras" + SRS implementado** (fatia inicial do item 2 da seção 4; escopo reduzido combinado com o usuário — o `VocabularyPage.tsx` do web tem 4460 linhas com categorias, vocabulário base, palavras do professor, IA e caderno, então não entrou tudo de uma vez):
  - `lib/features/vocabulary/models/`: `SrsRating`, `srs_schedule.dart` (porte exato do algoritmo adaptativo do web — `baseDays^difficulty`, mesmas constantes), `VocabularyEntry`.
  - `lib/features/vocabulary/vocabulary_repository.dart` + `vocabulary_controller.dart` (Riverpod): lê/escreve `student_vocabulary` (só `source='student'`, sem categorias). Mesma checagem de duplicata por termo normalizado do web.
  - `lib/features/vocabulary/vocabulary_list_page.dart` (lista + form de adicionar palavra) e `flashcard_practice_page.dart` (sessão de flashcards com as 4 notas, prévia do próximo intervalo por botão, prioriza palavras vencidas e cai pro deck inteiro se nada vencer — igual ao web).
  - Acessível pelo botão "Vocabulário" no `home_shell.dart` (ainda via `Navigator.push` direto, não é rota do `go_router` — `/aluno/vocabulario`/`/estudo/vocabulario` da seção 2.3 do planejamento ainda não existem como rotas nomeadas).
  - **Enrich por IA** (`lib/features/vocabulary/models/vocab_enrich_result.dart`, porte de `buildEnrichedTranslationField`): botão "Preencher com IA" no formulário de nova palavra chama a edge function `vocab-enrich` (`entryKind: 'word'`, só palavra isolada) e preenche tradução + frase de exemplo automaticamente; `description`/`partOfSpeech` da IA são gravados também (sem campo visível pra eles — `partOfSpeech` aparece como uma dica itálica ao lado do termo na lista). Aluno ainda revisa/edita antes de salvar.
  - **Categorias** (`vocab_categories` + `student_vocabulary_categories`): filtro na lista e chips no formulário de nova palavra. O catálogo é só leitura — criar/renomear/apagar categoria continua no web (ferramenta do professor).
  - **Aba Arquivadas**: lista `archived_at` (exceto `skip_archived_tab`) e restaura (`archived_at = null`).
  - **Vocabulário base**: aba Base lê `base_vocabulary` por idioma, copia pra `student_vocabulary` com `saved_from_base_vocab_id` e as categorias da base.
  - **Entradas de frase** (`entry_kind='sentence'`): toggle Palavra/Frase no formulário, filtro na lista, badge "Frase" e flashcards no mesmo recorte.
  - **Não implementado ainda**: palavras atribuídas pelo professor (aluno de escola).
  - **Bug corrigido nesta sessão**: `AuthController` zerava `state` pra `AsyncLoading` (perdendo o usuário em cache) em qualquer evento de fundo do Supabase Auth, o que podia derrubar o `vocabularyRepositoryProvider` e, por causa do `go_router` reconstruir o Navigator, descartar telas abertas via `Navigator.push`. Corrigido pra refresh silencioso (mantém o valor anterior visível durante reload em segundo plano) — ver comentário em `lib/core/session/auth_controller.dart`.
  - Testado ponta a ponta no emulador com uma conta assinante real (dados de acesso guardados na memória do agente, não neste arquivo): adicionar palavra, listar, praticar (due e fallback pro deck inteiro), avaliar nas 4 notas com update correto de `interval_minutes`/`srs_difficulty`/`next_review_at` no Supabase, arquivar (`archived_at`, soft-delete). Enrich por IA testado à parte nesta sessão: chamada real à edge function preencheu tradução + frase de exemplo corretas pra duas palavras diferentes (`serendipity`, `curiosity`), `partOfSpeech` salvo e exibido na lista, entrada de teste removida ao final.
- **Caderno implementado** (item 3 da seção 4 do planejamento.md — CRUD simples, como previsto; `NotebookPage.tsx` do web tem 485 linhas, bem mais contido que Vocabulário):
  - `lib/features/notebook/models/notebook_entry.dart`: `NotebookEntry`, `NotebookEntryKind` (`manual`/`ai_explanation`), `NotebookLinkType` (os 4 tipos do web, mas o app só sabe *criar* vínculo com `vocabulary` — os outros só ficam guardados/exibidos).
  - `lib/features/notebook/notebook_repository.dart` + `notebook_controller.dart` (Riverpod): CRUD completo em `student_notebook_entries`, espelha `src/lib/notebook.ts`.
  - `lib/features/notebook/notebook_list_page.dart`: lista + sheet de criar/editar (idioma, conteúdo, vínculo opcional com uma palavra do Vocabulário **ou** um texto da Biblioteca — reaproveita `vocabularyControllerProvider`/`libraryControllerProvider` pra popular os dois dropdowns, sem duplicar query; só um vínculo por nota, escolher um limpa o outro).
  - Acessível pelo botão "Caderno" no `home_shell.dart` (mesma limitação do Vocabulário: `Navigator.push` direto, sem rota nomeada no `go_router`).
  - **Filtro de notas de IA** (Todas / Notas de IA) + marcar como vista (`reviewed_at`). Explanações do Vocabulário entram como `ai_explanation`.
  - **Não implementado ainda**: vínculo com atividade/aula (Aluno de escola). `NotebookFab` já aparece nas telas do aluno/assinante (atalho flutuante pro compositor).
  - Testado ponta a ponta no emulador: criar nota, editar conteúdo, apagar (hard delete, igual ao web), vincular a uma palavra do Vocabulário e a um texto da Biblioteca (`link_type='library_text'`, `link_id`/`link_label` corretos no Supabase, chip do vínculo exibido na lista).
- **Biblioteca de textos implementada** (fatia do item 4 da seção 4 — só leitura + marcar como lido; `StudentTextLibraryPage.tsx` do web tem quase 3000 linhas com textos temporários/pessoais do aluno, perguntas de compreensão por IA e TTS, então ficou de fora igual às outras fatias):
  - Dependência nova: `flutter_markdown_plus` (o pacote oficial `flutter_markdown` está descontinuado; conteúdo de `texts_library.content` é markdown, igual ao web que usa `react-markdown`).
  - `lib/features/library/models/library_text.dart`, `library_repository.dart` + `library_controller.dart` (Riverpod): lê `texts_library` (todo mundo autenticado vê, sem gate por CEFR — confirmado no código web, `getUnlockedCefrLevels` não é usado nessa tela) e `student_text_reads` (toggle otimista com rollback se a escrita falhar).
  - `library_list_page.dart` (lista com idioma/CEFR + toggle de lido direto na linha) e `text_reading_page.dart` (conteúdo renderizado com `MarkdownBody`, toggle de lido na AppBar, TTS e link pras perguntas).
  - **TTS do texto** (`tts-text-plan`, dependência nova `path_provider`): o texto vem em pedaços já sintetizados em base64 (um por parágrafo/sentença); cada pedaço é gravado num arquivo temporário e tocado em sequência via `just_audio` `ConcatenatingAudioSource`/`setAudioSources`. Sem controle de velocidade/voz nem cache local nesta fatia (sempre voz feminina).
  - **Perguntas de compreensão** (`lib/features/library/models/text_question.dart`, `text_questions_page.dart`): o app só **lê** o conjunto MCQ já publicado por um professor (`text_question_sets`/`text_questions`/`text_question_options`, `status='published'`) e grava a tentativa (`student_text_question_attempts`/`student_text_question_answers`) — a edge function `text-questions-generate` só deixa professor/admin gerar perguntas pra `source_type='library'`, então o aluno/assinante nunca teria permissão de gerar mesmo se o app chamasse a function.
  - **Bug corrigido nesta sessão** (achado testando o TTS, mas existia também no Ditado e no Nivelamento): `just_audio`'s `player.play()` só resolve quando a faixa termina (ou é interrompida) — dar `await` nele antes de resetar o spinner de loading travava o botão desabilitado até o áudio inteiro acabar. Trocado por `unawaited(_player.play())` nos três lugares (`dictation_session_page.dart`, `placement_session_page.dart`, `text_reading_page.dart`).
  - Acessível pelo botão "Biblioteca" no `home_shell.dart` (mesma limitação de rota das outras: `Navigator.push` direto).
  - **Textos próprios**: abas Temporários (colar texto, 48h, 5/dia) e Pessoais (guardar a partir do temp, teto de 30), com RPC `transfer_temporary_text_question_sets` ao salvar. Assinante gera perguntas com IA só nesses textos (`text-questions-generate`).
  - **TTS**: voz feminina/masculina e velocidade 0,5×–1,75× (`just_audio` `setSpeed`), inclusive em texto temporário/pessoal (`temporaryTextId`/`personalTextId`).
  - **Captura de vocabulário**: selecionar/copiar trecho e salvar como palavra ou frase (`addFromText`, `source` library|temporary|personal).
  - **Perguntas**: última tentativa + tentar de novo; marcar lido/enviar perguntas completa assignments `read_text`/`read_questions`.
  - **Não implementado ainda**: propostas de texto pra biblioteca (fluxo de aluno escolar), geração de perguntas em texto curado (a edge function só deixa professor/admin gerar pra `source_type='library'`).
  - Testado ponta a ponta no emulador com dados reais de produção: listar, abrir um texto e ler o markdown renderizado, marcar/desmarcar como lido, TTS de um texto longo (múltiplos pedaços) tocando/pausando/retomando corretamente após o fix do `play()`, estado "sem perguntas" renderizando certo pra textos sem conjunto publicado. Não testado ao vivo: responder um conjunto de perguntas publicado (não achei um pelo app dentre ~400 textos sem busca — confirmado via query direta que existem 3 conjuntos publicados no banco; `fetchQuestionSet`/`submitQuestionAttempt` reaproveitam o mesmo padrão de select/insert já testado no Caderno/Ditado/Nivelamento).
- **Ditado implementado** (item 5 da seção 4 — só o modo "prática livre" de `DictationPage.tsx`: pool público `is_free_practice = true`, sem sessão calibrada por IA/atividade de professor):
  - `lib/features/dictation/models/dictation_score.dart`: porte exato de `scoreDictationAnswer` (`src/lib/dictation.ts`) — alinhamento de tokens por Levenshtein ponderado, mesmas constantes — **e** de `mergeDictationGrades`/`isValidDictationAiGrade` (mesmas salvaguardas contra a IA inflar nota/ignorar erro real do web).
  - `dictation_repository.dart` + `dictation_controller.dart`: busca itens do pool livre, gera áudio sob demanda via `tts-generate`, chama a edge function `dictation-grade` (IA, timeout de 8s — cai pro local se falhar/estourar, igual ao web) em `fetchAiGrade`, grava `dictation_attempts` com `score`/`mistakes`/`feedback`/`grading_source` (`'local'` ou `'hybrid'`) reais.
  - `dictation_home_page.dart` (escolha de idioma) + `dictation_session_page.dart` (tocar áudio com `just_audio`, digitar, verificar — nota combinada local+IA com indicador ✨ quando `hybrid`, mostra `feedback` da IA quando presente —, resumo da sessão).
  - **Não implementado ainda**: ditado vinculado a atividade de professor (aluno de escola).
  - Testado ponta a ponta no emulador com a conta assinante contra produção: tocar áudio, digitar resposta, chamada real à edge function `dictation-grade`, nota combinada (`hybrid`) com feedback em português e lista de erros renderizados corretamente.
  - 14 testes unitários em `test/dictation_score_test.dart` — nota local (8) + `mergeDictationGrades` (6 casos: fallback por resposta inválida, IA ignorando erro real, IA não conseguindo inflar acima do local, notas de typo preservadas).
- **Nivelamento (placement) implementado** (item 6 da seção 4 — teste adaptativo + "Começar do zero" + cooldown de retake de `PlacementPage.tsx`; pedido de retake pro professor e as ferramentas de admin ficam fora desta fatia):
  - `lib/features/placement/models/`: `placement_item.dart` (tipagem do item público, incluindo os 4 `itemKind`: `mcq`, `producao_traducao`, `ditado`, `producao_livre`), `placement_result.dart` (resultado unificado dos RPCs `placement_start_test`/`placement_submit_answer`/`placement_submit_production`/`placement_start_zero` — um único model em vez da união de tipos do TS), `placement_scoring.dart` (porte de `dictationScoreToCefr`, `placementProductionNeedsWork` e o soft-pass da escada), `placement_retake_status.dart` (recorte de `PlacementRetakeCooldownStatus`).
  - `placement_repository.dart`: RPCs `placement_language_ready`, `placement_start_test`, `placement_submit_answer`, `placement_submit_production`, `placement_start_zero`, e `placement_can_retake`/`placement_can_retake_student` (a checagem certa por papel — assinante usa cooldown de 14 dias/15 práticas com janela de graça de 72h; aluno de escola só libera com concessão do professor, sem cooldown por tempo) — todos `security definer`, resolvem o usuário via `auth.uid()` — + duas edge functions (`placement-grade-production`, `tts-generate`, igual ao Ditado).
  - `placement_home_page.dart`: checa `placement_can_retake*` ao trocar de idioma, desabilita os dois botões e mostra o motivo quando bloqueado; botão "Começar do zero (A1)" chama `placement_start_zero` e confirma por snackbar (sem tela de resultado própria, já que não há gabarito/dimensionScores nesse caminho).
  - `placement_session_page.dart` (MCQ com gabarito propositalmente escondido durante a sessão — só revelado no resultado final —, resposta livre com correção por IA ou nota local de ditado, feedback verde/vermelho, tela de resultado com nível CEFR final, barras de desempenho por dimensão e o gabarito completo).
  - **Não implementado ainda**: pedido de retake pro professor (`placementRetakeRequest.ts`, `placement_retake_grants`) quando bloqueado pro aluno de escola, atalho pra sugestão do Coach que libera retake na hora, fila de idiomas pendentes/navegação automática pro próximo idioma (o app ainda não usa `studyLanguages` pra isso), recuperação de sessão em caso de resposta perdida por queda de rede (`recoverIfAlreadyAnswered` do web).
  - Testado ponta a ponta no emulador com a conta assinante contra o banco de produção: sessão completa de 16 perguntas em inglês (MCQ certo, MCQ errado, item de listening com áudio via `tts-generate`), escada CEFR subindo/descendo corretamente, sessão completando e tela de resultado renderizando CEFR final + barras por dimensão + gabarito revelado. `placement_can_retake` chamado ao vivo e retornou "liberado" corretamente pela regra de janela de graça (72h) logo após o teste de inglês feito nesta mesma sessão. Não testado ao vivo: item de produção/ditado/produção livre dentro do teste adaptativo (exige B2+, não alcançado), `placement_start_zero` (evitado de propósito pra não alterar o CEFR de outro idioma na conta de QA reutilizável sem forma de reverter pelo app) — ambos reaproveitam padrões de RPC já testados (`placement_submit_*`/`placement_start_test`).
  - 12 testes unitários em `test/placement_scoring_test.dart` cobrindo `dictationScoreToCefr`, `placementProductionNeedsWork` e o soft-pass da escada.
- **Study Coach + Produção sob demanda implementados** (item 8 da seção 4 — só assinante; reduzido de `StudyCoachPage.tsx`/`ProductionDemandPage.tsx`):
  - `lib/features/study_coach/models/`: `study_coach_plan.dart` (`StudyCoachPlan`/`StudyCoachAction`/`StudyCoachEvidenceItem`, parse direto do JSON que a edge function/tabela já devolvem estruturado), `production_assignment.dart` (`ProductionAssignment` de `subscriber_study_assignments` kind='production', `CorrectSentenceResult` da correção).
  - `study_coach_repository.dart`: `fetchCachedPlan` lê a última linha de `subscriber_daily_study_plans` direto (sem chamar IA), `generatePlan` chama a edge function `study-coach` (`refresh: true`, sempre `uiLanguage: 'pt'`), `fetchAssignment`/`gradeProduction` pra Produção sob demanda (edge function `correct-sentence`, que já marca a assignment como `done` no servidor).
  - `study_coach_home_page.dart`: escolha de idioma + cartão do plano (resumo, focos, próximos passos tocáveis, "por que esse plano") + botão gerar/atualizar. Cada ação navega pra tela certa do app (Vocabulário/Ditado/Biblioteca/Caderno) por `type`, ou pra `ProductionDemandPage` extraindo o id da rota `/estudo/producao-demanda/:id`.
  - `production_demand_page.dart`: carrega a assignment, mostra proposta/critérios, textarea + envio, cartão de correção (explicação, versão corrigida, issues, forma natural). Só aparece no menu do Assinante (`home_shell.dart`), não do Aluno de escola.
  - Ações do plano abrem Caderno já filtrado em notas de IA quando o tipo é `ai_notes_review`. Home do assinante mostra o plano em cache, assignments abertas e o banner CEFR.
  - **Não implementado ainda**: localização do conteúdo por idioma da UI (`studyCoachCopy.ts` — app só gera/mostra em português).
  - Testado ponta a ponta no emulador com a conta assinante contra produção: gerar plano (chamada real à IA, ~30s, resposta em português com resumo/focos/3 próximos passos/evidências), ler o plano em cache numa segunda visita sem chamar a IA de novo, navegar de uma ação do plano pra tela do Ditado. Não testado ao vivo: `ProductionDemandPage` (o plano gerado não teve ação de produção pendente nesta conta) — o padrão de chamada (`functions.invoke`) é o mesmo já validado em `gradeProduction`/`tts-generate`.
- **Perfil + Status da assinatura implementados** (as duas rotas do assinante que ainda não existiam no app — `/estudo/perfil` e a parte de leitura de `/assinatura`; reduzido de `SubscriberProfilePage.tsx`/`SubscriptionPage.tsx`):
  - `AppUser` (`lib/core/session/app_user.dart`) ganhou `studyLanguages`/`cefrLevelByLanguage`, lidos agora pelo `AuthController` a partir de `profiles.profile_languages`/`profiles.cefr_levels` (mesmo parse de `parseStudyLanguages`/`parseCefrLevelsFromProfile` do web).
  - `lib/features/profile/`: `profile_repository.dart` (`update` em `profiles` — só nome e idiomas de estudo) e `subscriber_profile_page.dart` (dados da conta editáveis, chips de idioma de estudo, nível CEFR por idioma com atalho pro Nivelamento).
  - `lib/features/subscription/subscription_status_page.dart`: cartão só leitura (plano, status, fim do trial ou próxima cobrança) a partir do `SubscriptionInfo` já carregado no `AuthController` — sem chamada nova ao Supabase. Cancelar/trocar cartão/histórico de pagamentos ficam fora (política de compra só no site, seção 1 do planejamento.md).
  - Acessível pelos botões "Perfil"/"Assinatura" no `home_shell.dart`, só pro Assinante.
  - Cooldown de retake por idioma, progresso de skills (`skill_list_progress`) e atalho de nivelamento já com o idioma da linha (`PlacementHomePage.initialLanguage`).
  - **Não implementado ainda**: histórico de pagamentos, trocar cartão, cancelar assinatura (compra continua só no site).
  - Testado ponta a ponta no emulador com a conta assinante contra produção: ler perfil (nome/e-mail/idiomas/nível — o nível A1 em inglês bateu com o resultado do Nivelamento testado antes nesta sessão, confirmando que `placement_write_cefr` persiste e o Perfil lê certo), editar e salvar idiomas de estudo (adicionar Espanhol, confirmar refresh automático, reverter), e a tela de assinatura mostrando plano mensal/status ativa da conta de teste.
  - **Tradução inline**: painel "Tradução ao lado do texto" (idioma alvo ≠ idioma do texto), frase a frase com cache em `text_translation_cache` / `owned_text_translation_cache` e `vocab-enrich` `mode=translation_only`, igual ao site.
  - **Rotas nomeadas**: `/estudo/vocabulario`, `/estudo/biblioteca?text_id=`, `/estudo/ditado?focus=calibrated`, `/estudo/nivelamento/:lang`, `/estudo/assistente`, `/estudo/producao-demanda/:id`, `/estudo/caderno?tab=ai`, `/estudo/perfil`, `/assinatura` — mesmas paths do `App.tsx`.
  - **Deep link de senha**: `/redefinir-senha` + esquema `connectlang://redefinir-senha`.
  - **TTS do vocabulário**: botão de ouvir na lista e nos flashcards (`tts-generate`).

## Ambiente de desenvolvimento (nesta máquina)

Tudo instalado e configurado, variáveis já persistidas em `~/.zshrc` (bastando abrir um terminal novo):

- Flutter 3.44.9 (via Homebrew: `brew install --cask flutter`)
- Java: `openjdk@21` (via Homebrew formula, **não** o cask `temurin` — esse pede sudo e falhou)
- Android SDK: `android-commandlinetools` (via Homebrew, sem precisar da GUI do Android Studio)
- Emulador criado: `connectlang_pixel` (Pixel 7, Android 16 / API 36, `google_apis` arm64-v8a). `hw.keyboard=yes` no `~/.android/avd/connectlang_pixel.avd/config.ini` (o AVD nasceu com isso `=no` via linha de comando — sem essa flag o teclado físico do Mac não funciona dentro do emulador, só o teclado virtual).
- `JAVA_HOME`, `ANDROID_HOME`, `ANDROID_SDK_ROOT` e PATH configurados no `~/.zshrc`
- `flutter doctor`: Android 100% verde. **iOS pendente** — só as Command Line Tools da Apple estão instaladas, falta:
  1. Instalar o Xcode completo (App Store — precisa do seu Apple ID, não automatizável por aqui)
  2. `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`
  3. `sudo xcodebuild -runFirstLaunch`
  4. Instalar CocoaPods (`brew install cocoapods` ou `sudo gem install cocoapods`)

## Como retomar

```bash
cd ~/ConnectLang-APP

# 1. Credenciais locais (nunca commitadas) — copiar do repo web:
cp assets/.env.example assets/.env
# preencher SUPABASE_URL e SUPABASE_PUBLISHABLE_DEFAULT_KEY com os mesmos valores
# de VITE_SUPABASE_URL / VITE_SUPABASE_PUBLISHABLE_DEFAULT_KEY do verb-flow-hub/.env

flutter pub get

# 2. Subir o emulador (se não estiver rodando):
emulator -avd connectlang_pixel &

# 3. Rodar o app:
flutter run
```

## Próximo passo

Pendências do **assinante** cobertas nesta fatia: home/dashboard, categorias/arquivados/base/explicar/frases/TTS no Vocabulário, filtro de IA + `NotebookFab` no Caderno, **ditado calibrado/reforço/diagnóstico**, **histórico + sync no Coach**, **biblioteca com textos próprios/TTS/captura/retry/tradução inline**, **rotas `/estudo/...` iguais ao site**, **deep link de senha**.

O que ainda falta pro assinante (não bloqueia o uso diário):
- Histórico de pagamentos / troca de cartão / cancelar (compra continua só no site, seção 1 do planejamento.md)
- Universal/App Links HTTPS (o esquema `connectlang://redefinir-senha` já existe; precisa cadastrar essa URL em Auth > Redirect URLs no Supabase)

Depois: item 7, **Aluno de escola** (atividades, leitura/produção, `submissions`, `lesson_plans`).

Nota pra próxima sessão de testes no emulador: o `adb shell input text` neste ambiente ocasionalmente perde/desloca caracteres digitados (visto tanto no e-mail/senha do login quanto em campos do app) — sempre conferir o `text=` real via `adb exec-out uiautomator dump` antes de submeter um formulário, em vez de confiar que o texto enviado chegou completo.
