# Progresso — retomar a partir daqui

Resumo do que já foi decidido e feito até agora, pra continuar numa sessão nova (abrindo o Claude Code direto nesta pasta, `~/Documents/ConnectLang-APP`). O plano completo está em [planejamento.md](planejamento.md); este arquivo é só o "estado atual".

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
- `lib/main.dart` atual é só uma tela de bootstrap ("Supabase inicializado") — **nenhuma feature real foi implementada ainda**, isso é o próximo passo.
- Testado ponta a ponta: `flutter build apk --debug` + instalado no emulador Android, app abre e conecta no Supabase com sucesso (confirmado via screenshot).

## Ambiente de desenvolvimento (nesta máquina)

Tudo instalado e configurado, variáveis já persistidas em `~/.zshrc` (bastando abrir um terminal novo):

- Flutter 3.44.9 (via Homebrew: `brew install --cask flutter`)
- Java: `openjdk@21` (via Homebrew formula, **não** o cask `temurin` — esse pede sudo e falhou)
- Android SDK: `android-commandlinetools` (via Homebrew, sem precisar da GUI do Android Studio)
- Emulador criado: `connectlang_pixel` (Pixel 7, Android 16 / API 36, `google_apis` arm64-v8a)
- `JAVA_HOME`, `ANDROID_HOME`, `ANDROID_SDK_ROOT` e PATH configurados no `~/.zshrc`
- `flutter doctor`: Android 100% verde. **iOS pendente** — só as Command Line Tools da Apple estão instaladas, falta:
  1. Instalar o Xcode completo (App Store — precisa do seu Apple ID, não automatizável por aqui)
  2. `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`
  3. `sudo xcodebuild -runFirstLaunch`
  4. Instalar CocoaPods (`brew install cocoapods` ou `sudo gem install cocoapods`)

## Como retomar

```bash
cd ~/Documents/ConnectLang-APP

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

Seguir a ordem da seção 4 do `planejamento.md`, começando pela **base** (item 1): tela de login (`lib/features/auth`) usando `supabase_flutter` (email/senha, mesmo fluxo do `AuthContext.tsx` do web), depois `AuthController` (Riverpod) carregando `profiles`/`subscriptions`, e o shell de navegação com guards por role via `go_router`.

Depois da base, a feature recomendada pra validar o pipeline auth → RLS → UI é **Vocabulário + flashcards SRS**, por ser a mais isolada (ver seção 6 do planejamento.md).
