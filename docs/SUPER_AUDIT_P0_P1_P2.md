# LaBomba — Super Audit

## 1. Executive Summary

O projeto está em um estado de saúde relativamente bom em build, análise estática e testes, mas não está pronto para produção devido a riscos de segurança e regras de acesso em Storage. O maior problema confirmado é a permissividade de leitura em arquivos de usuário e stories: qualquer usuário autenticado pode ler objetos em paths `/users/{userId}/...` e `/users/{userId}/stories/...` sem verificar relação de propriedade, follower ou privacidade. Isso é um risco de vazamento de conteúdo privado e deve ser tratado como P0.

O segundo bloqueador confirmado é a inconsistência entre a regra de Storage para chat e a estrutura real do documento de chat no Firestore: a regra usa `participants`, mas o modelo de dados usa `members`. Isso faz a regra de upload de mídia em chat estar fora do fluxo real e potencialmente impedir ou quebrar o uso de arquivos de chat.

Além disso, há evidência de duplicidade arquitetural em `ChatService`: existem duas implementações com responsabilidades overlapping em `lib/features/chat/services/chat_service.dart` e `lib/features/social/services/chat_service.dart`, com APIs diferentes e comportamentos divergentes. Isso é risco de regressão e ambiguidade de manutenção.

Resumo da saúde atual:

- Build Android debug: validado com sucesso
- `dart analyze --fatal-infos`: validado com sucesso
- `flutter test`: validado com sucesso
- Firebase project config: validado com sucesso
- Firebase rules: parse ok, mas algumas regras sem alinhamento de segurança e data model
- Produção: `NÃO PRONTO` por causa de P0s abertos

## 2. Current Build Status

| Verificação | Status | Evidência |
| --- | --- | --- |
| `dart analyze --fatal-infos` | VALIDADO | Saída: "No issues found!" |
| `flutter test` | VALIDADO | Saída: "00:19 +24: All tests passed!" |
| `flutter build apk --debug` | VALIDADO | APK gerado em `build/app/outputs/flutter-apk/app-debug.apk` |
| `git status --short` | VALIDADO, mas há alterações de trabalho | Repositório com conteúdo já em processo e não alterado nesta auditoria |

Conclusão: a base de build e testes está estável, mas a prontidão para produção continua bloqueada por riscos de segurança e regras de dados.

## 3. Firebase Status

| Item | Status | Observação |
| --- | --- | --- |
| Firebase project | VALIDADO | `labomba-b202a` alinhado com `firebase.json`, `firebase_options.dart` e `google-services.json` |
| Firestore rules | VALIDADO em parse | As regras carregam sem erro de parsing |
| Storage rules | VALIDADO em parse | Regras carregam sem erro de parsing, mas há falha de política de acesso |
| Auth/Firestore/Storage emulator | VALIDADO | Inicialização do emulador foi executada com sucesso |
| Firebase config | VALIDADO | Alinhado ao projeto correto |

## 4. Flutter Architecture

Estrutura geral do app segue um padrão de feature + providers + services, com divisão razoável entre `lib/features`, `lib/services` e `lib/views`. O projeto não é caótico, mas há alguns sinais de arquitetura em proliferação.

### Observações confirmadas

- Há um `ChatProvider` dedicado em `lib/features/chat/providers/chat_provider.dart`.
- Existe um `ChatService` separado em `lib/features/chat/services/chat_service.dart`.
- Existe um segundo `ChatService` em `lib/features/social/services/chat_service.dart` com API diferente e regras de envio distintas.
- O serviço base `StorageService` em `lib/services/storage_service.dart` é um contrato abstrato, mas a fábrica `defaultStorageService()` lança `UnimplementedError`, o que indica um padrão de uso dependente de platform-specific constructors.

### Risco arquitetural confirmado

- duplicidade de implementação de chat
- acoplamento de UI e regras de negócio em diferentes camadas
- risco de comportamento divergente entre social e chat principal

## 5. Firestore

