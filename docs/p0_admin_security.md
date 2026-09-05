# P0.5 — Segurança administrativa avançada, reautenticação, MFA e auditoria

## Status

`P0.5 PARCIAL`

O projeto já possui um hardening administrativo relevante implementado no código local e validável no repositório: autenticação administrativa backend-authoritative, `auth_time` para ações críticas, validação de payload e claims, e registro de auditoria. Porém, a etapa não pode ser considerada concluída como produção-ready porque MFA forte, revogação de sessão em escala e políticas reais de IAM/console dependem de configuração externa do Firebase/Google Cloud e não podem ser comprovadas localmente.

---

## 1. Vulnerabilidades encontradas

### CRITICAL

- Nenhuma vulnerabilidade crítica restante confirmada no repositório após a correção do bypass de privilégios em `submitAdminRequest`/`assignRoleClaims` e no backend de processamento de `admin_requests`.
- O risco crítico principal que já foi mitigado é a possibilidade de a UI ser confundida com autoridade real, sem verificação de privilégios no backend.

### HIGH

- Dependência de `custom claims` e de IAM real do Firebase para autenticação administrativa. Sem console/configuração correta, o ambiente local não reflete a política de produção.
- Falta de MFA/reauth de produção para contas `owner/admin` em ações sensíveis, quando o provider real do Firebase não está configurado para exigir MFA.
- Bloqueio e moderação de usuários/conteúdo continuam exigindo arquitetura adicional de enforcement server-side, não apenas arrays client-side.

### MEDIUM

- `auth_time` foi adotado como mecanismo de reautenticação recente para ações críticas, mas isso ainda depende de contexto real de sessão do Firebase e da política do projeto.
- `admin_guard` e `AdminAuthProvider` são importantes como UX/guardrails, mas não substituem autorização real no backend.
- A auditoria registra ações importantes, mas dependências de retenção, alerting e governança continuam sendo requisitos de produção.

### LOW

- Mensagens de erro e logs de backend devem continuar sendo revisados para evitar vazamento de detalhes desnecessários.
- A diferenciação entre `owner`, `admin` e `moderator` precisa ser rigorosamente documentada e testada conforme o fluxo real do produto.

---

## 2. Correções implementadas

### Backend-authoritative admin authorization

A correção já validada no repositório foi a centralização da autorização em backend em:

- `backend/functions/src/index.ts`

Controles implementados:

- validação de payload de ação administrativa
- normalização de `type`/`resourceType`/`resourceId`
- rejeição de ações não reconhecidas
- validação de `auth_time` para ações críticas
- checagem de claims `owner`, `admin`, `isOwner`, `isAdmin`
- bloqueio de criação de claims de papel por cliente
- processamento de `admin_requests` apenas por backend
- `admin_audit_logs` registrados por backend e não por cliente

### Auditoria administrativa

- `admin_requests` e `admin_audit_logs` agora são tratados como coleções server-only / privileged em `firestore.rules`.
- `processAdminRequest` grava eventos e resultados em auditoria, registrando quem executou, qual ação, alvo e resultado.

### Reautenticação recente

- `ensureFreshAdminAuth()` foi implementado para exigir `auth_time` recente em ações críticas como:
  - `delete_post`
  - `ban_user`
  - `mass_fcm`
  - `assignRoleClaims`
  - `moderate_community`
  - `review_story`
  - `system_alert`

---

## 3. Controles pendentes e dependentes do console

### MFA

`AÇÃO MANUAL NECESSÁRIA`

O código local pode validar a existência de claims e a lógica de ações críticas, mas MFA real para contas administrativas depende do Firebase Console / Google Cloud / Identity Platform e de políticas de autenticação do projeto real.

O que pode ser validado localmente:

- lógica de decisão no backend
- validação de `auth_time`
- ações que exigem reautenticação
- registro de auditoria e bloqueio de ação sem autorização

O que não pode ser validado localmente:

- MFA real para `owner`/`admin`
- enforcement de MFA no projeto autenticado
- revogação de sessão e sessão antiga em produção

### RBAC real em produção

`AÇÃO MANUAL NECESSÁRIA`

As claims devem ser configuradas no Firebase real e validadas em ambiente de produção. O código local não pode criar, validar ou provar essas configurações fora do projeto real.

### Sessão / revogação / logout em produção

`AÇÃO MANUAL NECESSÁRIA`

A política de sessão administrativa, revogação de refresh tokens, expiração e invalidation real precisa ser configurada junto ao provider real da autenticação.

---

## 4. Riscos residuais

- MFA real não foi comprovado no ambiente de produção.
- Revogação de sessão e expiração de token administrativo em produção dependem da configuração do Firebase/Google Cloud.
- Bloqueio social e políticas de moderação ainda precisam de enforcement server-side e revisão de arquitetura para não depender de arrays client-side.
- Claims de `owner/admin` continuam sendo um ponto crítico de governança; qualquer erro de configuração no console terá impacto direto.

---

## 5. Testes executados

Executado localmente no repositório:

- `cd "C:\Users\gusta\OneDrive\Desktop\LaBomba_app-main\LaBomba_app-main.worktrees\pasted-text-processing-c6dbe1b1"; dart format .` → sucesso
- `cd "C:\Users\gusta\OneDrive\Desktop\LaBomba_app-main\LaBomba_app-main.worktrees\pasted-text-processing-c6dbe1b1"; flutter analyze` → sucesso
- `cd "C:\Users\gusta\OneDrive\Desktop\LaBomba_app-main\LaBomba_app-main.worktrees\pasted-text-processing-c6dbe1b1"; flutter test` → sucesso
- `cd "C:\Users\gusta\OneDrive\Desktop\LaBomba_app-main\LaBomba_app-main.worktrees\pasted-text-processing-c6dbe1b1\backend\functions"; npm run build` → sucesso

Teste de regras específico do backend:

- `cd "C:\Users\gusta\OneDrive\Desktop\LaBomba_app-main\LaBomba_app-main.worktrees\pasted-text-processing-c6dbe1b1\backend\functions"; node --test test/firestore-rules.test.js` → não validado neste ambiente porque o emulador do Firestore não estava disponível/ativo; a falha foi operacional e não de compilação.

---

## 6. Recomendação de próxima etapa

A próxima etapa planejada é:

**P0.6 — Trust & Safety, Moderação e Antiabuso.**

A implementação dessa etapa não deve começar automaticamente antes da confirmação dos controles administrativos de produção, MFA real e governança de claims no Firebase real.
