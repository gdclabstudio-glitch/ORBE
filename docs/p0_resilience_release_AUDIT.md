# P0.9 — AUDITORIA DE RESILIÊNCIA, RELEASE E QUALIDADE

## ESCOPO
Auditoria profunda de estabilidade, tratamento de erros, conectividade, performance, release engineering e qualidade de produção. **Sem alterações em produção.**

## DATA
2026-08-31 / Etapa de Auditoria

---

## PROBLEMAS ENCONTRADOS

### CRÍTICOS (CRITICAL)
Problemas que podem causar perda de dados, indisponibilidade ou bypass de segurança.

#### C1: Inicialização Firebase sem validação de falhas críticas
- **ARQUIVO**: `lib/main.dart:79-204`
- **PADRÃO**: `catch (_) {}` com `runApp()` mesmo após falhas em Firebase/Observability
- **RISCO**: App inicia sem backend crítico; falhas silenciosas, permissões não validadas
- **IMPACTO**: Degradação silenciosa, logs vazios, usuários com experiência quebrada
- **PRIORIDADE**: P0

#### C2: Feed paginated com FutureBuilder recriado em cada rebuild
- **ARQUIVO**: `lib/features/social/views/social_feed_page.dart:45-89, 199-205`
- **PADRÃO**: `_loadPostsPage()` chamado direto em `build()` → rebuild = nova query
- **RISCO**: Duplicação de Firestore reads, race conditions, cursor corrompido
- **IMPACTO**: Aumento de custo, feed inconsistente, carga no backend
- **PRIORIDADE**: P0

#### C3: Erros do feed convertidos silenciosamente para empty state
- **ARQUIVO**: `lib/features/social/views/social_feed_page.dart:208-290, 356-366`
- **PADRÃO**: `snapshot.hasError` → empty list, sem retry UI
- **RISCO**: Outages invisíveis, usuários sem feedback de falha
- **IMPACTO**: Degradação invisível, abandono da app
- **PRIORIDADE**: P0

#### C4: Exceções de carregamento de stories silenciosas
- **ARQUIVO**: `lib/features/social/views/story_viewer_page.dart:88-116, 440-447`
- **PADRÃO**: `catch (_)` → empty stories, sem diferença de "sem dados" vs "erro"
- **RISCO**: Falhas de rede/permissão escondidas
- **IMPACTO**: UX confusa, sem retry path
- **PRIORIDADE**: P0

#### C5: Timer callbacks em story viewer sem mounted checks
- **ARQUIVO**: `lib/features/social/views/story_viewer_page.dart:119-139, 248-280`
- **PADRÃO**: `Navigator.of(context).pop()` sem validação `mounted`
- **RISCO**: setState after dispose, crashes em navegação rápida
- **IMPACTO**: Crashes, race conditions em play/pause/swipe
- **PRIORIDADE**: P0

#### C6: Chat writes sem retry/timeout/offline queue
- **ARQUIVO**: `lib/features/chat/services/chat_service.dart:21-40` e social variant
- **PADRÃO**: Firestore `add()`/`set()` direto, sem OutboxService ou retry
- **RISCO**: Perda de mensagens, duplicação, sem offline fallback
- **IMPACTO**: Perda de dados, UX degradada
- **PRIORIDADE**: P0

#### C7: Backend submitReport com ID não-idempotente
- **ARQUIVO**: `backend/functions/src/index.ts:627-665`
- **PADRÃO**: `report_${Date.now()}_${reporterId}` → duplicate reports em retry
- **RISCO**: Dados duplicados, inconsistência
- **IMPACTO**: Spam em reports, auditoria corrompida
- **PRIORIDADE**: P0

#### C8: Backend submitAdminRequest com ID não-idempotente
- **ARQUIVO**: `backend/functions/src/index.ts:733-787`
- **PADRÃO**: `admin_req_${Date.now()}_${actorUid}` sem dedupe guard
- **RISCO**: Ações administrativas executadas duas vezes
- **IMPACTO**: Estados inválidos, escalação de privilégios acidental
- **PRIORIDADE**: P0

#### C9: processAdminRequest sem idempotência em trigger
- **ARQUIVO**: `backend/functions/src/index.ts:901-1158`
- **PADRÃO**: Trigger replayed, sem "if already processed" guard
- **RISCO**: Admin actions duplicadas, estado corrompido
- **IMPACTO**: Bans duplicados, claims alterados duas vezes
- **PRIORIDADE**: P0

