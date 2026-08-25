# ConnectLang App

App mobile (Flutter, Android/iOS) do ConnectLang, para os perfis **Aluno** e **Assinante**. Reaproveita 100% o mesmo backend Supabase do repo web (`verb-flow-hub`) — nenhum backend novo.

- **Planejamento** (escopo, arquitetura, decisões): [planejamento.md](planejamento.md)
- **Estado atual / como retomar o desenvolvimento**: [PROGRESSO.md](PROGRESSO.md)

## Setup rápido

```bash
cp assets/.env.example assets/.env
# preencher com os mesmos valores de VITE_SUPABASE_URL / VITE_SUPABASE_PUBLISHABLE_DEFAULT_KEY
# do repo web (verb-flow-hub/.env)

flutter pub get
flutter run
```
