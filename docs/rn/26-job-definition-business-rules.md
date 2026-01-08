# Documento de Regras de Negócio — JobDefinitions

## 1. Introdução
Este documento descreve de forma detalhada as regras de negócio do módulo **JobDefinitions** no sistema IAM (VianaID).

Um **JobDefinitions** (ou Job) representa uma tarefa agendada ou sob demanda que executa operações automatizadas na plataforma, utilizando Hangfire como engine de execução e monitoramento.

---

## 2. Objetivos do Módulo de JobDefinitions
- Catalogar e gerenciar jobs da plataforma.  
- Centralizar configurações de agendamento (Cron expressions).
- Controlar ativação/desativação de jobs sem deploy de código.
- Registrar metadados e histórico de configurações.
- Integrar com Hangfire para execução e monitoramento.
- Garantir auditoria de alterações em jobs críticos. 
- Suportar múltiplas categorias de jobs (Cleanup, Maintenance, Security, Billing, etc).

---

## 3. Estrutura Geral do JobDefinitions
Um **JobDefinitions** contém:  
- `Id`
- `Code` (código técnico gerado automaticamente pelo sistema)
- `JobCategory` (categoria do job)
- `JobName` (nome único do job)
- `Description`
- `JobPurpose` (propósito/objetivo)
- `JobType` (namespace e classe no código C#)
- `JobMethod` (método a ser executado)
- `CronExpression` (agendamento)
- `TimeZoneId` (timezone para execução)
- `ExecuteOnlyOnce` (fire-and-forget vs recorrente)
- `TimeoutMinutes`
- `Priority`
- `Queue` (fila do Hangfire)
- `MaxRetries`
- `JobConfiguration` (JSON com configurações específicas)
- `IsSystemJob` (job crítico do sistema)
- `HangfireJobId` (referência ao job no Hangfire)
- `LastRegisteredAt` (última sincronização com Hangfire)
- Estado (`Status`, `IsActive`, `IsDeleted`)
- Auditoria (`CreatedBy`, `CreatedAt`, `UpdatedBy`, `UpdatedAt`)

### 3.1 Regras do campo Code
- O campo **`Code` nunca é informado pelo usuário**.  
- O campo **`Code` é imutável** e **nunca pode ser alterado** após a criação.  
- O `Code` é **gerado automaticamente pela aplicação**, utilizando o componente `CodeGenerator`.
- O formato do código segue obrigatoriamente o padrão:  

```
<PREFIXO><YYMMDD><HASH>
```

Onde:
- **BJOB**: prefixo fixo que identifica o recurso Job.  
- **YYMMDD**: data UTC de geração do código. 
- **HASH**: sequência alfanumérica aleatória de 4 caracteres.

**Exemplo válido:**
```
BJOB251220X7K9
```

- A unicidade do `Code` é garantida pelo sistema através da constraint `UQ_Job_Code`.
- Qualquer tentativa de envio ou alteração manual do campo `Code` deve ser ignorada ou rejeitada pela API.

### 3.2 Escopo Global
- JobDefinitions são entidades **globais da plataforma**.
- Não pertencem a um Tenant específico.
- São gerenciados apenas por administradores da plataforma.  
- Não há aplicação de Row-Level Security (RLS) nesta tabela.

### 3.3 Categorias de Jobs

| Categoria | Descrição | Exemplos |
|-----------|-----------|----------|
| `Cleanup` | Limpeza de dados expirados ou obsoletos | CleanupExpiredSessions, CleanupExpiredOTPs |
| `Maintenance` | Manutenção e otimização do sistema | ArchiveAuditLogs, OptimizeIndexes |
| `Security` | Detecção e resposta a eventos de segurança | DetectAnomalies, RevokeCompromisedTokens |
| `Billing` | Processamento de cobrança e assinaturas | ProcessSubscriptionRenewals, GenerateInvoices |
| `Notification` | Envio de notificações e webhooks | SendPendingWebhooks, SendEmailNotifications |
| `Sync` | Sincronização com sistemas externos | SyncUsersFromAD, SyncWithCRM |
| `Reporting` | Geração de relatórios e métricas | GenerateUsageReports, CalculateMetrics |

---

## 4. Regras de Negócio por Operação

### 4.1 Criar Job (POST /v1/admin/job-definition)
**Contexto:** Apenas administradores da plataforma podem criar jobs. 

**Regras:**
- O job é criado com `IsActive = true` e `IsDeleted = false`.
- O campo `Code` é gerado automaticamente.
- O campo `JobName` deve ser único na plataforma (constraint `UQ_Job_JobName`).
- O campo `JobType` deve conter o namespace e classe completo (ex.:  `VianaID.Infrastructure.Jobs.CleanupExpiredSessionsJob`).
- O campo `JobMethod` tem valor padrão `Execute` se não informado.
- O campo `TimeZoneId` tem valor padrão `GMT Standard Time` (Portugal).
- O campo `Queue` tem valor padrão `default` se não informado.
- O campo `Priority` deve estar entre 1 (mais alta) e 10 (mais baixa) - validado pela constraint `CK_Job_Priority`.
- O campo `TimeoutMinutes` deve ser maior que zero - validado pela constraint `CK_Job_TimeoutMinutes`.
- O campo `MaxRetries` deve ser maior ou igual a zero - validado pela constraint `CK_Job_MaxRetries`.
- Se `ExecuteOnlyOnce = true`, o campo `CronExpression` deve ser NULL (job fire-and-forget).
- Se `ExecuteOnlyOnce = false`, o campo `CronExpression` é obrigatório e deve ser uma expressão Cron válida.  

**Validações:**
- Validar formato da Cron expression (se informada).
- Validar se o `TimeZoneId` existe no sistema operacional (. NET).
- Validar se o `JobType` existe no assembly da aplicação (reflexão).
- Validar se o `JobMethod` existe na classe especificada.
- O `CreatedBy` deve ser o ID do administrador autenticado. 

**Após criação:**
- O job **NÃO** é registrado automaticamente no Hangfire.
- É necessário ativar o job explicitamente ou aguardar o próximo ciclo de sincronização.

---

### 4.2 Consultar Jobs (GET /v1/admin/job-definition)
**Contexto:** Listar todos os jobs cadastrados.  

**Regras:**
- Devem ser retornados apenas jobs não deletados (`IsDeleted = false`).
- Aplicar filtros por:  
  - `JobCategory` (filtro exato ou múltiplos valores)
  - `IsActive` (true/false)
  - `IsSystemJob` (true/false)
  - `Queue` (filtro exato)
  - `JobName` (busca parcial, case-insensitive)
- Ordenação padrão: `JobCategory ASC, Priority ASC, JobName ASC`.
- Suportar paginação obrigatória.

**Projeção de dados:**
- Incluir todos os campos, exceto dados sensíveis (se houver em `JobConfiguration`).
- Incluir indicador se o job está sincronizado com Hangfire (`HangfireJobId IS NOT NULL`).

**Permissões:**
- Apenas administradores da plataforma podem consultar.  

---

### 4.3 Consultar Job por ID (GET /v1/admin/job-definition/{id})
**Regras:**
- Retornar apenas se não estiver deletado.  
- Incluir todos os campos detalhados.
- Incluir metadados do Hangfire (se disponível via API do Hangfire):
  - Última execução
  - Próxima execução
  - Quantidade de execuções
  - Taxa de sucesso/falha

**Permissões:**
- Apenas administradores da plataforma.  

---

### 4.4 Consultar Job por Code (GET /v1/admin/job-definition/code/{code})
**Regras:**
- Buscar job pelo campo `Code` único.
- Retornar 404 se não encontrado ou deletado.
- Mesmas regras de projeção da consulta por ID.

---

### 4.5 Atualizar Job (PUT /v1/admin/job-definition/{id})
**Contexto:** Modificar configurações de um job existente.  

**Regras:**
- O campo `Code` **não pode ser alterado**. 
- O campo `JobName` **não pode ser alterado** (é usado como identificador no Hangfire).
- O campo `IsSystemJob` **não pode ser alterado**. 
- Campos que podem ser alterados: 
  - `Description`
  - `JobPurpose`
  - `CronExpression` (validar formato)
  - `TimeZoneId` (validar existência)
  - `TimeoutMinutes` (validar > 0)
  - `Priority` (validar 1-10)
  - `Queue`
  - `MaxRetries` (validar >= 0)
  - `JobConfiguration`
  - `IsActive`
- Atualizar `UpdatedBy` com ID do administrador autenticado.  
- Atualizar `UpdatedAt` com data/hora atual.

**Validações:**
- Se `CronExpression` for alterada, validar formato. 
- Se `TimeZoneId` for alterado, validar existência no sistema.  
- Não permitir alterar job deletado.  

**Após atualização:**
- Se o job estiver ativo (`IsActive = true`) e registrado no Hangfire:  
  - Re-registrar o job no Hangfire com novas configurações.
  - Atualizar `LastRegisteredAt`.
- Se o job foi desativado (`IsActive = false`):
  - Remover do Hangfire (se registrado).
  - Manter `HangfireJobId` para histórico.

**Auditoria:**
- Registrar alteração em `AuditLogs` com valores antigos e novos.  

---

### 4.6 Ativar Job (PATCH /v1/admin/job-definition/{id}/activate)
**Contexto:** Ativar um job desativado e registrá-lo no Hangfire.  

**Regras:**
- Só é permitido ativar um job existente e não deletado.
- Atualizar `IsActive = true`.
- Atualizar `UpdatedBy` e `UpdatedAt`.

**Ação no Hangfire:**
- Se `ExecuteOnlyOnce = false` (job recorrente):
  - Registrar job recorrente no Hangfire com `RecurringJob.AddOrUpdate`.
  - Atualizar `HangfireJobId` com o `JobName`.
  - Atualizar `LastRegisteredAt`.
- Se `ExecuteOnlyOnce = true` (fire-and-forget):
  - **NÃO** registrar automaticamente.  
  - Aguardar execução manual via endpoint específico.

**Validações:**
- Job deve existir e não estar deletado.
- Job não pode já estar ativo (operação idempotente).

**Auditoria:**
- Registrar ativação em `AuditLogs`.

---

### 4.7 Desativar Job (PATCH /v1/admin/job-definition/{id}/deactivate)
**Contexto:** Desativar um job ativo e removê-lo do Hangfire.  

**Regras:**
- Só é permitido desativar um job ativo.  
- Jobs com `IsSystemJob = true` podem exigir confirmação adicional ou ter restrições. 
- Atualizar `IsActive = false`.
- Atualizar `UpdatedBy` e `UpdatedAt`.

**Ação no Hangfire:**
- Remover job do Hangfire com `RecurringJob.RemoveIfExists(JobName)`.
- Manter `HangfireJobId` para histórico.

**Validações:**
- Job deve existir e estar ativo.
- Se `IsSystemJob = true`, validar permissões especiais ou exigir motivo.

**Auditoria:**
- Registrar desativação em `AuditLogs` com motivo (se fornecido).

---

### 4.8 Executar Job Manualmente (POST /v1/admin/job-definition/{id}/execute)
**Contexto:** Forçar execução imediata de um job (útil para testes e manutenções).

**Regras:**
- Job deve estar ativo (`IsActive = true`).
- Job não pode estar deletado.
- Permitir execução de jobs recorrentes fora do agendamento.  
- Permitir execução de jobs fire-and-forget sob demanda.

**Ação no Hangfire:**
- Enfileirar job com `Job.Enqueue(() => ExecuteJob(jobDef. JobType, jobDef.JobMethod))`.
- Respeitar fila configurada (`Queue`).
- Retornar `JobId` do Hangfire na resposta.

**Resposta:**
```json
{
  "jobId": "hangfire-generated-id",
  "enqueuedAt": "2025-12-20T15:30:00Z",
  "queue": "default",
  "message": "Job enqueued successfully"
}
```

**Validações:**
- Job deve estar ativo.
- Administrador deve ter permissões adequadas.

**Auditoria:**
- Registrar execução manual em `AuditLogs`.

---

### 4.9 Remover Job (DELETE /v1/admin/job-definition/{id}) — Exclusão lógica (soft delete)
**Contexto:** Excluir logicamente um job.  

**Regras:**
- Jobs com `IsSystemJob = true` **NÃO podem ser removidos**. 
- Aplicar soft delete:  
  - `IsDeleted = true`
  - `IsActive = false`
  - `UpdatedBy` = ID do administrador
  - `UpdatedAt` = data/hora atual

**Ação no Hangfire:**
- Remover job do Hangfire se estiver registrado.
- Limpar `HangfireJobId` (opcional, pode manter para auditoria).

**Validações:**
- Job não pode ser do sistema (`IsSystemJob = false`).
- Job deve existir e não estar já deletado.

**Auditoria:**
- Registrar exclusão em `AuditLogs` com motivo (opcional).

---

### 4.10 Sincronizar Jobs com Hangfire (Process)
**Contexto:** Processo automatizado que sincroniza jobs ativos com Hangfire.

**Regras:**
- Executar na inicialização da aplicação.
- Executar periodicamente (ex.: a cada 5 minutos) para detectar dessincronia.  

**Fluxo:**
1. Buscar todos os jobs ativos (`IsActive = true`, `IsDeleted = false`).
2. Para cada job recorrente (`ExecuteOnlyOnce = false`):
   - Verificar se está registrado no Hangfire.
   - Se não estiver, registrar com `RecurringJob.AddOrUpdate`.
   - Atualizar `HangfireJobId` e `LastRegisteredAt`.
3.  Buscar jobs recorrentes no Hangfire que não existem mais no banco.
4. Remover jobs órfãos do Hangfire.  

**Logging:**
- Registrar quantidade de jobs sincronizados.
- Alertar sobre jobs órfãos ou dessincronia.

---

## 5. Regras de Integridade e Dependência

### 5.1 Dependências
- JobDefinitions **não tem** foreign keys para outras tabelas.
- É uma entidade independente de infraestrutura.  

### 5.2 Unicidade
- `Code` deve ser único (constraint `UQ_Job_Code`).
- `JobName` deve ser único (constraint `UQ_Job_JobName`).

### 5.3 Consistência
- A relação entre banco de dados e Hangfire deve ser mantida consistente.
- Jobs deletados devem ser removidos do Hangfire.  
- Jobs desativados devem ser removidos do Hangfire mas mantidos no banco.

---

## 6. Regras de Segurança

### 6.1 Permissões
- **Apenas administradores da plataforma** podem:  
  - Criar jobs.  
  - Atualizar jobs. 
  - Ativar/desativar jobs.
  - Executar jobs manualmente.
  - Remover jobs.  
  - Consultar jobs.  

### 6.2 Jobs do Sistema
- Jobs com `IsSystemJob = true` têm proteções especiais:  
  - Não podem ser removidos. 
  - Desativação pode exigir confirmação ou permissões elevadas.
  - Alterações críticas devem ser auditadas rigorosamente.

### 6.3 Validação de Código
- O campo `JobType` deve ser validado contra assembly da aplicação.
- Não permitir execução de classes/métodos arbitrários (prevenção de code injection).
- Usar lista branca de namespaces permitidos (ex.: `VianaID.Infrastructure.Jobs.*`).

### 6.4 Configurações Sensíveis
- O campo `JobConfiguration` pode conter dados sensíveis (senhas, tokens).
- Implementar criptografia de campos sensíveis se necessário.  
- Não expor configurações sensíveis em logs.  

---

## 7. Regras de Auditoria e Observabilidade

### 7.1 Registro de eventos
**Eventos obrigatórios:**
- Criação de job.  
- Atualização de job (com valores antigos e novos).
- Ativação de job.  
- Desativação de job. 
- Execução manual de job.
- Remoção de job.  
- Sincronização com Hangfire (sumário).

### 7.2 Campos de auditoria
- `CreatedBy`: Quem criou o job.
- `CreatedAt`: Quando foi criado.
- `UpdatedBy`: Quem fez a última alteração.
- `UpdatedAt`: Quando foi alterado.
- `LastRegisteredAt`: Última sincronização com Hangfire.  

### 7.3 Integração com AuditLogs
- Alterações em jobs devem gerar registros em `AuditLogs`.
- Incluir valores antigos e novos para campos alterados.  
- Incluir contexto (IP, user agent) se disponível.

---

## 8. Regras de Governança

### 8.1 Ciclo de vida de jobs
- Jobs devem ser criados em ambiente de desenvolvimento/staging primeiro.
- Promover jobs para produção após validação.  
- Manter versionamento de configurações (opcional, via `JobConfiguration`).

### 8.2 Naming conventions
**JobName:**
- Use PascalCase.  
- Seja descritivo e específico.
- Exemplos: `CleanupExpiredSessions`, `GenerateDailyUsageReport`.

**JobCategory:**
- Use categorias predefinidas. 
- Evite criar categorias ad-hoc. 

### 8.3 Documentação
- Todo job deve ter `Description` e `JobPurpose` preenchidos.
- Documentar parâmetros esperados em `JobConfiguration` (JSON schema).

---

## 9. Integração com Hangfire

### 9.1 Registro de Jobs Recorrentes
```csharp
RecurringJob.AddOrUpdate(
    recurringJobId:  jobDef.JobName,
    methodCall: () => ExecuteJob(jobDef.JobType, jobDef.JobMethod),
    cronExpression: jobDef.CronExpression,
    timeZone: TimeZoneInfo.FindSystemTimeZoneById(jobDef.TimeZoneId),
    queue: jobDef.Queue
);
```

### 9.2 Execução Fire-and-Forget
```csharp
var jobId = Job. Enqueue(
    () => ExecuteJob(jobDef.JobType, jobDef.JobMethod)
);
```

### 9.3 Monitoramento via Dashboard
- O dashboard do Hangfire fornece:  
  - Lista de jobs recorrentes.  
  - Histórico de execuções. 
  - Jobs enfileirados, processando, com sucesso ou falha. 
  - Retry de jobs falhados.  
- Integrar acesso ao dashboard na interface de administração.

### 9.4 Tratamento de Erros
- Hangfire automaticamente faz retry de jobs falhados. 
- Quantidade de retries definida por `MaxRetries` no job.
- Após esgotar retries, job vai para "Failed" no dashboard.  
- Administradores podem re-enfileirar manualmente jobs falhados.

---

## 10. Exemplos de Jobs do Sistema

### 10.1 CleanupExpiredSessions
```json
{
  "code": "BJOB-251220-A001",
  "jobCategory": "Cleanup",
  "jobName": "CleanupExpiredSessions",
  "description": "Remove sessões expiradas e aplica soft delete em sessões antigas",
  "jobPurpose": "Manter a tabela UserSessions limpa e performática",
  "jobType": "VianaID.Infrastructure.Jobs.CleanupExpiredSessionsJob",
  "jobMethod": "Execute",
  "cronExpression":  "0 3 * * *",
  "timeZoneId": "GMT Standard Time",
  "executeOnlyOnce": false,
  "timeoutMinutes": 10,
  "priority": 1,
  "queue": "default",
  "maxRetries": 3,
  "isSystemJob": true,
  "jobConfiguration": "{\"retentionDays\": 90}"
}
```

### 10.2 DetectSecurityAnomalies
```json
{
  "code": "BJOB-251220-A004",
  "jobCategory": "Security",
  "jobName":  "DetectSecurityAnomalies",
  "description": "Analisa eventos de segurança e detecta anomalias",
  "jobPurpose": "Identificar e alertar sobre atividades suspeitas",
  "jobType": "VianaID.Infrastructure.Jobs.SecurityAnomalyDetectionJob",
  "jobMethod": "Execute",
  "cronExpression": "*/15 * * * *",
  "timeZoneId": "GMT Standard Time",
  "executeOnlyOnce": false,
  "timeoutMinutes": 15,
  "priority": 1,
  "queue": "critical",
  "maxRetries":  5,
  "isSystemJob": true,
  "jobConfiguration": "{\"lookbackMinutes\": 60, \"sensitivityLevel\": \"high\"}"
}
```

### 10.3 GenerateMonthlyReport (Fire-and-Forget)
```json
{
  "code":  "BJOB-251220-R001",
  "jobCategory":  "Reporting",
  "jobName": "GenerateMonthlyReport",
  "description": "Gera relatório mensal de uso por tenant",
  "jobPurpose": "Fornecer dados para billing e análise de negócio",
  "jobType":  "VianaID.Infrastructure.Jobs.GenerateMonthlyReportJob",
  "jobMethod": "Execute",
  "cronExpression": null,
  "timeZoneId": "GMT Standard Time",
  "executeOnlyOnce": true,
  "timeoutMinutes": 60,
  "priority": 5,
  "queue": "low",
  "maxRetries":  2,
  "isSystemJob": false,
  "jobConfiguration": "{\"month\": \"2025-12\", \"format\": \"pdf\"}"
}
```

---

## 11. Estrutura de Endpoints da API

### 11.1 Listar Jobs
```
GET /v1/admin/job-definition
Query Parameters:
  - category (string, optional)
  - isActive (boolean, optional)
  - isSystemJob (boolean, optional)
  - queue (string, optional)
  - search (string, optional) - busca em JobName
  - page (int, default:  1)
  - pageSize (int, default: 20)
```

### 11.2 Obter Job por ID
```
GET /v1/admin/job-definition/{id}
```

### 11.3 Obter Job por Code
```
GET /v1/admin/job-definition/code/{code}
```

### 11.4 Criar Job
```
POST /v1/admin/job-definition
Body:  JobCreateDto
```

### 11.5 Atualizar Job
```
PUT /v1/admin/job-definition/{id}
Body: JobUpdateDto
```

### 11.6 Ativar Job
```
PATCH /v1/admin/job-definition/{id}/activate
```

### 11.7 Desativar Job
```
PATCH /v1/admin/job-definition/{id}/deactivate
Body (optional): { "reason": "Manutenção programada" }
```

### 11.8 Executar Job Manualmente
```
POST /v1/admin/job-definition/{id}/execute
Response: { "jobId": "hangfire-id", "enqueuedAt": ".. .", "queue": "..." }
```

### 11.9 Remover Job
```
DELETE /v1/admin/job-definition/{id}
Body (optional): { "reason": "Job obsoleto" }
```

### 11.10 Sincronizar Jobs com Hangfire
```
POST /v1/admin/job-definition/sync
Response: { "synced": 15, "removed": 2, "errors": [] }
```

---

## 12. DTOs (Data Transfer Objects)

### 12.1 JobCreateDto
```csharp
public class JobCreateDto
{
    public string JobCategory { get; set; }          // Required
    public string JobName { get; set; }              // Required, unique
    public string Description { get; set; }          // Optional
    public string JobPurpose { get; set; }           // Optional
    public string JobType { get; set; }              // Required
    public string JobMethod { get; set; }            // Optional, default: "Execute"
    public string CronExpression { get; set; }       // Required if ExecuteOnlyOnce = false
    public string TimeZoneId { get; set; }           // Optional, default: "GMT Standard Time"
    public bool ExecuteOnlyOnce { get; set; }        // Optional, default: false
    public int TimeoutMinutes { get; set; }          // Optional, default: 5
    public int Priority { get; set; }                // Optional, default: 5, range: 1-10
    public string Queue { get; set; }                // Optional, default: "default"
    public int MaxRetries { get; set; }              // Optional, default: 3
    public string JobConfiguration { get; set; }     // Optional, JSON string
    public bool IsSystemJob { get; set; }            // Optional, default:  false
}
```

### 12.2 JobUpdateDto
```csharp
public class JobUpdateDto
{
    public string Description { get; set; }
    public string JobPurpose { get; set; }
    public string CronExpression { get; set; }
    public string TimeZoneId { get; set; }
    public int TimeoutMinutes { get; set; }
    public int Priority { get; set; }
    public string Queue { get; set; }
    public int MaxRetries { get; set; }
    public string JobConfiguration { get; set; }
    public bool IsActive { get; set; }
}
```

### 12.3 JobResponseDto
```csharp
public class JobResponseDto
{
    public Guid Id { get; set; }
    public string Code { get; set; }
    public string JobCategory { get; set; }
    public string JobName { get; set; }
    public string Description { get; set; }
    public string JobPurpose { get; set; }
    public string JobType { get; set; }
    public string JobMethod { get; set; }
    public string CronExpression { get; set; }
    public string TimeZoneId { get; set; }
    public bool ExecuteOnlyOnce { get; set; }
    public int TimeoutMinutes { get; set; }
    public int Priority { get; set; }
    public string Queue { get; set; }
    public int MaxRetries { get; set; }
    public string JobConfiguration { get; set; }
    public bool IsSystemJob { get; set; }
    public string HangfireJobId { get; set; }
    public DateTime?  LastRegisteredAt { get; set; }
    public int Status { get; set; }
    public bool IsActive { get; set; }
    public bool IsDeleted { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime?  UpdatedAt { get; set; }
    
    // Metadados do Hangfire (se disponível)
    public DateTime? NextExecution { get; set; }
    public DateTime? LastExecution { get; set; }
    public string LastExecutionStatus { get; set; }
}
```

---

## 13. Validações

### 13.1 Validações de Criação
- `JobCategory`: Obrigatório, deve estar em lista de categorias válidas.
- `JobName`: Obrigatório, único, máximo 150 caracteres.
- `JobType`: Obrigatório, deve ser namespace válido, máximo 200 caracteres.
- `JobMethod`: Opcional, default "Execute", máximo 100 caracteres.
- `CronExpression`: Obrigatório se `ExecuteOnlyOnce = false`, validar formato Cron.
- `TimeZoneId`: Opcional, validar existência no sistema, default "GMT Standard Time".
- `TimeoutMinutes`: Maior que zero (constraint do banco). 
- `Priority`: Entre 1 e 10 (constraint do banco).
- `MaxRetries`: Maior ou igual a zero (constraint do banco).
- `JobConfiguration`: Opcional, validar se é JSON válido.  

### 13.2 Validações de Atualização
- Não permitir alterar `Code`, `JobName`, `IsSystemJob`.
- Aplicar mesmas validações de formato dos campos alteráveis.

### 13.3 Validações de Ativação
- Job deve existir e não estar deletado.
- Se `ExecuteOnlyOnce = false`, `CronExpression` deve estar preenchida.

### 13.4 Validações de Remoção
- Não permitir remover jobs com `IsSystemJob = true`.

---

## 14. Testes e Validação

### 14.1 Casos de teste obrigatórios
**Criação:**
- Criar job recorrente válido.
- Criar job fire-and-forget válido.  
- Rejeitar criação com JobName duplicado.  
- Rejeitar criação com CronExpression inválida.  
- Rejeitar criação com Priority fora do range. 

**Atualização:**
- Atualizar campos permitidos.
- Rejeitar alteração de Code.
- Rejeitar alteração de JobName.
- Rejeitar alteração de IsSystemJob.  

**Ativação/Desativação:**
- Ativar job e verificar registro no Hangfire.
- Desativar job e verificar remoção do Hangfire.  
- Ativar job já ativo (idempotente).

**Execução Manual:**
- Executar job recorrente manualmente.
- Executar job fire-and-forget manualmente.
- Rejeitar execução de job inativo.

**Remoção:**
- Remover job não-sistema.
- Rejeitar remoção de job sistema.

**Sincronização:**
- Sincronizar jobs ativos com Hangfire na inicialização.
- Detectar e remover jobs órfãos do Hangfire.

---

## 15. Considerações de Performance

### 15.1 Indexação
**Índices obrigatórios (já criados no script):**
- `IX_Services_Category_Active` - `(JobCategory, IsActive, IsDeleted)` - Consultas filtradas por categoria.  
- `IX_Services_Active_System` - `(IsActive, IsSystemJob) WHERE IsDeleted = 0` - Consultas de jobs ativos.
- `IX_Services_HangfireJobId` - `(HangfireJobId) WHERE HangfireJobId IS NOT NULL` - Lookup por ID do Hangfire.

### 15.2 Caching
- Cachear lista de jobs ativos em memória.
- Invalidar cache ao criar/atualizar/ativar/desativar jobs.  
- TTL do cache:  5 minutos.  

### 15.3 Otimização de Consultas
- Sempre aplicar filtro `IsDeleted = 0` nas consultas.
- Usar paginação em listas.  
- Evitar consultas complexas no Hangfire durante sincronização.

---

## 16. Exemplo de Fluxo Completo

### 16.1 Criar e Ativar Job
```
1. POST /v1/admin/job-definition
   Body: { "jobName": "CleanupOldLogs", "jobCategory": "Cleanup", ...  }
   Response: { "id": ".. .", "code": "BJOB-251220-X7K9", ... }

2. PATCH /v1/admin/job-definition/{id}/activate
   Response: { "message": "Job activated and registered in Hangfire" }
```

### 16.2 Executar Manualmente
```
POST /v1/admin/job-definition/{id}/execute
Response: { "jobId": "hangfire-123", "enqueuedAt": "2025-12-20T16:00:00Z" }
```

### 16.3 Monitorar no Dashboard Hangfire
```
- Acessar /hangfire
- Verificar job "CleanupOldLogs" em "Recurring Jobs"
- Ver histórico de execuções
```

### 16.4 Desativar Job
```
PATCH /v1/admin/job-definition/{id}/deactivate
Body: { "reason": "Job temporariamente desnecessário" }
Response: { "message": "Job deactivated and removed from Hangfire" }
```

---

## 17. Conclusão
O módulo **JobDefinitions** é essencial para automação e manutenção da plataforma IAM VianaID. 

As regras aqui definidas garantem:
- **Governança centralizada:** Configurações em banco de dados, não hard-coded.
- **Flexibilidade:** Ativar/desativar/configurar jobs sem deploy.
- **Auditoria completa:** Rastreamento de todas as alterações.
- **Integração robusta com Hangfire:** Sincronização automática e monitoramento.  
- **Segurança:** Proteção de jobs críticos do sistema.  
- **Observabilidade:** Dashboard do Hangfire + logs de auditoria.  
- **Escalabilidade:** Filas, prioridades e retry automático. 

Com esta estrutura detalhada, o sistema garante gestão profissional de job, atendendo requisitos de confiabilidade, manutenibilidade e observabilidade de sistemas empresariais modernos.  🚀