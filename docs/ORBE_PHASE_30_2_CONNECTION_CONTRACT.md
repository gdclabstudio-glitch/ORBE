# ORBE — Fase 30.2 — Contrato do sistema de conexões

## Objetivo e escopo

Este documento fecha o contrato conceitual para a evolução social do ORBE. Ele
não implementa funcionalidades, não cria collections, não altera Rules e não
substitui os fluxos legados existentes.

Os conceitos são independentes:

- **Follow**: interesse ou assinatura social; não implica amizade nem autorização
  para conversa.
- **Connection**: relação social bilateral estabelecida.
- **Connection Request**: pedido direcional para estabelecer uma Connection.
- **Conversation Request**: autorização direcional para iniciar uma conversa
  privada sem Connection.
- **Private Conversation**: conversa 1:1 autorizada.
- **Group**: conversa coletiva independente de Connection.

## Princípios

1. Follow != Connection.
2. Connection Request != Conversation Request.
3. Uma pessoa desconhecida não entra diretamente no chat privado principal.
4. Estado social autoritativo não deve depender de arrays editáveis no perfil,
   cache local ou fallback offline.
5. Operações devem ser idempotentes e convergir sob retry e concorrência.
6. Connection não representa localização física nem altera diretamente a física
   do Orb Universe.

## Entidades e estados

### ConnectionStatus

| Estado | Semântica |
| --- | --- |
| `none` | Não existe relação, pedido ativo ou bloqueio aplicável. |
| `pendingIncoming` | O outro usuário enviou um pedido pendente. |
| `pendingOutgoing` | O usuário atual enviou um pedido pendente. |
| `connected` | O pedido foi aceito e existe uma relação bilateral. |
| `blocked` | Existe bloqueio aplicável; novas interações incompatíveis são impedidas. |

`blocked` é uma decisão de política, não deve ser representado apenas como um
estado de uma Connection. A recomendação é uma relação de bloqueio separada e
direcional, capaz de impedir requests, mensagens e leituras conforme as Rules.
O array `users.blocked` atual permanece legado durante a transição.

### ConnectionRequest

```text
requestId
requesterId
recipientId
status: pending | accepted | declined | cancelled
createdAt
updatedAt
```

`requesterId` e `recipientId` são imutáveis, distintos e dão direção ao pedido.
`expired` não é necessário nesta fase.

### Connection

```text
connectionId
userIds: [uidA, uidB]
status: connected | removed
createdAt
updatedAt
removedAt?
```

`userIds` contém exatamente dois UIDs e é normalizado em ordem lexicográfica.
A relação é bilateral, portanto `Connection` não é direcional.

### ConversationRequest

```text
requestId
requesterId
recipientId
status: pending | accepted | declined | cancelled
createdAt
updatedAt
```

É direcional e independente de Connection. Aceitá-lo autoriza a conversa
privada, mas não cria Connection automaticamente.

## IDs determinísticos

Os IDs são calculados pelo caminho server-authoritative. A versão `v1` serializa
uma tupla JSON inequívoca e aplica SHA-256, representado como hexadecimal
minúsculo. O cliente pode calcular o mesmo valor para validação otimista, mas o
servidor é a autoridade final.

### Connection ID

```text
connectionId = sha256(json(["v1", "connection", min(uidA, uidB), max(uidA, uidB)]))
```

onde `uidA` e `uidB` são os UIDs distintos ordenados. Assim, A↔B sempre produz
o mesmo ID, sem colisões causadas pelo separador.

### Connection Request ID

```text
requestId = sha256(json(["v1", "connection_request", requesterId, recipientId]))
```

O ID é direcional. Isso impede dois requests ativos na mesma direção e torna
retry, cancelamento e lookup determinísticos. Um request inverso é uma operação
distinta e deve ser rejeitado ou reconciliado por uma transação quando já houver
request ativo no sentido oposto.

### Conversation Request ID

Usa a tupla direcional `["v1", "conversation_request", requesterId,
recipientId]`. Requests históricos não devem
ser sobrescritos silenciosamente; uma nova solicitação somente é permitida
quando não houver estado pendente conflitante.

IDs não usam timestamps.

## Persistência futura

A recomendação é usar collections explícitas:

```text
connections/{connectionId}
connection_requests/{requestId}
conversation_requests/{requestId}
blocks/{blockId}
```