| Collection | Quem lê | Quem escreve | Quem pode alterar | Cliente ou backend | Rule correspondente | Risco |
| --- | --- | --- | --- | --- | --- | --- |
| `users/{userId}` | owner, followers, público, admin/server | owner, server | owner; server | cliente + backend | `match /users/{userId}` | MÉDIO |
| `users/{userId}/stories/{storyId}` | owner, seguidores, público | owner, server | owner/server | cliente + backend | `match /users/{userId}/stories/{storyId}` | MÉDIO |
| `chats/{chatId}/messages/{messageId}` | membros do chat | membros do chat | sender + membros | cliente + backend | `match /chats/{chatId}/messages/{messageId}` | MÉDIO |
| `posts/{postId}` | usuários autenticados | author/server | author/server | cliente + backend | `match /posts/{postId}` | BAIXO |
| `posts/{postId}/comments/{commentId}` | usuários autenticados | author/server | author/server | cliente + backend | `match /posts/{postId}/comments/{commentId}` | BAIXO |
| `reports/{reportId}` | backend/admin | authenticated users + server | server + owner-like flows | cliente + backend | `submitReport` callable + rules | BAIXO |
| `admin_requests/{requestId}` | privileged admins | privileged actors + server | admin/server | cliente + backend | `admin_requests` rules | MÉDIO |
| `system_events` | server/admin | server | server | backend | `system_events` not user-writable | BAIXO |

### Observações

- O projeto faz uso de regras com `isServer` / `isAdmin` / `owner` para limitar ações privilegiadas.
- Há proteção razoável para ações sensíveis administrativas.
- O maior problema em Firestore não são as regras gerais; o problema principal está em Storage, porque as regras de leitura são excessivamente abertas.

## 6. Storage

| Path | Upload | Read | Delete | Owner check | MIME check | Size check | Risco |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `/users/{userId}/avatar.*` | `isValidUserOwnedFile` | `if isAuth()` | `isOwner(userId)` | SIM | SIM | 2 MB | P0 |
| `/users/{userId}/stories/{storyId}/{fileName}` | `isValidUserOwnedFile` | `if isAuth()` | `isOwner(userId)` | SIM | SIM | 25 MB | P0 |
| `/users/{userId}/{fileName}` | `isValidUserOwnedFile` | `if isAuth()` | `isOwner(userId)` | SIM | SIM | 25 MB | P0 |
| `/users/{userId}/memories/{allPaths=**}` | `isValidUserOwnedFile` | `if isAuth()` | `isOwner(userId) || isAdmin()` | SIM | SIM | 25 MB | P1 |
| `/posts/{postId}/{fileName}` | `isValidPostUpload` | `if isAuth()` | `owner == uid` | SIM | SIM | 25 MB | BAIXO |
| `/chats/{chatId}/{fileName}` | `isValidChatUpload` | `if isAuth()` | `owner == uid` | PARCIAL | SIM | 25 MB | P1 |
| `/site_assets/{allPaths=**}` | admin-only | `true` | admin-only | SIM | SIM | 10 MB | BAIXO |

### Confirmado — P0: abertura excessiva de leitura em Storage

Arquivo relevante: [storage.rules](../storage.rules)

Evidência direta:

- `match /users/{userId}/avatar.* { allow read: if isAuth(); }`
- `match /users/{userId}/stories/{storyId}/{fileName} { allow read: if isAuth(); }`
- `match /users/{userId}/{fileName} { allow read: if isAuth(); }`

Isso significa que qualquer usuário autenticado pode tentar ler qualquer avatar, story ou arquivo em qualquer path do padrão `users/{userId}/...` desde que conheça o caminho. A regra não considera: perfil privado, relação de amizade, follower, owner ou a natureza do conteúdo. Em uma plataforma social, isso é uma falha de privacidade e vazamento de dados.

Impacto: vazamento de imagem de perfil, stories privadas e arquivos pessoais.
Severidade: `CRÍTICA`

### Confirmado — P1: regra de upload de chat não bate com o model real

Arquivo relevante: [storage.rules](../storage.rules)

Evidência direta:

- Storage: `firestore.get(/databases/default/documents/chats/$(chatId)).data.participants`
- Firestore: `match /chats/{chatId}` usa `resource.data.members` e `request.auth.uid in get(...).data.members`

