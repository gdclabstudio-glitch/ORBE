# P0.7 — LGPD, privacidade e consentimento

## Status

`P0.7 PARCIAL`

O projeto já possui um nível inicial de atendimento a privacidade e consentimento no código local: há consentimento versionado para termos, política de privacidade visualizável no app, e um painel de gestão local de dados (`PrivacyDataManagementPage`) para limpar cache e dados locais. No entanto, ainda não existe um fluxo completo de atendimento a direitos do titular em nível de backend e infraestrutura, especialmente exportação de dados, exclusão de conta em escala, retenção e registro de consentimento por usuário com auditoria server-side.

---

## 1. Escopo da auditoria

A auditoria focou em:

- dados pessoais armazenados no cliente, Firestore e Storage
- ciclo de vida da conta e exclusão
- consentimento e termos
- direitos do titular, portabilidade e deleção
- privacidade social, bloqueios, seguidores e conteúdo privado
- logs e retenção
- minimização e dados locais

## 2. Dados pessoais encontrados

### Firestore / usuários

- nome
- e-mail
- foto/avatar
- bio
- preferências e configurações
- status de privacidade (`private`)
- followers/following
- bloqueios e silenciamentos
- notificações
- stories e posts
- comentários e reações
- denúncias
- mensagens privadas e chats

Esses dados estão na maior parte em coleções do Firestore e são acessados por regras (`firestore.rules`) com autoria do usuário, permissão de leitura pública/privada, e privacidade por perfil. O `private` do usuário, seguidores e subcoleções de `stories`/`views` ajudam a reduzir vazamento de dados, mas dependem de conjunto correto de regras e ausência de arrays legados.

### Storage

- fotos de perfil
- stories e mídia
- imagens e vídeos de posts
- recursos de chat

O armazenamento é controlado por `storage.rules` e exige ownership, tipo MIME e limite de tamanho. Isso reduz risco de upload indevido e uso de arquivos indevidos, mas não substitui um mecanismo de exclusão por conta ou retenção por ciclo de vida.

### Local Storage / dispositivo

- termos aceitos
- onboarding concluído
- memórias offline
- cache de imagens
- preferências e dados locais

O `PrivacyDataManagementPage` remove cache e dados locais sensíveis do dispositivo, mas isso não afeta dados persistidos no backend.

---

## 3. Riscos identificados

### CRITICAL

- Ausência de fluxo server-side de exportação e exclusão de dados do usuário para dados persistidos em Firestore/Storage. O `deleteCurrentUserWithPassword` do cliente reautentica e apaga a conta no Firebase Auth, mas não há prova de cascata completa para registros do projeto, mídia e conteúdo relacionado.
- Falta de registro de consentimento vinculado a um usuário/UID e a versão legal aprovada em um armazenamento server-side ou identificável por auditoria. O app armazena `terms_accepted_v1` localmente, mas não existe prova de consentimento de produção com metadata de data/hora e versão aceita em backend.

### HIGH

- Risco de dados pessoais permanecerem no Firestore/Storage após a exclusão da conta, especialmente uploads de mídia, stories, posts, mensagens, comentários e logs administrativos.
- Ausência de política de retenção formal e cronograma de eliminação para logs/eventos, storage e documentos de moderação.
- Cadeia de direitos do titular não está implementada de forma automatizada: não há exportação completa de dados nem solicitação robusta de exclusão no backend.

### MEDIUM

- A interface de termos e política existe, mas a revisão posterior e a reaceitação por versão legal não têm um fluxo explícito em toda a experiência, além do gate de onboarding/landing.
- A privacidade social depende de regras e do modelo de seguidores, mas a revisão de conteúdo compartilhado e do ciclo de vida do usuário continua sendo um esforço de produção e não de código isolado.
- A `PrivacyPage` e `TermsPage` são relevantes, mas ainda não representam uma governança completa de LGPD/privacidade; elas são disclosures, não um processo orquestrado de DSR.

### LOW

- Dados de uso e logs operacionais podem permanecer em pouca quantidade sem política formal de minimização.
- O app ainda usa armazenamento local para dados que podem ser sensíveis; o uso depende de limpeza explícita e não de política de retenção.

---

## 4. Vulnerabilidades corrigidas / controles já presentes

### Consentimento e termos