Essas collections são as collections efetivamente usadas pela implementação
server-authoritative atual.

### Consultas esperadas

- Connection: lookup direto pelo par normalizado.
- Connection requests: requests recebidos por `recipientId` e enviados por
  `requesterId`, filtrados por `status`.
- Conversation requests: mesmas consultas direcionais, separadas das conexões.
- Blocks: lookup por `blockerId`, `blockedId` e estado ativo.

Índices compostos serão definidos somente junto com as queries reais e as Rules
da próxima fase. Nenhum índice é criado por este contrato.

## State machines

### ConnectionRequest

```text
pending ── accept  ──> accepted
pending ── decline ──> declined
pending ── cancel  ──> cancelled
```

Estados terminais não podem voltar a `pending` ou `accepted`. Uma nova tentativa
depois de `declined` ou `cancelled` deve gerar uma nova versão lógica somente
através da operação autorizada de reenvio.

### Connection

```text
connected ── remove ──> removed
```

O estado `removed` preserva histórico. Uma nova conexão exige um novo request e
não reativa silenciosamente o documento histórico.

### ConversationRequest

Segue a mesma máquina direcional, mas `accepted` autoriza a conversa privada e
não altera Connection.

## Autorização futura

| Operação | `connected` | não conectado | `pending` | `blocked` |
| --- | --- | --- | --- | --- |
| Ver conversa privada | sim | não | não | não |
| Enviar mensagem privada | sim | não | não | não |
| Iniciar conversa privada | sim | Conversation Request | não | não |
| Criar Connection Request | não se já conectado | sim | não duplicar | não |
| Criar Conversation Request | não necessário | sim | não duplicar | não |
| Grupo | depende da membership do grupo | depende da membership | depende da membership | conforme política do grupo |

Toda mensagem deve ter `senderId == auth.uid`. `participants` será o campo
autoritativo para chats novos; `members` continuará sendo aceito somente para
compatibilidade com chats legados até a migração. A implementação atual em
`lib/features/chat` é a implementação a preservar; a implementação duplicada
em `lib/features/social` não deve receber novas funcionalidades.

## Bloqueio

O bloqueio é unilateral: o usuário bloqueador cria e remove seu próprio bloqueio.
A política futura recomendada é:

- bloquear impede follow, Connection Request, Conversation Request e mensagens;
- o bloqueado não pode iniciar interação social com o bloqueador;
- perfil e visibilidade devem obedecer às Rules, sem assumir leitura automática;
- requests pendentes incompatíveis devem ser cancelados;
- Connection existente fica suspensa enquanto o bloqueio existir e conserva
  histórico para eventual desbloqueio explícito;
- desbloquear não reativa automaticamente Connection nem requests.

A forma final da collection `blocks` e a política detalhada de leitura do perfil
continuam pendentes para a próxima fase de Rules.

## Remoção de conexão

`removeConnection` é idempotente: se a conexão já estiver removida, não cria
novo estado. A remoção marca `status=removed` e `removedAt`, preservando o
histórico. Ela não remove mensagens nem reativa requests antigos.

## Concorrência e idempotência

As operações futuras devem usar transação ou operação server-side com pré-condições:

- criar request verifica ausência de request ativo conflitante;
- aceitar verifica `status=pending`; a criação da Connection é uma operação
  server-side separada que exige o request aceito;
- decline e cancel só alteram `pending`;
- duas aceitações concorrentes convergem para o mesmo `connectionId`;
- retry de qualquer operação retorna o estado já obtido, sem duplicar documentos;
- uma Connection por par é garantida pelo ID determinístico;
- a autorização não pode depender de cooldown ou estado apenas no cliente.

Operações idempotentes:

```text
sendConnectionRequest
acceptConnectionRequest
declineConnectionRequest
cancelConnectionRequest
removeConnection
sendConversationRequest
acceptConversationRequest
declineConversationRequest
```

## Follow e compatibilidade legada

O Follow atual continua funcionando e não será convertido automaticamente em
Connection. Os seguintes dados são preservados e classificados como legado ou
alvo de migração, sem exclusão nesta fase:

