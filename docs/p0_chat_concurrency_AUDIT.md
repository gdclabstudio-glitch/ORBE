# P0 — Chat / concorrência / retry / deduplicação / consistência

## Status atual

Status: PARTIAL

A correção de idempotência foi aplicada e validada para o caminho principal de envio duplicado. O código agora usa `messageId`/`idempotencyKey` estável e o Outbox rejeita replay de mensagens já gravadas. A auditoria também encontrou e corrigido um risco real de envio simultâneo por double tap/concorrência no provider.

Ainda há uma limitação de build fora do escopo do chat: o APK debug falha no plugin Gradle do Firebase Crashlytics por configuração do projeto Android, não por lógica de chat.

## Idempotência

- Onde a idempotency key nasce: no provider de chat, em `ChatProvider.sendMessage`, a chave é criada como `clientMessageId` quando o cliente ainda não forneceu uma.
- Como vira `messageId`: o serviço de chat usa essa chave como identidade do documento Firestore (`doc(resolvedMessageId)`). O mesmo valor é salvo em `id` e `idempotencyKey` no payload.
- Como é persistida: a mensagem é escrita apenas quando o documento com essa ID ainda não existe. Se o documento já existe, o envio é ignorado.
- Como retry reutiliza a identidade: as chamadas repetidas de retry passam a mesma `idempotencyKey` para o serviço, então o doc permanece idempotente e a operação lógica continua sendo uma única mensagem.
- Como Outbox reutiliza a identidade: o item do Outbox usa `messageId` e `roomId`; ao processar, o worker faz `doc(messageId).get()` e só grava se o documento ainda não existir.

## Listeners

Listeners encontrados e lifecycle:

1. [lib/features/chat/providers/chat_provider.dart]
   - `connect()` cria `_sub = _service.messagesStream().listen(...)`.
   - `switchRoom()` cancela a subscription anterior e incrementa `connectionGeneration` antes de criar nova stream.
   - `dispose()` cancela `_sub`.
   - O guard `currentGen != _connectionGeneration` evita que listeners antigos emitam no estado novo.

2. [lib/features/chat/views/chat_page.dart]
   - Usa `context.read<ChatProvider>()` e no `initState` chama `switchRoom()` ou `connect()` em `addPostFrameCallback`.
   - O fluxo é disparado pela mudança de room, não em `build()`.
   - Não há criação de listeners em cada rebuild porque a UI usa `Consumer<ChatProvider>` sem novos `listen`.

3. [lib/features/social/views/chat_page.dart]
   - Usa `StreamBuilder<QuerySnapshot>` diretamente sobre `_service.messagesStream(widget.chatId)`.
   - O stream é criado pelo widget a cada build, mas o `StreamBuilder` do Flutter gerencia a subscription automáticamente e a cancela no dispose do widget.
   - Não há duplicação por rebuild porque o widget reusa o StreamBuilder do Flutter; a criação do stream é controlada pelo framework.

4. Ambos os `chat_service.dart`
   - [lib/features/chat/services/chat_service.dart]: `messagesStream()` retorna `snapshots().map(...)` e todos os listeners ficam sob controle do provider.
   - [lib/features/social/services/chat_service.dart]: `messagesStream(String chatId)` produz um `Stream<QuerySnapshot>` consumido por `StreamBuilder`.

Conclusão: não há acumulação de listeners nos provideres do chat principal; o mecanismo de `switchRoom()` + `dispose()` e `connectionGeneration` bloqueia emissão de streams antigas.

## Paginação

O teclado do app não implementa paginação real em mestres de chat. No código atual, os fluxos usam realtime diretamente:

- [lib/features/chat/services/chat_service.dart] usa `snapshots()` sem `limit` / `startAfter`.
- [lib/features/social/services/chat_service.dart] usa `orderBy('createdAt', descending: true)` e `snapshots()`, sem paginação.

Não há `loadMore` para mensagens de chat nos serviços auditados. Isso elimina um risco clássico de duplicação por realtime + paginação no fluxo atual. Mesmo assim, o sistema foi reforçado para deduplicar por `messageId` em nível de gravação e Outbox, preservando a identidade real da mensagem.

