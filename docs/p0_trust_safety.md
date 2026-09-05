# P0.6 — Trust & Safety, Moderação, Denúncias, Bloqueios e Antiabuso

## STATUS

`P0.6 PARCIAL`

O projeto já possui alguns blocos de infraestrutura de segurança, especialmente em autorização administrativa e auditoria, mas a camada de Trust & Safety ainda não está pronta para produção. Há um progresso concreto na remoção de escrita direta de denúncias no cliente e na entrada de regras para `reports` protegidas por autenticação e autorização real no backend.

## SUPERFÍCIES AUDITADAS

- usuários: bloqueio, silenciamento, seguidores, perfis privados, contas suspensas
- conteúdo: posts, comentários, stories, mensagens, mídia, comunidades e eventos
- administração: Control Center, admin requests, auditoria, moderação básica
- backend: Cloud Functions, Firestore, Storage, Auth
- privacidade e abuso: denúncia, bloqueio, perfil, interações, uploads

## VULNERABILIDADES

### CRITICAL

- Nenhuma vulnerabilidade crítica localmente confirmada após o reforço administrativo anterior; porém, o sistema de denúncias ainda não tinha pipeline de moderação e triagem real, o que torna a investigação e a ação dependentes de processo manual e de regras severamente incompletas.

### HIGH

- Usuário comum podia escrever diretamente em `reports` sem validação robusta do backend. Isso foi corrigido parcialmente pela introdução de `submitReport` e pela regra de Firestore para `reports`.
- O bloqueio de usuários continua sendo um risco operacional se o enforcement não for aplicado em mensagens, follows e comentários de forma consistente no backend.
- O sistema de moderação ainda não tem fila, triagem, decisão, restauração, appeals ou retenção formalizados.

### MEDIUM

- Falta de rate limiting e anti-spam básico para criação massiva de ações sociais.
- Faltam logs e políticas de retenção para ações de moderação e bloqueio.
- O sistema de denúncias ainda precisa de uma triagem real e de auditoria de decisão administrativa.

### LOW

- Alguns fluxos de UX podem ainda indicar sucesso sem garantir que a decisão tenha sido processada por backend.
- A diferenciação entre `moderador`, `admin` e `owner` ainda precisa ser reforçada em cada ação destrutiva e na triagem.

## CORREÇÕES

### Implementadas no repositório

- Introdução de `submitReport` em `backend/functions/src/index.ts`.
- Validação de payload de denúncia com categoria, tipo e identificador do recurso.
- Restrição de escrita em `reports` via `firestore.rules` para usuários autenticados apenas com `reporterId` próprio, e leitura apenas por atores privilegiados.
- Atualização dos pontos de cliente que criavam denúncias diretamente em Firestore para usar o callable backend em:
  - `lib/features/social/views/social_feed_page.dart`
  - `lib/features/profile/user_profile_page.dart`

### Não implementado porque depende de produção / infraestrutura externa

- MFA real para contas administrativas
- políticas de rate limiting em Firebase/App Check/Cloud Armor/infraestrutura da app
- enforcement de bloqueio definitivo para todos os fluxos de interações
- fila de moderação completa com triagem/decisão/auditoria
- anti-abuse avançado e detecção automatizada

## PENDÊNCIAS

- curation de `reports` e moderadores reais
- revisão final de bloqueio na camada de mensagens e interações
- implementação de rate limiting real e anti-abuse para ações massivas
- MFA e reautenticação para owner/admin no Firebase real
- retenção e governança de logs de moderação

## AÇÕES MANUAIS

`AÇÃO MANUAL NECESSÁRIA`

- Firebase Console: validar claims reais de `owner` e `admin`
- Firebase Console: revisar proteção de `reports` e revisão manual por moderadores
- IAM / Google Cloud: políticas de funções e alerting
- Configuração de MFA e reauth para contas de risco alto
- Política de ações de moderação e bloqueio para produção

## TESTES

Executado localmente:

- `cd "C:\Users\gusta\OneDrive\Desktop\LaBomba_app-main\LaBomba_app-main.worktrees\pasted-text-processing-c6dbe1b1"; dart format .` → sucesso
- `cd "C:\Users\gusta\OneDrive\Desktop\LaBomba_app-main\LaBomba_app-main.worktrees\pasted-text-processing-c6dbe1b1"; flutter analyze` → sucesso
- `cd "C:\Users\gusta\OneDrive\Desktop\LaBomba_app-main\LaBomba_app-main.worktrees\pasted-text-processing-c6dbe1b1"; flutter test` → sucesso
- `cd "C:\Users\gusta\OneDrive\Desktop\LaBomba_app-main\LaBomba_app-main.worktrees\pasted-text-processing-c6dbe1b1\backend\functions"; npm run build` → sucesso

Não executado com sucesso em ambiente local:

- `cd "C:\Users\gusta\OneDrive\Desktop\LaBomba_app-main\LaBomba_app-main.worktrees\pasted-text-processing-c6dbe1b1\backend\functions"; node --test test/firestore-rules.test.js` → `BLOQUEIO OPERACIONAL — Firestore Emulator não disponível`

## RISCOS RESIDUAIS

- O bloqueio de usuários ainda não é enforcement completo em todas as interações do app.
- A moderação e a triagem ainda exigem processo humano e infraestrutura real.
- Rate limiting expressivo e anti-abuse automatizado ainda não foram validados em produção.
- Qualquer configuração de MFA, sessão e claims no Firebase real ainda pode mudar o status de segurança.

## PRÓXIMA ETAPA

**P0.7 — LGPD, Privacidade e Consentimento**