| Estrutura | Classificação |
| --- | --- |
| `friend_requests` | Legado; não é fonte autoritativa |
| `users.friends` | Legado; não é fonte autoritativa |
| `followers`/`following` arrays | Legado/compatibilidade |
| `followers`/`following` subcollections | Reutilizável para Follow, sujeito a Rules consistentes |
| `incomingFollowRequests`/`outgoingFollowRequests` | Legado de Follow; não é Connection Request |
| `SocialProvider` | Compatibilidade temporária; não é service definitivo |
| `features/chat` | Implementação de chat a preservar |
| `features/social` chat | Legado; não expandir |

Não haverá migração implícita, perda de dados ou dupla fonte autoritativa.

## Limites de serviço

A implementação futura deve separar:

```text
ConnectionRepository
ConnectionService
ConversationRequestRepository
ConversationRequestService
```

O repository encapsula persistência e consultas. O service aplica transições,
idempotência e autorização de domínio. `SocialProvider` pode ser adaptado
gradualmente como fachada de compatibilidade, mas não deve definir o contrato
novo nem manter fallback local para estado autoritativo.

## Contrato de UI futuro

No perfil de outra pessoa:

```text
[Conectar]
[Mensagem]
```

Estados visuais de Connection:

```text
Conectar
Solicitação enviada
Aceitar conexão
Conectado
Bloqueado
```

`Mensagem` abre a conversa principal somente em `connected`. Nos demais casos,
abre o fluxo de Conversation Request, sem criar mensagem normal antecipadamente.
Nenhuma UI é alterada nesta fase.

## Notifications futuras

Eventos futuros, separados do estado das entidades:

```text
connection_request_received
connection_request_accepted
conversation_request_received
conversation_request_accepted
```

Notificações devem apontar para a entidade e ação corretas. Não são fonte de
verdade de request ou connection e não devem ser criadas pelo cliente sem
autorização server-side.

## Orb Universe e grupos

Connection é apenas um sinal social. Futuramente pode contribuir para relevância
com `InteractionScore`, frequência, recência e contexto, mas não determina
distância física, posição do Orb ou autorização geral.

Grupos permanecem separados: membership de grupo controla acesso ao grupo e não
cria Connection, não autoriza conversa 1:1 e não altera requests.

## Matriz futura de Rules

| Collection | Create | Read | Update | Delete |
| --- | --- | --- | --- | --- |
| `connection_requests` | requester autenticado, sem bloqueio e com IDs válidos | requester ou recipient | recipient aceita/recusa; requester cancela, sempre de `pending` | operação autorizada ou retenção histórica |
| `connections` | somente transição autorizada de accept | ambos participantes, salvo bloqueio | transição de remoção/bloqueio autorizada | preferir retenção histórica |
| `conversation_requests` | requester autenticado, sem bloqueio e não conectado | requester ou recipient | recipient aceita/recusa; requester cancela | operação autorizada ou retenção histórica |
| `blocks` | somente o bloqueador | partes conforme política | somente bloqueador | somente bloqueador |

Essas Rules serão projetadas e testadas no Emulator antes de qualquer
implantação. Esta tabela não altera `firestore.rules`.

## Estratégia de migração

1. Implementar novas collections e Rules sem alterar os contratos legados.
2. Criar leitura explícita do novo modelo.
3. Manter Follow e chats legados funcionando.
4. Migrar dados somente após inventário, consentimento técnico e testes de
   consistência.
5. Comparar estados novos e legados durante período de compatibilidade.
6. Remover legado apenas em fase posterior e explícita.

## Riscos

- arrays legados podem divergir de subcollections;
- `friend_requests` atuais podem estar inacessíveis pelas Rules;
- chats podem usar `members` em vez de `participants`;
- outbox pode repetir operações antigas;
- aceitar requests sem transação pode produzir estados parciais;
- alterar Rules sem Emulator pode bloquear usuários existentes;
- cache local não deve ser promovido a fonte autoritativa.

## Decisões obrigatórias

1. **Fonte autoritativa da Connection:** `connections/{connectionId}`.
2. **Connection ID:** par ordenado e codificado, independente da direção.
3. **ConnectionRequest ID:** par ordenado e codificado com direção.
4. **ConnectionRequest:** direcional.
5. **Connection:** bilateral, não direcional.
6. **Bloqueio:** unilateral, relação separada; suspende interações e preserva histórico.
7. **Remoção:** marca `removed`, preserva histórico.
8. **Connection Request e Conversation Request:** independentes.
9. **Usuário desconhecido:** somente via Conversation Request aceito.
10. **Grupos:** separados de Connection e conversa privada.
11. **Chat preservado:** `lib/features/chat`; manter compatibilidade com `members`.
12. **Código não expandido:** `SocialProvider` de amizade e chat em `features/social`.
13. **Migração:** aditiva, faseada, sem apagar nem sobrescrever dados legados.
14. **Idempotência:** IDs determinísticos e transições condicionais.
15. **Concorrência:** transações ou backend server-side com pré-condições.
16. **Rules da próxima fase:** requests, connections, conversation requests e blocks.
17. **Índices:** somente após as queries finais; nenhum definido nesta fase.

