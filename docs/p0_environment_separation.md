# P0.2 — Ambiente e configuração (DEV / STAGING / PRODUCTION)

## 1. Status da análise

Status geral: `PARCIAL / NÃO CONFIGURADO PARA PRODUÇÃO`.

O repositório contém artefatos de configuração Firebase, mas não há separação formal entre ambientes. O código e os artefatos de configuração apontam para um único projeto Firebase (`project-fdb4b65e-57ff-4b13-afc`), e não há evidência local de ambientes distintos para desenvolvimento, staging e produção.

### Evidências encontradas

- `firebase.json` com configuração do projeto Firebase e emuladores.
- `lib/firebase_options.dart` com `projectId` único e `apiKey` definidos no código.
- `android/app/google-services.json` com configurações específicas do app e projeto.
- `.github/workflows/build_release.yml` usa `secrets.ADMIN_WHITELIST` para build de release, o que demonstra uso de segredos em CI, mas sem ambiente separado por projeto.

### Risco principal

A app/CI/repo atual não demonstram isolamento de ambiente para `DEV`, `STAGING` e `PRODUCTION`. Em produção, isso pode resultar em:

- dados cruzados entre ambientes;
- uso de projeto errado em build/release;
- vazamento de configurações para repositórios públicos;
- risco de produção sendo atingida por testes ou by-pass de secrets.

---

## 2. Estrutura recomendada

### DEV

- projeto Firebase isolado para desenvolvimento local e testes
- dados sintéticos ou anonimizados
- regras de segurança menos rígidas apenas para ciclo de desenvolvimento
- build local com `flutter run` 
- uso de emuladores Firebase para Firestore, Storage e Functions

### STAGING

- projeto Firebase separado
- dados de teste representativos, mas não prod
- validação de release candidate
- smoke tests e regras de segurança
- revisão administrativa e autorização em ambiente imitado

### PRODUCTION

- projeto Firebase exclusivo
- backup/DR ativo
- observabilidade e alertas
- secrets armazenados no sistema de segredos da plataforma
- RBAC rigoroso e revisão de deploy

---

## 3. Requisitos de segurança para configuração

### Regras obrigatórias

- Nunca versionar secrets reais.
- Nunca commitar APIs keys reais, tokens, service account JSON, ou credenciais de produção.
- Usar Firebase Console/GCP Secret Manager para material sensível.
- Separar projeto por ambiente.
- Travar deploys por branch e por ambiente.
- Não reutilizar `apiKey` de produção em dev/staging.
- Manter `android/app/google-services.json` e `lib/firebase_options.dart` em projeto correto e separado por ambiente.

### Ações seguras no repositório

- manter arquivos de exemplo com placeholders;
- documentar a configuração de cada ambiente;
- usar `--dart-define` e `secrets` na CI para valores dinâmicos;
- garantir que os builds de release não passem `projectId` ou `client_id` de produção em branches públicas.

---

## 4. Configuração mínima recomendada

### Variáveis sensíveis

- `FIREBASE_PROJECT_ID`
- `FIREBASE_API_KEY`
- `FIREBASE_APP_ID`
- `FIREBASE_AUTH_DOMAIN`
- `FIREBASE_STORAGE_BUCKET`
- `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_MEASUREMENT_ID`
- `ADMIN_WHITELIST`
- `GOOGLE_CLIENT_ID`
- `GOOGLE_CLIENT_SECRET` (quando aplicável)

### Padrão seguro

Usar placeholders e geração de config por ambiente, por exemplo:

- `dev`: projeto separado com configuração de `debug`
- `staging`: projeto separado com dados de teste realistas
- `prod`: projeto dedicado, secrets gerenciados fora do repositório

---

## 5. Evidência do projeto local

Como verificado no código:

- `lib/firebase_options.dart` contém chaves e configurações do projeto atual.
- `android/app/google-services.json` contém configuração e identificadores do app Firebase.
- Não há `.env` real no repositório.
- Não há `dev`, `staging` e `prod` em arquivos de configuração explícitos.

`SECRET/KEY ENCONTRADO — localização: lib/firebase_options.dart`  
`SECRET/KEY ENCONTRADO — localização: android/app/google-services.json`

Não copie os valores reais; mantenha os artefatos protegidos e fora de repositórios públicos.

---

## 6. Ações manuais necessárias no Firebase Console / GCP

`AÇÃO MANUAL NECESSÁRIA`

Para separar ambientes de forma real, o time de Cloud/Firebase precisa executar no console:

- criar `DEV`, `STAGING` e `PRODUCTION` como projetos distintos;
- gerar ou migrar `google-services.json` e `FirebaseOptions` para cada ambiente;
- configurar storage buckets separados;
- configurar e separar Firestore databases / permissions;
- separar Cloud Functions e Functions em projetos distintos;
- revisar `custom claims`, owner/admin e RBAC em cada ambiente;
- configurar Secrets Manager e CI/CD environment variables por ambiente;
- validar `Google Sign-In` e `FCM` em cada projeto real.

Estas ações não podem ser validadas localmente sem acesso ao projeto real do Firebase.

---

## 7. Implementação segura feita neste repositório

### Arquivos adicionados

- `.env.example`
- `scripts/firebase_env_validate.ps1`

### Conteúdo seguro

- placeholders explícitos para chaves/configuração por ambiente;
- script de verificação de presença de config e envio de alertas sem expor valores reais;
- documentação da estratégia de ambiente.

### O que não foi implementado

- não foi criado projeto real de staging/production;
- não foi alterado o Firebase real;
- não foi movido o app para ambiente separado;
- não foi alterado o `google-services.json` real do projeto local.

---

## 8. Procedimento recomendado para a equipe de operação

1. Criar projetos distintos para `DEV`, `STAGING` e `PRODUCTION`.
2. Definir owner e permissões por ambiente.
3. Gerar configuração correspondente para cada ambiente.
4. Registrar no CI/CD por environment.
5. Validar que builds de produção nunca apontem para `dev`/`staging`.
6. Validar `Google Sign-In`, Storage, Firestore e FCM em cada ambiente.
7. Rodar smoke tests de integração por ambiente.
8. Criar checklist de deploy com aprovação do owner.

---

## 9. Conclusão prática

O projeto possui configuração Firebase e CI, mas ainda não possui separação real de ambientes. A infraestrutura necessária para `DEV`, `STAGING` e `PRODUCTION` precisa ser montada no Firebase Console/GCP e validada em ambientes reais antes de considerar a plataforma pronta para operação e produção.
