# P0.8 — Observabilidade, logs e gestão de incidentes

## Status

`P0.8 PARCIAL`

O projeto já possui um núcleo de observabilidade em Flutter e Cloud Functions, com Analytics, Crashlytics e registros de eventos em alguns fluxos. No entanto, a implementação ainda é incompleta: há muitos `catch` silenciosos, logger sem padronização, ausência de política clara de redaction, falta de correlation IDs e ausência de documento de resposta a incidentes para a operação em produção.

---

## 1. Estado anterior

Antes da correção:

- `lib/services/observability_service.dart` registrava eventos e erros, mas com `catch (_) {}` silenciosos em pontos importantes.
- Muitos erros eram apenas ignorados na UI/serviços, o que impossibilitava diagnóstico real.
- Cloud Functions usavam `console.error` e `console.warn` com payloads crus, sem sanitização de dados sensíveis.
- Não havia um documento formal de severidade de incidente, procedures de contenção, comunicação e post-mortem.
- Não havia política explícita de minimização de dados em logs.

---

## 2. Problemas encontrados

### Observabilidade e logs

- `ObservabilityService.logEvent`, `setUserId` e `reportError` tinham tratamento de erro silencioso.
- `Analytics` e `Crashlytics` recebiam dados sem sanitização, podendo captar valores sensíveis em parâmetros arbitrários.
- Backend tinha `console.warn/error` sem estrutura e sem máscara de dados críticos.
- Ausência de correlation ID para rastrear contexto de operação em request/trigger.

### Tratamento de erros

- Itens `catch` vazios impediam rastreio de falhas e criavam estado silencioso.
- O código que registra erros no cliente fazia isto sem contexto suficiente para diagnóstico em produção.
- Há fluxos de admin/notifications/chat/report que exigem observabilidade específica em produção, mas atualmente dependem de logs ad hoc.

### Operação e incidentes

- O projeto não possuía classificação formal de incidentes (SEV-0, SEV-1, SEV-2, SEV-3).
- Não havia procedimento de detecção, contenção, investigação, comunicação e encerramento.
- Não havia explicitação do que não pode constar em logs.

---

## 3. Riscos

- Falhas de autenticação e admin podem ocorrer sem alerta útil.
- Erros de notificação, chat e reports podem ser percebidos apenas pela experiência do usuário, sem rastreio técnico.
- Dados privados podem aparecer em logs se parâmetros de eventos forem mal construídos.
- A ausência de correlation ID dificulta a investigação de incidentes distribuídos entre Flutter, Cloud Functions e Firestore.

---

## 4. Alterações realizadas

### Flutter / cliente

Arquivo alterado:

- `lib/services/observability_service.dart`

Mudanças:

- adicionada sanitização para chaves sensíveis (`password`, `token`, `authorization`, `secret`, `api_key`, `refresh_token`, etc.)
- adicionado `generateCorrelationId()` para criação de identificadores de correlação
- `logEvent()` agora sanitiza parâmetros antes de registrar em Analytics
- `setUserId()` não aceita valores vazios/espúrios e continua com tratamento seguro
- `reportError()` e `recordFlutterError()` preservam logging técnico sem ocultar a falha
- erros que ainda falham na própria observabilidade agora emitem prints locais em debug mode, sem expor secrets

### Backend / Cloud Functions

Arquivo alterado:

- `backend/functions/src/index.ts`

Mudanças:

- adicionado `sanitizeForLogs()` para reduzir payloads em logs
- adicionado `logStructured()` para produzir JSON de log padronizado com `ts`, `level`, `event` e `payload`
- remoção de `console.warn/error` com payload cru; agora os logs são estruturados e sanitizados
- eventos críticos de admin/notifications/chat/report passaram a registrar contexto mínimo útil sem expor dados sensíveis

### Testes

Arquivo adicionado:

- `test/observability_service_test.dart`

Valida:

- mascaramento de chaves sensíveis
- geração de correlation ID com prefixo estável

---

## 5. Alterações não realizadas

As seguintes melhorias foram identificadas, mas não implementadas por não serem de baixo risco e/ou requererem configuração externa real:

- configuração de alertas de monitoramento em Firebase/GCP real
- dashboards e SLOs em produção
- alertas por incidentes em Cloud Monitoring/Google Cloud
- mensuração de performance em ambiente real com análise de traces e latência real
- políticas de retenção de logs em produção
- integração com sistema de incident management externo