## Decisões pendentes

- nome final e forma da collection de blocks;
- política de leitura de perfil após bloqueio;
- se desbloqueio permite novo request imediatamente ou exige cooldown;
- retenção e auditoria de requests recusados/cancelados;
- estratégia exata de migração de `users.friends`;
- claims ou backend escolhido para operações server-side;
- campos de presença, última atividade e arquivamento de conversas;
- matriz final de Rules e índices validada no Emulator.

## Definition of Ready — próxima fase

A implementação só estará pronta para começar quando:

- os nomes e campos das collections forem aprovados;
- a política de bloqueio estiver fechada;
- as Rules estiverem especificadas e cobertas por testes do Emulator;
- os fluxos concorrentes tiverem casos de teste;
- a compatibilidade de `participants`/`members` estiver validada;
- o destino do `SocialProvider` estiver definido;
- as queries reais e seus índices estiverem documentados;
- houver plano de rollback sem perda de dados legados.

## Implementação vigente — Fase 30.6.3

Esta seção substitui qualquer estratégia histórica anterior que contradiga o
backend implementado. A Callable `socialOperation`, exportada pelas Firebase
Functions, é a autoridade para todas as mutações de `connections`,
`connection_requests`, `conversation_requests` e `blocks`.

- `auth.uid` é obtido exclusivamente do contexto autenticado da Callable.
- O cliente não é autoridade sobre participantes, estados, timestamps ou IDs.
- O backend recalcula cada ID determinístico e usa `expectedId` somente como
  verificação opcional; um valor divergente é rejeitado e nunca seleciona outro
  documento.
- A identidade é SHA-256 da serialização JSON UTF-8 da tupla canônica e resulta
  em hexadecimal minúsculo de exatamente 64 caracteres:

  ```text
  Connection:
  ["v1","connection",min(uidA,uidB),max(uidA,uidB)]

  Connection Request:
  ["v1","connection_request",fromUserId,toUserId]

  Conversation Request:
  ["v1","conversation_request",fromUserId,toUserId]

  Block:
  ["v1","block",blockerId,blockedUserId]
  ```

- Connections são simétricas; requests, Conversation Requests e Blocks são
  direcionais.
- Reads do cliente podem continuar usando Firestore diretamente quando
  autorizados pelas Rules. Writes diretos das quatro collections não são
  autoridade e permanecem bloqueados pelas Rules.
- A Callable usa o Admin SDK, que bypassa as Firestore Rules; por isso cada
  autorização e cada pré-condição são verificadas explicitamente no backend.
- Antes de qualquer transição, documentos existentes têm seus participantes
  validados. Documentos inconsistentes são rejeitados, nunca reparados
  silenciosamente.
- O lifecycle normal preserva histórico; physical delete não faz parte das
  operações sociais normais. Blocks permanecem históricos.
- `connected → removed` é uma remoção terminal para o documento corrente.
  Connection removida não é reativada diretamente; uma nova relação exige novo
  ciclo de request conforme a política atual.
- Aceitar um Conversation Request somente atualiza sua autorização. Não cria
  automaticamente Connection, mensagem ou documento de chat.

O cliente usa `SocialOperationClient` para todas as escritas sociais. Os
repositories podem ler diretamente do Firestore, mas não possuem fallback de
escrita direta quando a Callable falha.

## Escopo histórico desta fase

Nenhum código, tela, rota, modelo, Rule, índice, dependência, migração ou dado
existente foi alterado pelo contrato original. A configuração explícita das
Functions foi adicionada posteriormente em `firebase.json`, sem alterar o
projeto Firebase selecionado.

---

# Adendo normativo — Fase 30.2.1

Este adendo fecha e substitui qualquer recomendação ou pendência anterior que
seja incompatível com as decisões abaixo. As seções históricas permanecem para
rastreabilidade, mas este adendo é a autoridade para a implementação futura.