As duas estruturas são diferentes. O nome do campo de membros é inconsistente (`participants` vs `members`). Isso torna a regra de upload em chat sem caminho consistente e pode impedir que uploads de mídia do chat funcionem como esperado. O problema é confirmável no código e não é apenas teoria.

Impacto: upload de mídia em chat falha ou fica bloqueado sem ter a correção explícita.
Severidade: `ALTA`

## 7. Cloud Functions

### Mapa de triggers

| Trigger | Ação | Escrita | Notificação | Estado |
| --- | --- | --- | --- | --- |
| `onUserCreated` | registra evento de onboarding | `system_events` + `system_metrics` | nenhuma | VALIDADO |
| `onPostCreated` | registra criação de post | `system_events` | nenhuma | VALIDADO |
| `onStoryCreated` | registra story | `system_events` | nenhuma | VALIDADO |
| `onPostReactionCreated` | notifica dono do post | `users/{uid}/notifications` | FCM | PARCIAL |
| `onCommentReactionCreated` | notifica autor do comentário | `users/{uid}/notifications` | FCM | PARCIAL |
| `onChatMessageCreated` | manda FCM para destinatários | `system_events` | FCM | RISCO |
| `onGroupMessageCreated` | manda FCM para todos os membros | sem escrita persistente direta | FCM | RISCO |
| `submitReport` | cria relatório com idempotência | `reports` | nenhuma | VALIDADO |
| `submitAdminRequest` | cria request de action admin | `admin_requests` | nenhuma | VALIDADO |

### Observações

- Há uso consistente de `sanitizeForLogs`, o que é uma boa prática.
- Há tentativas de evitar duplicação em alguns triggers, especialmente em `submitReport` e `submitAdminRequest`.
- `onChatMessageCreated` deriva destinatários a partir de `recipientId`, `to` ou parse de `chatId`; não revisa se o destinatário é membro real do chat antes de disparar FCM.
- Esse é um risco de fanout indevido e notificação para usuário incorreto se o payload do cliente for manipulado ou o chatId não for coerente.

## 8. Authentication

A autenticação em geral parece estar bem centralizada em `lib/services/auth_service.dart` e as claims admin são tratadas corretamente em backend via `submitAdminRequest` e `assignRoleClaims`.

### Situação

- `submitAdminRequest` exige autenticação e validação adicional de claims.
- `ensureFreshAdminAuth` exige reautenticação recente para ações sensíveis.
- Há proteção lógica para `owner` / `admin` / `moderator`.

Conclusão: a autenticação não está quebrada, mas há risco de permissões de leitura de Storage que podem expor conteúdo mesmo com autenticação válida.

## 9. Chat / Realtime

### Cenários avaliados

| Cenário | Status |
| --- | --- |
| A. envio duplo rápido | SEGURO |
| B. rede cai após envio | SEGURANÇA/RETRY operacional |
| C. app fecha antes ACK | PARCIAL, depende do Outbox |
| D. app abre novamente | PARCIAL, depende de persistência | 
| E. outbox reprocessa | SEGURO, com guard de idempotência |
| F. listener realtime entrega evento novamente | SEGURO |
| G. duas chamadas simultâneas `sendMessage()` | SEGURO |
| H. troca rápida de conversa | SEGURO |
| I. sair da tela durante operação assíncrona | RISCO, depende do lifecycle |

### Observações confirmadas

- O arquivo [lib/features/chat/services/chat_service.dart](../lib/features/chat/services/chat_service.dart) guarda `idempotencyKey` e compara `existing.exists` antes de escrever.
- O provider [lib/features/chat/providers/chat_provider.dart](../lib/features/chat/providers/chat_provider.dart) possui guard de `_inFlightMessageKeys` para bloquear envio duplicado concorrente.
- Existe também `OutboxService` com proteção contra reprocessamento.

### Problema de arquitetura confirmado

Há duas implementações para chat diferentes em duas áreas do app. Isso é um risco para comportamento inconsistente e acoplamento dividido.

## 10. Outbox / Offline

