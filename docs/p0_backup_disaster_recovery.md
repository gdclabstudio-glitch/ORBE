# P0.1 — Backup e Disaster Recovery (La Bomba)

## 1. Status da análise

Status geral: `PARCIAL / NÃO IMPLEMENTADO`.

O projeto contém configuração Firebase e estrutura de dados social, mas não há estratégia de backup/restore documentada nem automatizada no repositório. O backup e a recuperação são dependentes do console do Firebase e de políticas de retenção/configuração do projeto.

### Dados identificados que precisam ser protegidos

- Firestore
  - `users/*` (perfil, privacidade, seguidores, bloqueios, configurações, tokens, metadados)
  - `posts/*` (conteúdo, autor, mídia, comentários/reações em subcoleções)
  - `users/*/stories/*` (conteúdo efêmero, visualizações, reações)
  - `chats/*/messages/*` (mensagens privadas e mídia)
  - `communities/*`, `events/*`, `notifications/*`, `admin_requests/*`, `admin_audit_logs/*`
  - `system_events/*`, `system_metrics/*`
- Storage
  - avatares de usuários
  - mídia de posts, stories, chat, memórias e ativos de site
  - arquivos de upload associados a autores e participantes
- Cloud Functions
  - código e configuração da lógica de backend
  - regras de segurança e integrações de notificações
- Configuração e ambiente
  - Firebase project identifiers
  - Google services configuration
  - custom claims / admin identities
  - tokens e chaves de aplicação

### Dados que podem ser recriados

- arquivos de branding e assets estáticos do app
- métricas agregadas derivadas e eventos de analytics
- tokens FCM que podem ser reemitidos quando o usuário reautentica
- registros de cache local em device
- conteúdo gerado por bot/seed/seed local

### Riscos de perda de dados e operacionais

- exclusão acidental de documentos no Firestore
- sobrescrita de documentos críticos por regra ou cliente malicioso
- perda de uploads no Storage por exclusão, bucket corrompido ou política errada
- ausência de versionamento/retention em Storage
- ausência de backup automatizado do Firestore e da instância de Storage
- auditoria administrativa inexistente ou inconsistente
- ausência de procedimento formal de restore
- dependência de console do Firebase para decisões operacionais críticas

### Evidência local

Não foi encontrado no repositório qualquer mecanismo de:

- `firestore:export`
- `gcloud storage` backup automation
- backup schema/retention policy documentado
- restore drill execution
- scripts de verificação de backup

Esta etapa conclui que o projeto possui configuração Firebase e regras, mas ainda não possui backup operacional documentado e validado.

---

## 2. Estratégia proposta de Backup e DR

### 2.1 Firestore

Estratégia recomendada:

- Ativar export contínuo/planejado de backup do Firestore no Firebase Console ou via Firebase CLI em cron job seguro.
- Manter um dataset de backup em um bucket GCS separado do bucket de produção.
- Exportar por período diário, com retenção de 30 a 90 dias para dados críticos, e 365 dias para dados de auditoria e logs administrativos quando permitido por compliance.
- Separar backups por data/hora com nomenclatura estável e verificar integridade do pacote exportado.

Objetivos:

- RPO alvo: 1 hora para dados críticos e 24 horas para dados não críticos.
- RTO alvo: 4 horas para recuperação operacional de coleções essenciais e 24 horas para recuperação completa.

### 2.2 Storage

Estratégia recomendada:

- Habilitar versionamento de objetos no bucket de armazenamento do projeto.
- Habilitar lifecycle rules para mover blobs antigos para armazenamento de menor custo ou congelados.
- Exportar manifestos e metadados críticos (ownerUid, timestamps, paths, contentType) em paralelo ao backup do bucket.
- Usar bucket diferente para backup/offsite ou bucket de exportação dedicado.

Objetivos:

- RPO alvo: 1 hora para mídia crítica (avatares, stories, chat, posts).
- RTO alvo: 6 horas para recuperação de mídia e 24 horas para reconstrução completa do bucket.

### 2.3 Retenção

Recomendação base:

- Dados críticos (usuários, posts, stories, chats, moderação): 30 a 90 dias de snapshot, com backup diário e retenção mínima de 30 dias.
- Registros de auditoria e admin: 365 dias ou conforme política legal.
- Mídia em Storage: versionamento ativo por 30 a 90 dias e retenção longa para conteúdos de relevância legal/operacional.
- Backups locais temporários: 7 a 14 dias, com criptografia em repouso e exclusão automática.

### 2.4 Frequência

- Firestore: backup diário + export em janela de baixa utilização; para produção real, preferir backup incremental/contínuo e diário completo. 
- Storage: snapshot diário ou pós-upload crítico; versionamento ativo no bucket de produção para proteção imediata.
- Logs/auditoria: export diário ou em tempo real para solução de observabilidade/Cloud Logging.