## Decisões arquiteturais fechadas

### 1. Request ativo e histórico

`connection_requests/{requestId}` usa um ID determinístico direcional:

```text
sha256(json(["v1", "conversation_request", requesterId, recipientId]))
```

Há no máximo um documento ativo por direção e par. O documento pode atravessar
os estados `pending`, `accepted`, `declined` e `cancelled`, preservando
`createdAt`, `updatedAt` e os campos de auditoria da transição.

Um novo request depois de `declined` ou `cancelled` reutiliza o mesmo documento,
com `createdAt` preservado e `updatedAt` atualizado. O lifecycle anterior deve
ser preservado em campos de auditoria ou em uma futura estrutura de eventos;
não serão criados múltiplos requests ativos para a mesma direção.

Essa decisão é compatível com:

- concorrência, porque a criação é um write condicional no ID conhecido;
- Rules, porque requester e recipient são determinísticos;
- queries, porque a direção e o status são campos estáveis;
- cancelamento, que somente o requester pode executar;
- retry, que reaplica a mesma transição sem duplicidade.

Um request inverso (`A → B` e `B → A`) é uma direção distinta, mas não pode
ser aceito enquanto houver request pendente conflitante. A operação deve
reconciliar ambos em transação ou falhar com estado explícito.

### 2. Blocking

O bloqueio será unilateral e persistido em:

```text
blocks/{blockId}
```

O ID é determinístico:

```text
sha256(json(["v1", "block", blockerId, blockedUserId]))
```

Schema normativo:

```text
blockerId
blockedUserId
status: active | removed
createdAt
updatedAt
removedAt?
removedBy?
```

`blockerId` e `blockedUserId` são imutáveis e distintos. O bloqueador pode
criar e remover seu próprio bloqueio. Ambos podem ler somente o mínimo necessário
à aplicação da política; consultas públicas não devem expor a lista de bloqueios.

Efeitos de `active`:

- impede Follow, Connection Request e Conversation Request em qualquer direção
  entre as duas pessoas;
- impede leitura e escrita de mensagens privadas entre elas;
- impede contornar a barreira por outra rota ou pelo ID determinístico do chat;
- requests pendentes incompatíveis são cancelados na mesma operação autorizada;
- Connection existente passa a ficar suspensa, preservando histórico;
- não apaga Connection, mensagens ou histórico;
- não altera membership de grupos automaticamente.

O bloqueado não pode criar interação com o bloqueador. O bloqueador também não
deve iniciar novas interações com o bloqueado enquanto o bloqueio estiver ativo.
Desbloquear remove a barreira, mas não reativa Connection, requests ou chat
automaticamente. Uma nova interação exige as condições normais do contrato.

### 3. Conversation Request e chat privado

`conversation_requests/{requestId}` continua direcional e independente de
Connection. Ao aceitar:

1. o request muda condicionalmente de `pending` para `accepted`;
2. o par recebe autorização para usar o chat determinístico
   `private_{uidA}_{uidB}`;
3. nenhuma Connection é criada;
4. nenhuma mensagem é criada automaticamente.

O chat privado pode existir vazio somente quando houver uma Connection ativa ou
um Conversation Request aceito. A criação física do documento de chat é
opcional e lazy; a primeira mensagem pode criar o documento, desde que as Rules
validem a autorização e os dois participantes.

Mensagens só podem ser escritas após essa autorização. Toda mensagem exige
`senderId == auth.uid` e membership efetiva de exatamente os dois participantes.
Usuários externos não podem escrever diretamente no caminho conhecido.

Enquanto houver Conversation Request pendente, nenhuma mensagem normal pode ser
gravada. Uma segunda solicitação para a mesma direção enquanto houver uma
pendente é idempotente e não cria novo documento. Depois de `declined` ou
`cancelled`, o mesmo documento pode ser reutilizado com novo lifecycle.

Connection posterior não altera nem converte retroativamente o Conversation
Request; ela apenas passa a autorizar o chat por sua própria condição. Bloqueio
suspende o acesso e impede novas mensagens. Desbloqueio não reabre mensagens ou
requests automaticamente.

Não será criada collection `conversations` nesta fase. A implementação de chat a
preservar é `lib/features/chat`; `members` continua apenas como compatibilidade
de dados legados, enquanto `participants` é autoritativo para documentos novos.