A camada de outbox está ativa e foi reforçada em correções anteriores. Há guard condizente para duplicação em mensagens de chat, com `existing.exists` e `idempotencyKey`.

Conclusão: o mecanismo de outbox e retry para chat está muito melhor do que a média do projeto, mas sua eficácia depende do uso correto da mesma API em todas as telas e serviços.

## 11. Feed / Pagination

O feed usa `orderBy('isPinned')` e `orderBy('createdAt')` com `startAfterDocument`, que é uma abordagem razoável para paginação. Há um `FeedPaginationManager` em [lib/services/feed_pagination_manager.dart](../lib/services/feed_pagination_manager.dart) e a página [lib/features/social/views/social_feed_page.dart](../lib/features/social/views/social_feed_page.dart) também conduz a mesma lógica de paginação Stateful.

Risco observado: duplicação de lógica de paginação entre manager e página. Isso aumenta chance de divergência na UI e no cursor. Não é P0, mas é P1/P2 pela manutenção.

## 12. Social Graph

A lógica de follow/request/private account está estruturada e há referências a `followers`, `following`, `incomingFollowRequests`, `outgoingFollowRequests`. O que foi encontrado é que a parte de regras de Storage não bloqueia leitura de arquivos sensíveis dos usuários; o social graph em si não está quebrado por evidência direta, mas mantém complexidade alta e risco de inconsistência se não for testado end-to-end.

## 13. Stories

As stories têm regras de expiração no Firestore e `createdAt >= request.time - duration.value(24, 'h')`. Isso é boa prática. O risco principal é novamente a leitura aberta em Storage e o fato de cada story poder ser acessada por qualquer usuário autenticado se o caminho for conhecido.

## 14. Profiles

Perfil e privacidade têm regras de leitura condicionais em Firestore, mas o comportamento de leitura de arquivos de avatar e imagens de perfil em Storage é permissivo demais. Isso representa a maior falha observada na camada de dados do app.

## 15. Memories

Memories têm regras em Storage que são mais armações de propriedade do usuário do que mecanismo de privacidade. Como a regra de `read` é aberta para todos usuários autenticados, um usuário autenticado pode acessar objetos de `users/{userId}/memories/...` sem relação direta, se souber o caminho.

## 16. Notifications

As notificações são persistidas em `users/{uid}/notifications` e há triggers de FCM para reação e chat. O design é funcional e há algumas medidas de idempotência e logging sanitizado.

Risco: fluxo de chat e de reação não valida destinatário de forma estrita no backend antes de enviar FCM. Isso é confirmável em código, mas não é uma falha totalmente acionada sem manipulação do cliente.

## 17. Security

### Vulnerabilidades confirmadas

1. `storage.rules` permite leitura pública entre usuários autenticados para arquivos de perfil e story.
2. `onChatMessageCreated` usa dados do cliente para inferir destinatários sem validação de membership real.
3. `ChatService` duplicado e `ChatProvider`/`ChatService` inconsistentes podem permitir divergência entre API social e chat principal.

### Classificação

- `CRÍTICA`: leitura aberta em Storage para arquivos de usuário
- `ALTA`: chat media rule mismatch (`participants` x `members`)
- `MÉDIA`: fanout de FCM baseado em payload de cliente
- `MÉDIA`: duplicidade arquitetural em chat

## 18. UX

A experiência geral tem telas, loading states, empty states e navegação. Isso está em um nível razoavelmente funcional para um app de social. O problema principal não é UX visual; é consistência de dados e segurança.

## 19. Performance

O app tem alguns sinais de redundância:

- múltiplas implementações de chat
- lógica de paginação duplicada
- stream/listeners potenciais em várias telas
- caching local com `StorageService` e `PlatformStorageService` em vários pontos

Não há evidência de falha grave de performance por ausência de cache direto, mas há risco de repetição e sobrecarga em operações de feed e chat.

## 20. Android / Release