#### C10: Notification writes na reação sem deduplication
- **ARQUIVO**: `backend/functions/src/index.ts:403-440, 451-521, 525-579`
- **PADRÃO**: `onPostReactionCreated`, `onCommentReactionCreated`, `onChatMessageCreated` → append notification sem verificação de duplicates
- **RISCO**: Notificações duplicadas em retry/replay
- **IMPACTO**: Spam de notificações, confusão do usuário
- **PRIORIDADE**: P0

#### C11: Group message fan-out sem deduplication de membros
- **ARQUIVO**: `backend/functions/src/index.ts:583-624`
- **PADRÃO**: Loop through members sem dedupe, mesma pessoa recebe múltiplas notificações
- **RISCO**: Múltiplas pushes por mensagem, UX quebrada
- **IMPACTO**: Spam de notificações críticas
- **PRIORIDADE**: P0

#### C12: Mass FCM (broadcast) sem timeout safeguards
- **ARQUIVO**: `backend/functions/src/index.ts:1063-1104`
- **PADRÃO**: Sequencial `await` para cada user, sem batching ou timeout
- **RISCO**: Função timeout em scale, broadcast falha
- **IMPACTO**: Broadcast administrativos nunca completam
- **PRIORIDADE**: P0

---

### ALTOS (HIGH)
Impacto importante na confiabilidade, falha com workaround parcial.

#### H1: Auth operations sem timeout e tratamento de falha clara
- **ARQUIVO**: `lib/services/auth_service.dart:145-166, 187-223, 267-330, 498-523`
- **PADRÃO**: `catch` e conversão silenciosa a `AuthStatus.authenticated` ou `unknown`
- **RISCO**: Sessões travadas em má conexão, UI em estado errado
- **IMPACTO**: Login/logout/refresh não completa, app em estado incerto
- **PRIORIDADE**: P1

#### H2: Chat StreamBuilder sem error UI
- **ARQUIVO**: `lib/features/social/views/chat_page.dart:32-60`
- **PADRÃO**: Apenas `!snap.hasData` → spinner, `hasError` não tratado
- **RISCO**: Sem retry path, offline failures invisíveis
- **IMPACTO**: Chat travado, sem feedback de conexão
- **PRIORIDADE**: P1

#### H3: Story reaction stream não-robusta a swipes rápidos
- **ARQUIVO**: `lib/features/social/views/story_viewer_page.dart:154-184`
- **PADRÃO**: `_reactionsSub` não cancelada por story, stale results podem overwrite state
- **RISCO**: Reações duplicadas, UI stale após swipe
- **IMPACTO**: Comportamento inesperado, reações erradas
- **PRIORIDADE**: P1

#### H4: Chat provider não-robusta a room switches rápidos
- **ARQUIVO**: `lib/features/chat/providers/chat_provider.dart:27-47, 91-94`
- **PADRÃO**: `switchRoom()` sem token/generation para descartar stale emissions
- **RISCO**: Mensagens antigas aparecem em novo room
- **IMPACTO**: Chat confuso, mensagens no room errado
- **PRIORIDADE**: P1

#### H5: FCM failures are logged but not requeued
- **ARQUIVO**: `backend/functions/src/index.ts:491-510, 544-560, 599-614, 1073-1083`
- **PADRÃO**: Notification send fails → only logged, sem retry ou error response
- **RISCO**: Notificações críticas nunca chegam ao usuário
- **IMPACTO**: Chat/moderação não entrega notificação
- **PRIORIDADE**: P1

#### H6: Multi-write operations sem transaction
- **ARQUIVO**: `backend/functions/src/index.ts:637-655, 756-787, 912-1158`
- **PADRÃO**: Writes to `reports`, `admin_requests`, `admin_audit_logs`, metrics → separate operations
- **RISCO**: Partial success, state inconsistency
- **IMPACTO**: Audit logs incompletos, métricas erradas
- **PRIORIDADE**: P1

---

### MÉDIOS (MEDIUM)
Problemas reais com impacto limitado ou workaround possível.

#### M1: Streams/listeners não scoped corretamente
- **ARQUIVO**: Multiple
- **PADRÃO**: Listeners não cancelados per-page-instance, retenção de recursos
- **RISCO**: Memory leak, stale updates após navigation
- **IMPACTO**: App lenta com uso prolongado
- **PRIORIDADE**: P2