### 4. Remoção de Connection

O lifecycle é:

```text
connected → removed → none
```

`connections/{connectionId}` nunca é apagado fisicamente. Campos:

```text
connectionId
userIds
status: connected | removed
createdAt
updatedAt
connectedAt
removedAt?
removedBy?
```

Imutáveis:

- `connectionId`;
- `userIds`;
- `createdAt`;
- `connectedAt`.

Mutáveis somente por transições autorizadas:

- `status`;
- `updatedAt`;
- `removedAt`;
- `removedBy`.

`removed` é persistido como o resultado terminal da relação corrente. Uma nova
conexão após remoção não reativa diretamente o documento determinístico; exige
novo ciclo de request conforme a política atual. O backend rejeita a transição
direta `removed → connected` e não cria eventos ou versões implícitas para
contorná-la.

### 5. `users.friends`

`users.friends` é **LEGACY** e não é fonte autoritativa.

O sistema novo:

- consulta `connections` para determinar `connected`;
- não lê `users.friends` para autorização;
- não atualiza `users.friends` automaticamente;
- não tenta sincronizar silenciosamente arrays antigos;
- mantém usuários antigos funcionando pelos fluxos legados existentes.

Uma futura migração poderá importar relações válidas para `connections` após
inventário, deduplicação, consentimento técnico e validação. Até lá, divergência
entre `users.friends` e `connections` é esperada e deve ser observada, não
resolvida por writes automáticos. Nenhum dado legado será apagado nesta fase.

### 6. Server-side operations

| Operação | Estratégia | Invariantes obrigatórias |
| --- | --- | --- |
| `sendConnectionRequest` | Callable `socialOperation` + transação Admin SDK | requester igual a `auth.uid`, IDs distintos, sem block, sem request pendente conflitante |
| `acceptConnectionRequest` | Backend/Cloud Function | recipient é o destinatário, request ainda `pending`, uma Connection por par, sem block |
| `declineConnectionRequest` | Callable `socialOperation` + transação Admin SDK | somente recipient, transição apenas de `pending` |
| `cancelConnectionRequest` | Callable `socialOperation` + transação Admin SDK | somente requester, transição apenas de `pending` |
| `removeConnection` | Callable `socialOperation` + transação Admin SDK | somente participante, somente `connected`, preserva histórico |
| `createBlock` | Backend/Cloud Function | blocker autenticado, IDs distintos, cancelamento consistente de relações incompatíveis |
| `removeBlock` | Callable `socialOperation` + transação Admin SDK | somente blocker, somente seu documento, `active → removed` |
| `sendConversationRequest` | Callable `socialOperation` + transação Admin SDK | requester igual a `auth.uid`, sem block, não connected, um request pendente por direção |
| `acceptConversationRequest` | Backend/Cloud Function | somente recipient, request `pending`, sem block, autorização coerente do chat |
| `declineConversationRequest` | Callable `socialOperation` + transação Admin SDK | somente recipient, transição apenas de `pending` |
| `cancelConversationRequest` | Callable `socialOperation` + transação Admin SDK | somente requester, transição apenas de `pending` |

Todas as operações acima passam pelo backend, inclusive as que alteram somente
um documento, porque o Admin SDK bypassa Rules e a autorização server-side é
obrigatória.

O cliente nunca pode escolher livremente requester, recipient, participants,
senderId, status final, timestamps de auditoria ou `removedBy`. Timestamps de
servidor e transições condicionais são obrigatórios.

## Matriz final de autorização

| Operação | Permitido | Condição |
| --- | --- | --- |
| Follow | usuário autenticado | segue as Rules e o contrato atual de Follow; não cria Connection |
| Connection Request | usuário autenticado não bloqueado | não connected, IDs distintos, sem pending conflitante |
| Accept Connection | recipient | request `pending`, sem bloqueio; aceita o request; a Connection é criada separadamente |
| Decline Connection | recipient | request `pending`; não cria Connection |
| Cancel Connection | requester | request `pending`; não cria Connection |
| Ver Connection | participantes | sem bloqueio ativo incompatível |
| Remove Connection | qualquer participante | Connection `connected`; marca `removed` |
| Block | usuário autenticado | cria bloqueio unilateral e suspende interações |
| Conversation Request | usuário autenticado não bloqueado | não connected, sem request pendente conflitante |
| Accept Conversation | recipient | request `pending`, sem bloqueio; autoriza chat privado |
| Private Message | participante autorizado | connected ou Conversation Request accepted; `senderId == auth.uid` |
| Group Message | membro do grupo | membership válida do grupo; independente de Connection |