### 2.5 RPO / RTO

- RPO crítico: 1 hora
- RPO de conteúdo social geral: 24 horas
- RTO crítico: 4 horas
- RTO de mídia: 6 horas
- RTO de desastre regional ou perda total: 24 a 72 horas, dependendo do processo externo do Firebase Console/GCS

### 2.6 Restauração

- Restaurar primeiro regras e configuração do projeto.
- Restaurar Firestore exportado em projeto de staging ou de produção em janela planejada.
- Restaurar bucket de Storage após validar integridade do snapshot.
- Reaplicar permissões e claims do proprietário/admin.
- Validar conteúdo e referências cruzadas.
- Recarregar tokens FCM, serviços externos e usuários.

### 2.7 Teste de restauração

- Realizar drill sem produção em ambiente de staging pré-produção.
- Validar: importação do Firestore, intactness das subcoleções, permissões, arquivos de Storage e relacionamentos.
- Simular perda parcial e perda completa do bucket.
- Registrar resultados e tempo de recuperação.

### 2.8 Proteção de configuração

- Separar ambientes: `DEV`, `STAGING`, `PRODUCTION`.
- Usar projetos separadores e cargos distintos.
- Guardar arquivos de configuração em repositório somente com placeholders ou referências não sensíveis.
- Não versionar segredos reais no Git.
- Usar Secret Manager / IAM / Firebase Console para dados de acesso crítico.

### 2.9 Secrets e configuração

Conforme verificado no projeto local, há evidência de configuração Firebase no arquivo:

- `android/app/google-services.json`

Esse arquivo contém identificadores e referências de configuração do projeto do Firebase e deve ser tratato como artefato sensível. Não deve conter chaves secretas em repositório público ou em artefatos de build compartilhados.

`SECRET/KEY ENCONTRADO — localização: android/app/google-services.json`

Não copie valores reais no relatório nem no repositório.

### 2.10 Auditoria e monitoramento

- Registrar cada backup gerado com timestamp, projeto, escopo e responsável.
- Validar integridade do arquivo exportado e do bucket de backup.
- Enviar alertas para falha de exportação, falha de versionamento e idade do backup.
- Manter logs de ações críticas do console/Cloud Logging.

### 2.11 Documentação e procedimento de emergência

- Criar runbook interno com passos de: identificação do problema, contenção, backup, restore, validação e comunicação.
- Registrar owner de operação, responsável e contato para recuperação.
- Definir ordem de prioridade: regras → dados → mídia → claims → integrações → comunicação externa.

---

## 3. Ações manuais necessárias no Firebase Console

`AÇÃO MANUAL NECESSÁRIA`

Para implementar a estratégia real em produção, é necessário:

- habilitar Firestore backup no Firebase Console / Google Cloud;
- ativar versionamento de objetos no bucket de Storage;
- habilitar lifecycle policies e retenção do bucket;
- configurar alertas para falha de backup/export;
- separar projetos DEV/STAGING/PRODUCTION;
- confirmar o identidade do owner/admin e custom claims no console;
- estabelecer procedimento de restore real em ambiente controlado.

Estas ações não podem ser validadas localmente sem acesso ao ambiente real do projeto e, portanto, devem ser executadas no console do Firebase/GCP por quem tem autorização.

---

## 4. Implementação segura feita neste repositório

### Arquivos adicionados

- `scripts/firebase_backup_export.ps1`
- `docs/p0_backup_disaster_recovery.md`

### O que foi implementado com segurança

- documentação da estratégia e dos critérios de backup/DR;
- script de export local em modo dry-run com instruções explícitas;
- inclusão de `backups/` em `.gitignore` para evitar versionamento de cópias de backup.

### O que não foi implementado

- nenhuma ação de export real de produção;
- nenhuma configuração de backup no Firebase Console;
- nenhum restore real;
- nenhuma alteração em regras, storage rules ou produção.

---

## 5. Recomendação de implementação após aprovação

1. Habilitar backups do Firestore e Storage no Firebase Console.
2. Criar bucket de backup dedicado e políticas de retenção.
3. Configurar alertas/monitoramento.
4. Testar restore em staging.
5. Revisar owner/admin claims e políticas de acesso.
6. Incluir a DR no runbook operacional de produção.

---

## 6. Conclusão prática

O projeto ainda não está preparado para produção em termos de backup e disaster recovery. Há infraestrutura e dados importantes, mas essa camada precisa ser configurada no ambiente Firebase real e validada via teste de restauro antes de considerar a plataforma segura para uso real.