#### M2: Missing correlation IDs in backend logs
- **ARQUIVO**: `backend/functions/src/index.ts:95-114`
- **PADRÃO**: `logStructured` sem `requestId`, `traceId`, invocation ID
- **RISCO**: Difícil rastrear retries e duplicatas em incidentes
- **IMPACTO**: Diagnóstico mais lento
- **PRIORIDADE**: P2

#### M3: Missing required-field validation before FCM
- **ARQUIVO**: `backend/functions/src/index.ts:527-614`
- **PADRÃO**: Assume `msg.senderId`, `msg.text` válidos sem verificação
- **RISCO**: Malformed payloads processados, confusão na notificação
- **IMPACTO**: Notificações quebradas, backend instável
- **PRIORIDADE**: P2

#### M4: Role claims update race condition
- **ARQUIVO**: `backend/functions/src/index.ts:790-832`
- **PADRÃO**: `assignRoleClaims` lê claims e chama `setCustomUserClaims` sem transaction
- **RISCO**: Concurrent claim changes race and overwrite
- **IMPACTO**: Privilégios inconsistentes em operações simultâneas
- **PRIORIDADE**: P2

#### M5: Report payload validation é permissiva
- **ARQUIVO**: `backend/functions/src/index.ts:208-246`
- **PADRÃO**: Categorias desconhecidas → `other`, sem validação rigorosa
- **RISCO**: Relatórios de baixa qualidade acumulam
- **IMPACTO**: Moderação menos eficaz
- **PRIORIDADE**: P3

#### M6: Fresh auth validation não totalmente centralizado
- **ARQUIVO**: `backend/functions/src/index.ts:95-97`
- **PADRÃO**: `ensureFreshAdminAuth` client-side, não re-validated atomicamente backend
- **RISCO**: Edge case onde auth_time não rechecked
- **IMPACTO**: Pequeno risco em defence-in-depth
- **PRIORIDADE**: P2

---

### BAIXOS (LOW)
Melhorias de UX, performance, ou observabilidade.

#### L1: Release configuration mapping (DEV/STAGING/PROD)
- **ARQUIVO**: `.env`, `.env.example`, `lib/config/`, `android/`, etc.
- **DESCRIÇÃO**: Documentação e configuração de ambiente não totalmente separada
- **RISCO**: Configuração errada em produção
- **IMPACTO**: Deployment errado
- **PRIORIDADE**: P3

#### L2: CI/CD pipeline review
- **ARQUIVO**: `.github/workflows/`
- **DESCRIÇÃO**: Existem workflows, mas sem gates de qualidade explícitos
- **IMPACTO**: Possível deploy com teste falhando
- **PRIORIDADE**: P3

---

## RESUMO QUANTITATIVO

| SEVERIDADE | CONTAGEM | PRIORIDADE |
|---|---|---|
| CRITICAL (C1-C12) | 12 | P0 |
| HIGH (H1-H6) | 6 | P1 |
| MEDIUM (M1-M6) | 6 | P2 |
| LOW (L1-L2) | 2 | P3 |
| **TOTAL** | **26** | - |

---

## PRÓXIMAS ETAPAS

### FASE 2: IMPLEMENTAÇÃO

As correções serão implementadas em ordem de prioridade:

1. **P0 (CRITICAL)**: Correções que evitam perda de dados, duplicação, ou falhas silenciosas
   - Inicialização Firebase com fallback
   - Feed paginated com memoization
   - Error states visíveis na UI
   - Chat writes com retry/outbox
   - Idempotência no backend (submitReport, submitAdminRequest, triggers)
   - Deduplication de notifications
   - Mass broadcast com timeout/batching

2. **P1 (HIGH)**: Correções que melhoram confiabilidade
   - Auth timeout e error handling
   - Chat error UI e reconnect
   - Stream scoping per-story e per-room
   - FCM retry/queueing
   - Transaction safety

3. **P2 (MEDIUM)**: Melhorias operacionais
   - Correlation IDs
   - Resource lifecycle management
   - Validation hardening
   - Race condition mitigations

4. **P3 (LOW)**: Polish e release readiness
   - CI/CD gates
   - Config documentation
   - Performance profiling (não otimização prematura)

---

## RESTRIÇÕES
- ✅ Sem alteração de produção
- ✅ Sem deploy
- ✅ Sem dados reais
- ✅ Sem secrets
- ✅ Sem mudanças de Firestore/Storage rules sem justificativa P0/P1
- ✅ Todos os testes devem passar: `dart format`, `flutter analyze`, `flutter test`, `npm run build`