| Verificação | Status |
| --- | --- |
| `flutter build apk --debug` | VALIDADO |
| Configuração Firebase Android | VALIDADO |
| AGP / Gradle / Kotlin | VALIDADO com ajuste de plugin para Crashlytics |
| Release signing | NÃO VALIDADO — requer signing real | 
| `flutter build apk --release` | NÃO EXECUTADO / NÃO VALIDADO sem configuração de assinatura |

Conclusão: debug build está verde; release build exige configuração de assinatura e não foi validada nesta auditoria.

## 21. Testing

| Funcionalidade | Teste unitário | Widget | Integration | Rules | Backend | Cobertura |
| --- | --- | --- | --- | --- | --- | --- |
| chat/idempotência | SIM | NÃO | NÃO | NÃO | NÃO | BOA |
| social feed | NÃO | PARCIAL | NÃO | NÃO | NÃO | MÉDIA |
| stories | NÃO | NÃO | NÃO | PARCIAL | NÃO | BAIXA |
| security rules | NÃO | NÃO | NÃO | PARCIAL | NÃO | MÉDIA |
| admin / privileged actions | NÃO | NÃO | NÃO | NÃO | PARCIAL | MÉDIA |
| storage validation | NÃO | NÃO | NÃO | PARCIAL | NÃO | BAIXA |

A suite atual cobre alguns casos de chat, mas faltam testes de regras de Storage e casos de privacidade em arquivos sensíveis.

## 22. Code Quality

O código em geral é legível e existe evidência de correções recentes. Há alguns padrões positivos:

- logging sanitizado;
- idempotência aplicada em chat e reports/admin requests;
- uso de `request.auth.uid` e custom claims para acesso privilegiado;
- build e testes passam.

Mas a qualidade da arquitetura e da segurança está comprometida por:

- duplicidade de implementação;
- regras de storage excessivamente permissivas;
- mismatch de campo em chat.

## 23. Duplicate Implementations

### 1. Chat service duplicado

Arquivos:

- [lib/features/chat/services/chat_service.dart](../lib/features/chat/services/chat_service.dart)
- [lib/features/social/services/chat_service.dart](../lib/features/social/services/chat_service.dart)

Por que existem: a equipe parece ter criado uma implementação de chat principal e outra implementação social/feature. O projeto usa ambos em diferentes áreas.

Quem usa cada uma: aparentemente os fluxos de chat principal e social usam APIs diferentes.

Risco: comportamento divergente entre duas APIs de chat; bugs de compatibilidade; regressões futuras.

Severidade: `MÉDIA / ALTA`

## 24. Missing Features

Não há evidência de ausência funcional zero para o escopo principal, mas existem lacunas relevantes de validação:

- Storage tests ausentes;
- regras de privacidade em arquivos sensíveis não validadas em testes;
- backend tests para FCM fanout e `chatId` membership validation ausentes;
- validation of release build absent.

## 25. Confirmed Bugs

### BUG-01 — P0: Storage abre leitura de arquivos de usuário para qualquer usuário autenticado

- Arquivo: [storage.rules](../storage.rules)
- Região: regras de `avatar`, `stories`, e `users/{userId}/{fileName}`
- Comportamento observado: `allow read: if isAuth()`
- Por que é problema: qualquer usuário autenticado consegue tentar ler qualquer objeto com esse path
- Impacto: vazamento de dados sensíveis e privacidade
- Severidade: `CRÍTICA`
- Como validar: tentar ler um objeto de outro usuário autenticado com token de outro usuário e verificar que o bucket responde
- Recomendação: exigir owner/follower/privado e checar `request.auth.uid == userId` para arquivos sensíveis

### BUG-02 — P1: mismatch de campo em chat (`participants` vs `members`)

- Arquivo: [storage.rules](../storage.rules) e [firestore.rules](../firestore.rules)
- Região: regra `isValidChatUpload` em Storage e `match /chats/{chatId}` em Firestore
- Comportamento observado: `participants` em uma parte e `members` em outra
- Por que é problema: a regra de upload de mídia do chat fica inconsistente com o model real do chat
- Impacto: upload de mídia em chat falha ou é bloqueado sem caminho real
- Severidade: `ALTA`
- Como validar: verificar propriedade `participants` em documentos reais de chat e checar se o app usa `members`
- Recomendação: unificar o nome do campo; usar o mesmo em chats e em Storage