- `lib/views/terms_page.dart`
  - versionamento dos termos com chave `terms_accepted_v1`
  - migração de chave legada (`terms_accepted`) para a nova chave
  - bloqueio de loop de aceite e push para `/landing` ou `/onboarding`

### Política de privacidade

- `lib/views/privacy_page.dart`
  - política de privacidade acessível ao usuário
  - descrição de finalidade, compartilhamento, segurança, direitos e atualizações

### Gestão local de dados

- `lib/views/privacy_data_management_page.dart`
  - limpeza de cache de imagens
  - exclusão de dados locais sensíveis do dispositivo

### Acesso e restrição social

- `firestore.rules`
  - leitura de perfis controlada por `private`, seguidores e políticas de `owner`/`admin`
  - regras de stories, followers/following, mensagens e conteúdo sensível
  - bloqueio de writes arbitrários de campos de privilégio (`roles`, `permissions`, `role`, etc.)

### Logs e observabilidade

- `lib/main.dart`
  - inicialização de observabilidade com registro de eventos e erro sem expor secrets

---

## 5. Controles pendentes / dependentes de configuração externa

### DSR e direitos do titular

`AÇÃO MANUAL NECESSÁRIA`

Não há fluxo implementado para:

- exportação de dados pessoais em formato legível pelo usuário
- solicitação formal de acesso ao dado em backend
- exclusão em cascata de Firestore, Storage, posts, stories, chats e notificações
- confirmação de que registros de auditoria preservam o mínimo necessário e não expõem PII

### Consentimento auditável

`AÇÃO MANUAL NECESSÁRIA`

O projeto precisa de:

- registro server-side do consentimento aceito por usuário
- versão política aceita
- data/hora do aceite
- vínculo com UID e evento de auditoria
- mecanismo para reaceitação ao mudar a política

### Retenção e eliminação de mídia

`AÇÃO MANUAL NECESSÁRIA`

- lifecycle policy no Cloud Storage para remover arquivos expirados
- exclusão automática ou agendamento de mídias ligadas a postagem/conta
- regra de retenção para `admin_audit_logs`, `reports`, `notifications` e registros de moderação

### Revisão jurídica e processos

`AÇÃO MANUAL NECESSÁRIA`

- revisão jurídica da política de privacidade e termos
- designação de DPO/responsável pela privacidade
- canais de atendimento de pedidos do titular e SLA
- revisão de compatibilidade com LGPD e regulações locais

---

## 6. Riscos residuais

- a arquitetura atual não oferece prova de que o ciclo de vida da conta está completo em produção
- a exclusão do usuário no Auth não garante remoção completa no banco e no Storage
- o consentimento é local e não auditável em backend
- não há política formal de retenção e minimização para todos os dados sensíveis
- a porta de privacidade social e conteúdo privado depende de regras, manutenção e revisão constante

---

## 7. Testes executados

Comandos executados no repositório:

- `cd "C:\Users\gusta\OneDrive\Desktop\LaBomba_app-main\LaBomba_app-main.worktrees\pasted-text-processing-c6dbe1b1"; dart format .` → sucesso
- `cd "C:\Users\gusta\OneDrive\Desktop\LaBomba_app-main\LaBomba_app-main.worktrees\pasted-text-processing-c6dbe1b1"; flutter analyze` → sucesso
- `cd "C:\Users\gusta\OneDrive\Desktop\LaBomba_app-main\LaBomba_app-main.worktrees\pasted-text-processing-c6dbe1b1"; flutter test` → sucesso
- `cd "C:\Users\gusta\OneDrive\Desktop\LaBomba_app-main\LaBomba_app-main.worktrees\pasted-text-processing-c6dbe1b1\backend\functions"; npm run build` → sucesso

A validação local confirma que os controles e testes existentes em código não quebraram; porém, os fluxos de DSR, exclusão em cascata e consentimento server-side continuam sem prova operacional fora do ambiente real do Firebase.

---

## 8. Conclusão

O código local já contém uma base essencial de privacidade e consentimento, especialmente em termos, política de privacidade e limpeza local de dados. Isso reduz risco do cliente e melhora transparência. No entanto, a etapa não pode ser marcada como concluída de forma pronta para produção porque ainda faltam mecanismos server-side e jurídicos para exportação, exclusão, política de retenção e consentimento auditável.

A próxima etapa recomendada é:

**P0.8 — Observabilidade, Logs e Gestão de Incidentes.**