## Concorrência

Condições auditadas:

- dois envios simultâneos;
- double tap;
- retries concorrentes;
- replays do Outbox;
- listener recebendo a mensagem original enquanto retry ocorre.

A correção toma duas medidas:

1. `ChatProvider` registra uma chave de envio em andamento (`_inFlightMessageKeys`) para bloquear o mesmo payload duplicado em double tap/concorrência no mesmo cliente.
2. `ChatService` grava o documento usando `messageId` estável; replays posteriores são ignorados pelo check `if (existing.exists) return;`.

Com isso, uma operação lógica produz uma mensagem lógica.

## Outbox

- Identificação: item do Outbox possui `type`, `payload.roomId`, `payload.messageId` e `message`.
- Reivindicação: o código de processamento varre a fila em `_processQueue()` e executa cada item sequencialmente; não há lock distribuído ou persistente.
- Concorrência entre workers: no desenho atual, não existe mais de um worker processando a fila no mesmo app; o `bool _processing` impede reentrada em memória, mas não é persistente por processo.
- Lock persistente: não existe. Isso é uma limitação real e documentada.
- Recuperação após morte do worker: ao reiniciar o app, a fila permanece em storage local e a startup chama `_processQueue()`. Isso dá recuperação de retries por processo, mas sem mecanismo de claim distribuído.
- Retry mantém identidade: o `messageId` permanece o mesmo em todos os retries. O Outbox usa a mesma ID para novos writes, e o guard `existing.exists` evita duplicação.

## Offline / reconexão

Fluxo validado:

1. usuário escreve mensagem;
2. conexão cai;
3. `sendMessage` falha e entra no Outbox;
4. app pode fechar e reabrir;
5. ao voltar a conexão, `_processQueue()` tenta reenviar;
6. `messageId` igual garante que o item seja idempotente.

A persistência do Outbox é local via `StorageService`, então o estado sobrevive a reinicialização do app. O limite é que o lock não é compartilhado entre processos/instâncias; no desenho atual isso não é um risco de duplicação dentro do mesmo app, mas é uma limitação de coordenação multi-client.

## Backend

Cloud Function relacionada:

- [backend/functions/src/index.ts] — `onChatMessageCreated`

Side effects:

- determina destinatários a partir de `recipientId`, `to` ou `chatId`;
- envia FCM para cada destinatário;
- grava evento de sistema (`writeSystemEvent`);
- incrementa `messagesSentToday`.

Essa função é idempotente em relação ao documento de mensagem, porque ela é disparada por `onCreate` do documento. Se o mesmo documento for reprocessado por falhas de infraestrutura, o risco é de notificação duplicada, e não de escrita duplicada de mensagem. Esse risco não foi corrigido no backend porque o código atual depende do Firestore trigger and not exactly-once semantics; a mitigação de deduplicação do documento do cliente é a garantia principal.

## Testes

Testes adicionados:

- `ChatService idempotence / reusing the same idempotency key does not create duplicate messages`
- `ChatService idempotence / concurrent double-tap sends with the same payload are deduplicated`

Arquivos relevantes:

- [test/chat_service_idempotence_test.dart]

## Riscos restantes

Riscos comprovados ou limitações reais:

- `flutter build apk --debug` está bloqueado por configuração do Android/Gradle: plugin `com.google.firebase.crashlytics` não foi encontrado no repositório de plugins, sem relação com a lógica de chat.
- Não existe lock distribuído persistente no Outbox; esse desenho é suficiente para o app atual, mas não garante exactly-once multi-processo.
- O backend de notificação não oferece exactly-once garantido; isso é um risco de fanout duplicado em cenários de retry de infraestrutura, não de duplicação de mensagem persistente.

## Observação final

Os riscos concretos de duplicação da mensagem foram corrigidos e validados. O que permanece é um problema de build do projeto Android e uma limitação de desenho do Outbox em múltiplos workers/processos, que não foi inventada como solução agressiva sem prova.