### BUG-03 — P1: chat/fanout usa payload do cliente para inferir destinatários

- Arquivo: [backend/functions/src/index.ts](../backend/functions/src/index.ts)
- Região: `onChatMessageCreated`
- Comportamento observado: destinatários vêm de `msg?.recipientId`, `msg?.to`, ou parse do `chatId`
- Por que é problema: sem validar membership real do chat, um payload malicioso ou inconsistente pode disparar FCM para usuários errados
- Impacto: notificações indevidas e fanout fora do escopo do chat
- Severidade: `ALTA`
- Como validar: simular payload manipulado com `recipientId` externo e verificar do backend
- Recomendação: buscar o documento do chat e validar `request.auth.uid in members` / `participants` antes do fanout

### BUG-04 — P1: duplicidade arquitetural do `ChatService`

- Arquivo: [lib/features/chat/services/chat_service.dart](../lib/features/chat/services/chat_service.dart) e [lib/features/social/services/chat_service.dart](../lib/features/social/services/chat_service.dart)
- Comportamento observado: duas implementações diferentes para o mesmo domínio
- Por que é problema: comportamento divergente e manutenção complexa
- Impacto: regressões em chat social e chat principal
- Severidade: `MÉDIA`
- Como validar: identificar o código real usado por cada tela e comparar endpoints e payloads
- Recomendação: unificar em um único serviço ou interface com contrato único

## 26. P0

### P0-01 — Leitura de arquivos sensíveis de usuário aberta para todo usuário autenticado
- Arquivo: [storage.rules](../storage.rules)
- Impacto: vazamento de conteúdo privado
- Severidade: `CRÍTICA`
- Solução recomendada: limitar read a owner, followers, ou público explícito; não `isAuth()` universal
- Dependências: regras de privacidade de perfil e stories

### P0-02 — Chat media rule inconsistente com o modelo real do chat
- Arquivo: [storage.rules](../storage.rules), [firestore.rules](../firestore.rules)
- Impacto: upload de mídia em chat falha ou é bloqueado
- Severidade: `ALTA`
- Solução recomendada: unificar `members`/`participants` e validar membership antes de upload
- Dependências: model de chat e regras de storage

## 27. P1

### P1-01 — Fanout de FCM no chat depende de dados do cliente
- Arquivo: [backend/functions/src/index.ts](../backend/functions/src/index.ts)
- Impacto: notificações indevidas
- Severidade: `ALTA`
- Solução recomendada: validar chat membership no backend antes de enviar
- Dependências: backend trigger + chat model

### P1-02 — Duplicidade de implementação de `ChatService`
- Arquivo: [lib/features/chat/services/chat_service.dart](../lib/features/chat/services/chat_service.dart), [lib/features/social/services/chat_service.dart](../lib/features/social/services/chat_service.dart)
- Impacto: divergência funcional e manutenção
- Severidade: `MÉDIA`
- Solução recomendada: unificar a API
- Dependências: telas, providers e testes

### P1-03 — Paginação de feed duplicada entre manager e página
- Arquivo: [lib/services/feed_pagination_manager.dart](../lib/services/feed_pagination_manager.dart), [lib/features/social/views/social_feed_page.dart](../lib/features/social/views/social_feed_page.dart)
- Impacto: risco de cursor inconsistente e duplicidade em refresh/load more
- Severidade: `MÉDIA`
- Solução recomendada: centralizar a lógica em um único controller
- Dependências: UI feed e provider

### P1-04 — Stories e memories têm leitura de Storage aberta para todos autenticados
- Arquivo: [storage.rules](../storage.rules)
- Impacto: vazamento de arquivos pessoais e de story
- Severidade: `ALTA`
- Solução recomendada: restringir read para owner/followers ou público explícito
- Dependências: policy de privacidade

## 28. P2

### P2-01 — `StorageService.defaultStorageService()` lança `UnimplementedError`
- Arquivo: [lib/services/storage_service.dart](../lib/services/storage_service.dart)
- Impacto: acoplamento com implementação platform-specific
- Severidade: `BAIXA`
- Solução recomendada: fornecer factory segura ou remover a API de utilização genérica
- Dependências: manutenção de storage