Essas ações continuam dependentes do ambiente real e da infra de operação.

---

## 6. Arquitetura de observabilidade proposta

### Níveis de log

- `info`: eventos normais de uso e operação
- `warn`: comportamento anormal, mas recuperável
- `error`: falha funcional ou operacional significativa
- `critical`: incidente grave ou risco de segurança/companhia

### Eventos críticos a observar

- autenticação falha (`auth_failure`)
- admin action rejected / denied / failed
- report submission / moderation flows
- notification send failures
- chat delivery failures
- upload failures
- storage failures
- backend function exceptions

### Dados proibidos em logs

- senha
- token / refresh token
- API keys / secrets
- cookies / session IDs
- conteúdo privado desnecessário
- PII desnecessária
- qualquer dado que permita reconstituir credenciais

---

## 7. Modelo de incidente

### SEV-0
- Comprometimento grave de segurança ou perda massiva de dados.
- Detecção: alerta automático, falha crítica ou evidência de comprometimento.
- Contenção: bloquear acesso, revisar credenciais, isolar serviço.
- Investigação: forense e análise de logs.
- Comunicação: informar stakeholders e time de resposta.
- Correção: isolamento e reparo.
- Validação: testes e checagem de segurança.
- Encerramento: confirmação de restauração normal.
- Post-mortem: documentar causa, impacto e ações preventivas.

### SEV-1
- Falha crítica que impede grande parte do sistema.
- Detecção: monitoramento, deploy issue, falhas replicadas.
- Contenção: fallback operacional, feature flag, rollback seguro.
- Investigação: logs e reproduções.
- Comunicação: status e ETA para usuários/internos.
- Correção: patch e validação.
- Encerramento: reabilitação do serviço.
- Post-mortem: análise e ação de remediação.

### SEV-2
- Falha importante com workaround.
- Detecção: alertas, tickets e sinais de degradação.
- Contenção: workaround de cliente/servidor.
- Investigação: causa raiz e extensão do impacto.
- Comunicação: transparência interna e impacto esperado.
- Correção: integração e validação.
- Encerramento: confirmação de estabilidade.
- Post-mortem: documentar aprendizado.

### SEV-3
- Falha localizada ou menor.
- Detecção: incidentes operacionais pontuais.
- Contenção: mitigação local.
- Investigação: confirmar causa raiz.
- Comunicação: atualização mínima no fluxo operacional.
- Correção: hotfix ou correção emergencial.
- Validação: teste de regressão.
- Encerramento: fechar o registro.
- Post-mortem: registrar se necessário.

---

## 8. Pendências externas

`AÇÃO MANUAL NECESSÁRIA`

- configurar alertas reais em Firebase/GCP/monitoramento
- estabelecer SLO/SLA de operação
- configurar dashboards de backend e app
- definir retenção real de logs em ambiente de produção
- definir processo de resposta a incidentes e comunicação externa
- revisar um plano de backup/DR com integração de observabilidade

---

## 9. Testes executados

- `cd "C:\Users\gusta\OneDrive\Desktop\LaBomba_app-main\LaBomba_app-main.worktrees\pasted-text-processing-c6dbe1b1"; dart format .` → sucesso
- `cd "C:\Users\gusta\OneDrive\Desktop\LaBomba_app-main\LaBomba_app-main.worktrees\pasted-text-processing-c6dbe1b1"; flutter analyze` → sucesso
- `cd "C:\Users\gusta\OneDrive\Desktop\LaBomba_app-main\LaBomba_app-main.worktrees\pasted-text-processing-c6dbe1b1"; flutter test` → sucesso
- `cd "C:\Users\gusta\OneDrive\Desktop\LaBomba_app-main\LaBomba_app-main.worktrees\pasted-text-processing-c6dbe1b1\backend\functions"; npm run build` → sucesso

---

## 10. Riscos residuais

- sem alertas reais em produção, incidentes podem ser detectados apenas pela experiência do usuário
- sem dashboards e monitoramento reais, gargalos de produtividade e performance não serão medidos com precisão
- sem retenção de log e revisão do ambiente real, observabilidade continua dependente de policy externa

---

## 11. Próxima etapa

A próxima etapa recomendada é:

**P0.9 — Resiliência, estabilidade e qualidade de release.**