Estados `pendingIncoming` e `pendingOutgoing` não autorizam mensagens privadas.
`blocked` prevalece sobre qualquer outro estado. O usuário conectado tem acesso
ao chat privado, exceto enquanto existir bloqueio ativo.

## Consistência dos cenários críticos

### A → B e B → A

Requests são direcionais, mas o par possui apenas uma Connection ativa. Se ambos
enviarem requests simultaneamente, o backend reconcilia o conflito: aceita no
máximo uma transição válida e impede duas Connections. O resultado deve ser
determinístico e auditável; nenhum request pendente conflitante permanece após
uma Connection ser criada.

### Bloqueio e desbloqueio

```text
A bloqueia B
→ B não pode conectar A
→ B não pode conversar com A
→ requests incompatíveis são cancelados
→ Connection existente fica suspensa

A remove o bloqueio
→ nenhum request ou Connection é reativado automaticamente
→ B pode solicitar novamente se as condições forem atendidas
→ conversa exige Connection ou novo Conversation Request aceito
```

## Definition of Ready final

A próxima fase pode implementar somente quando seguir este contrato, sem novas
decisões fundamentais, pois estão fechados:

- entidades e nomes conceituais;
- estados e transições;
- IDs determinísticos;
- request ativo e histórico;
- bloqueio e seus efeitos;
- Conversation Request e chat privado;
- remoção e retenção de Connection;
- `users.friends` como legado;
- matriz client-side/backend;
- concorrência e idempotência;
- compatibilidade com Follow, grupos e `members`;
- necessidade de Rules e índices como trabalho da próxima fase.

Permanecem pendentes apenas decisões de implementação detalhada, não decisões
arquiteturais: forma exata do histórico de versões de Connection, campos finais
de auditoria e implementação concreta das Functions/Rules conforme os testes.

## Implementação do domínio — Fase 30.3

A Fase 30.3 adiciona somente domínio local e contratos abstratos, sem
persistência:

- `lib/features/social/connections/models/`: enums e modelos validados para
  status, requests, connections e blocks;
- `lib/features/social/connections/identities.dart`: identities determinísticas
  codificadas, com Connection não direcional e requests/blocks direcionais;
- `lib/features/social/connections/services/connection_state_machine.dart`:
  transições puras de lifecycle;
- `lib/features/social/connections/services/connection_policy.dart`: políticas
  puras de conexão, bloqueio, Follow e conversa privada;
- `lib/features/social/connections/repositories/`: interfaces de intenção de
  domínio, sem Firestore;
- `lib/features/social/connections/services/`: interfaces dos serviços de
  Connection, Conversation Request e Block;
- `test/social_connections_domain_test.dart`: testes de identidade, validação,
  lifecycle, idempotência conceitual e políticas.

O domínio novo permanece lado a lado com `SocialProvider`, `friend_requests`,
`users.friends`, Follow e os dois contratos de chat existentes. Nenhum desses
fluxos foi modificado ou convertido em fonte autoritativa.

## Persistência Firestore — Fase 30.4

A Fase 30.4 adiciona somente adaptadores Firestore para o domínio novo:

- `infrastructure/firestore_social_mappers.dart`: conversão isolada entre
  `DateTime`/enums do domínio e `Timestamp`/campos Firestore;
- `infrastructure/firestore_connection_repository.dart`: `connections` e
  `connection_requests`;
- `infrastructure/firestore_conversation_request_repository.dart`:
  `conversation_requests`;
- `infrastructure/firestore_block_repository.dart`: `blocks`;
- `infrastructure/firestore_social_errors.dart`: erros explícitos de dados,
  conflito, ausência e indisponibilidade.

Os quatro documentos usam as identities determinísticas da Fase 30.3. Writes
de criação e transição usam transações e timestamps do servidor; retries
convergem para o documento existente. nenhum chat, `Connection` automática a partir de Conversation Request, dado
legado, UI, Rule, índice ou configuração Firebase foi alterado pela Fase 30.4.
A implementação vigente valida autorização na Callable server-authoritative;
as Rules continuam bloqueando writes diretos.