### P2-02 — Logging e debug em vários pontos dispersos
- Arquivo: vários em `lib/`
- Impacto: ruído, risco de vazamento e maior dificuldade de depuração
- Severidade: `BAIXA`
- Solução recomendada: reduzir logs sensíveis e centralizar observabilidade
- Dependências: observability service

### P2-03 — Falta de testes de regras de Storage e privacidade
- Arquivo: [test/](../test)
- Impacto: regressão não capturada
- Severidade: `BAIXA`
- Solução recomendada: criar testes de regras para avatar, stories, memories e chat media
- Dependências: Firebase Emulator + rules tests

## 29. Technical Debt

- Duplicidade de `ChatService`
- Duplicidade de lógica de paginação em feed
- Regras de Storage permissivas demais
- Mismatch de model em entidades de chat (`members` x `participants`)
- Falta de testes de privacidade e Storage
- Complexidade de follow / notifications / stories em múltiplas camadas

## 30. Recommended Execution Order

### FASE 1
Bloqueadores P0.

1. P0-01 | leitura aberta de arquivos de usuário/stories | [storage.rules](../storage.rules) | vazamento de dados e privacidade | `CRÍTICA` | reescrever `read` para owner/followers/visibilidade explícita | regras de privacy + profile + stories
2. P0-02 | inconsistente `participants`/`members` em chat | [storage.rules](../storage.rules), [firestore.rules](../firestore.rules) | upload de chat quebrado | `ALTA` | unificar campo e validar membership | firestor rules + chat model

### FASE 2
Riscos P1.

1. P1-01 | FCM fanout baseado em payload do cliente | [backend/functions/src/index.ts](../backend/functions/src/index.ts) | notificações indevidas | `ALTA` | validar membership no backend | chat model + backend
2. P1-02 | duplicidade de `ChatService` | [lib/features/chat/services/chat_service.dart](../lib/features/chat/services/chat_service.dart), [lib/features/social/services/chat_service.dart](../lib/features/social/services/chat_service.dart) | divergência de comportamento | `MÉDIA` | unificar em contrato único | telas + providers
3. P1-03 | paginação duplicada | [lib/services/feed_pagination_manager.dart](../lib/services/feed_pagination_manager.dart), [lib/features/social/views/social_feed_page.dart](../lib/features/social/views/social_feed_page.dart) | cursor divergente | `MÉDIA` | centralizar manager | feed UI
4. P1-04 | leitura de stories/memories aberta | [storage.rules](../storage.rules) | vazamento de conteúdo privado | `ALTA` | restringir read | rules + privacy model

### FASE 3
P2.

1. remover ou melhorar `defaultStorageService` unsafe factory
2. reduzir logs sensíveis
3. aumentar testes de Storage/privacidade
4. consolidar observability

### FASE 4
Melhorias pós-lançamento.

1. revisar regras de notificação e mutes/blocks
2. criar testes de regras de Storage em emulator
3. executar smoke E2E para chat, stories e feed
4. revisar release signing e deploy pipeline

## 31. Final Production Readiness

Status: `NÃO PRONTO PARA PRODUÇÃO`

Motivo: há P0 abertos de privacidade/segurança em Storage e inconsistência de data model em chat. O projeto compila e os testes passam, mas isso não basta para produção quando há falha confirmada de permissividade de leitura e violações de concerto de regras de acesso.

## Resumo executivo final

- Build debug: verde
- `dart analyze`: verde
- `flutter test`: verde
- Firebase project: verde
- Firestore rules: carregam
- Storage rules: carregam, mas `P0` de privacidade e proteção de arquivos
- Chat: idempotência melhorada, mas arquitetura duplicada e fanout de notif em backend precisa refinamento
- Produção: `NÃO READY`

A auditoria confirmou que o sistema está funcional em build e em parte da lógica, porém ainda não é seguro e consistente o suficiente para produção com os riscos de storage e chat atualizados.
