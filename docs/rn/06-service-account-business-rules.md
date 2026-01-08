# Documento de Regras de Negócio — ServiceAccounts

## 1. Introdução
Este documento descreve de forma detalhada as regras de negócio do módulo **ServiceAccounts** no sistema IAM (VianaID).

Um **ServiceAccount** representa uma conta de serviço (máquina/robô) pertencente a um Tenant, utilizada para integrações, automações e comunicações máquina-a-máquina (M2M). Diferente de UserAccounts (usuários humanos), ServiceAccounts são identidades não-humanas que operam de forma automatizada, geralmente através de autenticação baseada em credenciais (Client ID/Secret) ou certificados. 

ServiceAccounts são fundamentais para:
- Integrações entre sistemas
- Automações e jobs agendados
- APIs e microserviços
- Processos batch
- Comunicação inter-aplicações

---

## 2. Objetivos do Módulo de ServiceAccounts
- Gerenciar identidades não-humanas (máquinas/serviços) por Tenant
- Permitir autenticação segura para integrações e automações
- Suportar controle de acesso baseado em ApplicationRoles (RBAC)
- Facilitar auditoria de ações automatizadas
- Garantir isolamento multi-tenant de contas de serviço
- Permitir gestão independente de credenciais
- Suportar rotação de segredos (secrets rotation)
- Facilitar monitoramento de uso e últimos acessos

---

## 3. Estrutura Geral do ServiceAccount
Um **ServiceAccount** contém:
- `Id`
- `TenantId` (FK para Tenants)
- `ClientId` (identificador único OAuth2/OIDC)
- `Code` (código técnico gerado automaticamente pelo sistema)
- `Name` (nome descritivo)
- `ClientSecretHash` (hash do segredo, nunca texto puro)
- `Description` (descrição da finalidade)
- Rastreamento de uso (`LastAccessAt`)
- Estado (`Status`, `IsActive`, `IsDeleted`)
- Auditoria (`CreatedBy`, `CreatedAt`, `UpdatedBy`, `UpdatedAt`)

### 3.1 Escopo Multi-tenant
- Todo ServiceAccount pertence exatamente a um Tenant específico
- ServiceAccounts são isolados por Tenant através de Row-Level Security (RLS)
- Um Tenant não pode acessar ServiceAccounts de outros Tenants
- Consultas e operações devem sempre respeitar o contexto do Tenant autenticado

### 3.2 Identificação e Autenticação
**ClientId:**
- Identificador único global do ServiceAccount
- Usado como "username" na autenticação OAuth2 Client Credentials
- Deve ser único em todo o sistema (não apenas no Tenant)
- Geralmente formato UUID/GUID

**ClientSecret:**
- Segredo usado como "password" na autenticação
- **Nunca armazenado em texto puro**, apenas hash criptográfico
- Deve ser fornecido ao cliente apenas no momento da criação
- Suporta rotação periódica para segurança
- Algoritmo de hash:  bcrypt, Argon2 ou similar

**Padrão de autenticação:**
```http
POST /oauth2/token
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials
&client_id={ClientId}
&client_secret={ClientSecret}
&scope={requested_scopes}
```

### 3.3 Diferenças entre ServiceAccount e UserAccount
| Característica | UserAccount | ServiceAccount |
|----------------|-------------|----------------|
| **Tipo de identidade** | Humana | Máquina/Serviço |
| **Autenticação** | Email + Password, MFA, Social Login | Client ID + Secret |
| **Email** | Obrigatório | Não possui |
| **MFA** | Suportado | Não aplicável |
| **Login interativo** | Sim | Não |
| **Sessões** | Sim (UserSessions) | Não (apenas tokens) |
| **Password reset** | Sim | Secret rotation |
| **Lockout** | Sim (tentativas falhas) | Não (rate limiting via API) |
| **Finalidade** | Usuários finais | Integrações/Automações |

### 3.4 Relacionamento com outros módulos
- ServiceAccounts recebem ApplicationRoles através de UserApplicationRoles
- ServiceAccounts podem ter ApiKeys para autenticação alternativa
- ServiceAccounts geram SecurityEvents para auditoria de segurança
- ServiceAccounts são vinculados a AuthorizationGrants (OAuth2)
- ServiceAccounts respeitam limites do Plan do Tenant (MaxServiceAccounts)

---

## 4. Regras de Negócio por Operação

### 4.1 Criar ServiceAccount (POST /v1/tenants/{tenantId}/service-accounts)
**Contexto:** Criar uma nova conta de serviço para integrações/automações do Tenant. 

**Payload de entrada:**
```json
{
  "name": "Integration API Service",
  "description": "Service account for ERP integration",
  "code": "ERP-INTEGRATION-001"
}
```

**Regras:**
- O ServiceAccount é criado com `IsActive = true` e `IsDeleted = false`
- O campo `TenantId` deve corresponder ao Tenant do contexto da requisição
- O `ClientId` deve ser gerado automaticamente como UUID único global
- O `ClientSecret` deve ser gerado automaticamente (string aleatória segura, 32+ caracteres)
- O `ClientSecretHash` deve armazenar o hash bcrypt/Argon2 do ClientSecret
- O `Code` deve ser único dentro do Tenant (gerado automaticamente se não fornecido)
- O `Name` deve ser descritivo da finalidade do ServiceAccount
- O `CreatedBy` deve ser preenchido com o ID do usuário autenticado
- O `Status` deve ser inicializado com valor padrão (1 - Ativo)
- O `LastAccessAt` deve ser NULL inicialmente

**Formato do Code (se gerado automaticamente):**
```
SVC-YYMMDD-HASH
Exemplo: SVC-251223-X7K9
```

**Validações:**
- O Tenant deve existir, estar ativo e não deletado
- O `Name` é obrigatório e deve ter entre 3 e 200 caracteres
- O `Code` deve ser único dentro do Tenant
- O `ClientId` deve ser único globalmente
- Verificar limite do plano:  `MaxServiceAccounts` do Plan do Tenant
- O usuário deve ter permissão para criar ServiceAccounts no Tenant
- Validar caracteres permitidos em `Code` (alfanuméricos, hífens, underscores)

**Resposta:**
```json
{
  "id": "guid",
  "tenantId": "guid",
  "clientId": "guid",
  "clientSecret": "plain-text-secret-only-shown-once",
  "code":  "SVC-251223-X7K9",
  "name": "Integration API Service",
  "description": "Service account for ERP integration",
  "lastAccessAt": null,
  "status": 1,
  "isActive": true,
  "isDeleted": false,
  "createdAt": "2025-12-23T10:00:00Z",
  "createdBy": "user-guid"
}
```

**⚠️ IMPORTANTE:**
- O `ClientSecret` em texto puro é retornado **APENAS na criação**
- Cliente deve armazenar o secret de forma segura (vault, secrets manager, etc.)
- Após a resposta inicial, o secret nunca mais pode ser recuperado
- Se perder o secret, única opção é rotação (gerar novo secret)

**Pós-criação:**
- Registrar evento de auditoria da criação
- Incrementar contador de ServiceAccounts do Tenant (UsageMetrics)
- Disparar webhook se configurado (service_account. created)
- Gerar SecurityEvent de criação de identidade privilegiada

---

### 4.2 Consultar ServiceAccounts (GET /v1/tenants/{tenantId}/service-accounts)
**Contexto:** Listar todos os ServiceAccounts do Tenant com filtros e paginação.

**Regras:**
- Devem ser retornados apenas ServiceAccounts não deletados (`IsDeleted = false`)
- Aplicar isolamento por Tenant através de RLS ou filtro explícito
- Aplicar filtros opcionais por: 
  - `IsActive` (ativos ou inativos)
  - `Name` (busca parcial, case-insensitive)
  - `Code` (busca exata ou parcial)
  - `LastAccessAt` (range de datas, ex: sem acesso há X dias)
- Ordenação padrão: `Name ASC, CreatedAt DESC`
- Suportar paginação obrigatória (page, pageSize)
- Limite padrão: 50 registros por página
- Limite máximo: 100 registros por página

**Projeção de dados:**
- Incluir todos os campos do ServiceAccount **EXCETO** `ClientSecretHash`
- **NUNCA retornar** `ClientSecretHash` em nenhuma consulta
- Incluir informações de auditoria (criação, última modificação)
- Incluir contagem de ApplicationRoles atribuídos
- Incluir informações de último acesso
- Calcular status de segurança (ex: "sem acesso há 90+ dias")

**Resposta:**
```json
{
  "totalCount": 15,
  "page": 1,
  "pageSize": 50,
  "data": [
    {
      "id": "guid",
      "tenantId": "guid",
      "clientId": "guid",
      "code": "SVC-251223-X7K9",
      "name": "Integration API Service",
      "description": "Service account for ERP integration",
      "lastAccessAt": "2025-12-20T15:30:00Z",
      "rolesCount": 2,
      "status": 1,
      "isActive": true,
      "isDeleted": false,
      "createdAt": "2025-12-23T10:00:00Z",
      "updatedAt": null
    }
  ]
}
```

**Permissões:**
- Apenas usuários com permissão de leitura de ServiceAccounts podem consultar
- Aplicar RLS automaticamente baseado no TenantId do contexto

---

### 4.3 Consultar ServiceAccount por ID (GET /v1/tenants/{tenantId}/service-accounts/{id})
**Contexto:** Obter detalhes completos de um ServiceAccount específico. 

**Regras:**
- Retornar apenas se o ServiceAccount pertencer ao Tenant especificado
- Não retornar ServiceAccounts deletados
- Incluir informações detalhadas de ApplicationRoles atribuídos
- Incluir histórico de acessos recentes (últimos 10 acessos)
- Incluir metadados de auditoria completos
- **NUNCA retornar** `ClientSecretHash`

**Validações:**
- O ServiceAccount deve existir e pertencer ao Tenant do contexto
- O ServiceAccount não pode estar deletado
- Aplicar RLS baseado no TenantId

**Projeção de dados:**
```json
{
  "id":  "guid",
  "tenantId": "guid",
  "clientId": "guid",
  "code": "SVC-251223-X7K9",
  "name": "Integration API Service",
  "description": "Service account for ERP integration",
  "lastAccessAt": "2025-12-20T15:30:00Z",
  "status": 1,
  "isActive": true,
  "isDeleted": false,
  "createdAt": "2025-12-23T10:00:00Z",
  "createdBy": "user-guid",
  "createdByUserName": "Admin User",
  "updatedAt":  "2025-12-23T12:00:00Z",
  "updatedBy": "user-guid",
  "updatedByUserName": "Admin User",
  "applicationRoles": [
    {
      "id": "guid",
      "applicationId": "guid",
      "applicationName": "ERP System",
      "roleName": "API Consumer",
      "assignedAt": "2025-12-23T11:00:00Z"
    }
  ],
  "recentAccess": [
    {
      "accessedAt": "2025-12-20T15:30:00Z",
      "ipAddress": "203.0.113.42",
      "endpoint": "/api/v1/orders"
    }
  ]
}
```

---

### 4.4 Atualizar ServiceAccount (PUT /v1/tenants/{tenantId}/service-accounts/{id})
**Contexto:** Atualizar informações descritivas de um ServiceAccount. 

**Payload de entrada:**
```json
{
  "name": "Updated Integration Service",
  "description": "Updated description"
}
```

**Regras:**
- Apenas campos `Name` e `Description` podem ser atualizados
- **Campos imutáveis:**
  - `ClientId` (imutável - identificador único)
  - `ClientSecretHash` (apenas via rotação de secret)
  - `TenantId` (imutável - isolamento multi-tenant)
  - `Code` (imutável após criação)
- Validar que o ServiceAccount pertence ao Tenant do contexto
- Atualizar `UpdatedBy` e `UpdatedAt`
- Validar que o ServiceAccount não está deletado

**Validações:**
- O ServiceAccount deve existir e pertencer ao Tenant
- O ServiceAccount não pode estar deletado
- `Name` deve ter entre 3 e 200 caracteres (se fornecido)
- `Description` pode ser NULL ou ter até 500 caracteres
- O usuário deve ter permissão para editar ServiceAccounts no Tenant

**Auditoria:**
- Registrar alteração em `AuditLogs` com valores antigos e novos
- Incluir contexto do usuário que modificou

---

### 4.5 Rotacionar Secret do ServiceAccount (POST /v1/tenants/{tenantId}/service-accounts/{id}/rotate-secret)
**Contexto:** Gerar novo ClientSecret para o ServiceAccount (rotação de credenciais).

**Regras:**
- Gerar novo `ClientSecret` aleatório seguro (32+ caracteres)
- Atualizar `ClientSecretHash` com hash do novo secret
- Manter `ClientId` inalterado (apenas secret é rotacionado)
- Atualizar `UpdatedBy` e `UpdatedAt`
- Invalidar todas as sessões/tokens ativos do ServiceAccount (opcional configurável)

**Validações:**
- O ServiceAccount deve existir e pertencer ao Tenant
- O ServiceAccount deve estar ativo (`IsActive = true`)
- O ServiceAccount não pode estar deletado
- O usuário deve ter permissão para gerenciar ServiceAccounts no Tenant
- Pode exigir autenticação adicional (MFA) dependendo da política de segurança

**Resposta:**
```json
{
  "clientId": "guid",
  "clientSecret": "new-plain-text-secret-only-shown-once",
  "rotatedAt": "2025-12-23T14:00:00Z",
  "rotatedBy": "user-guid"
}
```

**⚠️ IMPORTANTE:**
- O novo `ClientSecret` em texto puro é retornado **APENAS nesta operação**
- Cliente deve atualizar imediatamente suas configurações com o novo secret
- Secret antigo é invalidado imediatamente
- Considerar período de transição (manter ambos válidos por curto período)

**Auditoria:**
- Registrar rotação em `AuditLogs` e `SecurityEvents`
- Incluir motivo da rotação (se fornecido)
- Gerar alerta de segurança crítica
- Notificar administradores sobre rotação

**Motivos para rotação:**
- Rotação periódica (política de segurança)
- Suspeita de comprometimento
- Conformidade regulatória
- Offboarding de membro da equipe que tinha acesso
- Vazamento acidental em logs/código

---

### 4.6 Ativar ServiceAccount (PATCH /v1/tenants/{tenantId}/service-accounts/{id}/activate)
**Contexto:** Reativar um ServiceAccount previamente desativado.

**Regras:**
- Só é permitido ativar um ServiceAccount existente, não deletado e pertencente ao Tenant
- **O ServiceAccount deve estar inativo** (`IsActive = false`) para ser ativado
- Atualizar `IsActive = true`
- Atualizar `UpdatedBy` e `UpdatedAt`

**Validações:**
- O ServiceAccount deve existir e pertencer ao Tenant
- O ServiceAccount não pode estar deletado
- **O ServiceAccount não pode estar já ativo** - retorna erro 400 se tentar ativar um ServiceAccount que já está ativo
- A operação **não é idempotente** - valida o estado atual e retorna erro se já estiver no estado desejado

**Motivo da validação explícita:**
- Evita chamadas desnecessárias ao banco de dados quando o ServiceAccount já está ativo
- Detecta bugs no cliente que fazem chamadas duplicadas
- Melhora a performance ao fazer "early return" sem validar dependências desnecessariamente
- Fornece feedback explícito sobre tentativas de operação inválidas

**Auditoria:**
- Registrar ativação em `AuditLogs`
- Incluir contexto do usuário que ativou
- Gerar SecurityEvent de reativação de identidade

**Impacto:**
- ServiceAccount pode autenticar novamente
- ApplicationRoles atribuídos voltam a conceder Permissions
- Integrações podem voltar a funcionar

---

### 4.7 Desativar ServiceAccount (PATCH /v1/tenants/{tenantId}/service-accounts/{id}/deactivate)
**Contexto:** Desativar um ServiceAccount temporariamente.

**Regras:**
- Só é permitido desativar um ServiceAccount ativo, não deletado e pertencente ao Tenant
- **O ServiceAccount deve estar ativo** (`IsActive = true`) para ser desativado
- Atualizar `IsActive = false`
- Atualizar `UpdatedBy` e `UpdatedAt`
- Invalidar todas as sessões/tokens ativos do ServiceAccount

**Validações:**
- O ServiceAccount deve existir, pertencer ao Tenant e estar ativo
- **O ServiceAccount não pode estar já inativo** - retorna erro 400 se tentar desativar um ServiceAccount que já está inativo
- A operação **não é idempotente** - valida o estado atual e retorna erro se já estiver no estado desejado

**Motivo da validação explícita:**
- Evita chamadas desnecessárias ao banco de dados
- Detecta bugs no cliente que fazem chamadas duplicadas
- Melhora a performance ao fazer "early return" sem processar operação desnecessária
- Fornece feedback explícito sobre tentativas de operação inválidas

**Impacto:**
- ServiceAccount não pode mais autenticar
- Todas as integrações usando este ServiceAccount falham
- Tokens existentes são invalidados
- ApplicationRoles continuam atribuídos mas sem efeito

**Auditoria:**
- Registrar desativação em `AuditLogs` com motivo (se fornecido)
- Gerar SecurityEvent de desativação de identidade
- Notificar administradores sobre desativação

**Motivos para desativação:**
- Integração temporariamente suspensa
- Investigação de segurança
- Manutenção/atualização do sistema integrado
- Suspeita de comprometimento

---

### 4.8 Remover ServiceAccount (DELETE /v1/tenants/{tenantId}/service-accounts/{id})
**Contexto:** Excluir logicamente um ServiceAccount (soft delete).

**Regras:**
- Aplicar soft delete: 
  - `IsDeleted = true`
  - `IsActive = false`
  - `UpdatedBy` = ID do usuário autenticado
  - `UpdatedAt` = data/hora atual
- Invalidar todas as sessões/tokens ativos
- Desativar todos os UserApplicationRoles associados

**Validações:**
- O ServiceAccount deve existir e pertencer ao Tenant
- O ServiceAccount não pode estar já deletado
- Verificar se não há dependências críticas ativas
- Pode exigir autenticação adicional (MFA) dependendo da política

**Impacto:**
- ServiceAccount não pode mais autenticar
- Todas as integrações usando este ServiceAccount falham permanentemente
- UserApplicationRoles são desativados
- Registro mantido para auditoria histórica
- Não pode ser reativado (necessário criar novo ServiceAccount)

**Considerações:**
- Avaliar impacto em integrações ativas antes de deletar
- Notificar equipes responsáveis pelas integrações
- Documentar motivo da remoção
- Considerar período de desativação antes da remoção permanente

**Auditoria:**
- Registrar exclusão em `AuditLogs` com motivo obrigatório
- Gerar SecurityEvent de remoção de identidade
- Incluir informações detalhadas dos ApplicationRoles removidos
- Notificar administradores sobre remoção

---

### 4.9 Verificar Disponibilidade de ClientId (GET /v1/tenants/{tenantId}/service-accounts/check-clientid/{clientId})
**Contexto:** Verificar se um ClientId já está em uso (útil para UIs).

**Regras:**
- Verificar se existe ServiceAccount com o ClientId fornecido
- Considerar apenas ServiceAccounts não deletados
- Verificação global (não apenas no Tenant, pois ClientId é único globalmente)

**Resposta:**
```json
{
  "clientId": "guid",
  "isAvailable": false,
  "message": "ClientId is already in use"
}
```

**Nota:**
- Geralmente ClientId é gerado automaticamente, esta operação é auxiliar

---

### 4.10 Listar Últimos Acessos do ServiceAccount (GET /v1/tenants/{tenantId}/service-accounts/{id}/access-history)
**Contexto:** Obter histórico de acessos/autenticações de um ServiceAccount.

**Regras:**
- Buscar registros de AuthorizationGrants associados ao ServiceAccount
- Buscar registros de AuditLogs de autenticações
- Buscar registros de SecurityEvents relacionados
- Ordenar por data decrescente (mais recente primeiro)
- Suportar paginação
- Filtrar por range de datas (opcional)

**Projeção de dados:**
```json
{
  "serviceAccountId": "guid",
  "totalAccesses": 150,
  "lastAccessAt": "2025-12-20T15:30:00Z",
  "accessHistory": [
    {
      "accessedAt": "2025-12-20T15:30:00Z",
      "ipAddress": "203.0.113.42",
      "userAgent": "ServiceClient/1.0",
      "endpoint": "/oauth2/token",
      "grantType": "client_credentials",
      "scopes": ["read: orders", "write:orders"],
      "success": true
    }
  ]
}
```

**Permissões:**
- Apenas usuários com permissão de auditoria podem consultar

---

## 5. Regras de Integridade e Dependência

### 5.1 Dependências obrigatórias
- Todo ServiceAccount deve referenciar um `TenantId` válido e ativo
- `ClientId` deve ser único globalmente (não apenas no Tenant)
- `Code` deve ser único dentro do Tenant
- `ClientSecretHash` deve sempre conter hash válido (nunca NULL)

### 5.2 Integridade referencial
- ServiceAccounts são referenciados por: 
  - UserApplicationRoles (atribuição de ApplicationRoles)
  - AuthorizationGrants (tokens OAuth2)
  - AuditLogs (auditoria de ações)
  - SecurityEvents (eventos de segurança)
- Não permitir exclusão física de ServiceAccounts com histórico
- Soft delete mantém integridade referencial

### 5.3 Cascata de operações
**Desativação de ServiceAccount:**
- Invalidar todos os tokens ativos (AuthorizationGrants)
- Desativar todos os UserApplicationRoles associados
- Gerar SecurityEvent de desativação
- Notificar sistemas integrados (webhook)

**Desativação de Tenant:**
- Desativar automaticamente todos os ServiceAccounts do Tenant
- Não permitir criação de novos ServiceAccounts

**Remoção de ServiceAccount:**
- Aplicar soft delete no ServiceAccount
- Desativar todos os UserApplicationRoles associados
- Invalidar todos os tokens ativos
- Manter histórico de auditoria

### 5.4 Consistência de dados
- ServiceAccounts ativos devem sempre ter Tenant ativo
- ClientId deve ser único e válido
- ClientSecretHash nunca deve ser NULL ou vazio
- LastAccessAt deve ser atualizado a cada autenticação bem-sucedida
- Manter consistência temporal entre criação/atualização

---

## 6. Regras de Segurança

### 6.1 Isolamento multi-tenant
- Implementar Row-Level Security (RLS) baseado em TenantId
- Todas as consultas devem automaticamente filtrar pelo Tenant do contexto
- Validar TenantId em todas as operações para prevenir vazamento de dados
- ClientId é único globalmente, mas acesso é restrito ao Tenant proprietário

### 6.2 Gestão de Credenciais
**Armazenamento seguro:**
- **NUNCA armazenar ClientSecret em texto puro**
- Usar algoritmos de hash seguros:  bcrypt (custo 12+), Argon2id
- ClientSecretHash deve ser armazenado no campo `ClientSecretHash`
- ClientSecret em texto puro só é visível na criação e rotação

**Geração de secrets:**
- Mínimo 32 caracteres
- Caracteres aleatórios criptograficamente seguros
- Incluir letras maiúsculas, minúsculas, números e símbolos
- Usar biblioteca confiável (ex: `RandomNumberGenerator` do . NET)

**Rotação de secrets:**
- Implementar rotação periódica (ex: a cada 90 dias)
- Alertar administradores quando secret está próximo de expirar
- Permitir rotação manual a qualquer momento
- Invalidar secret antigo imediatamente

### 6.3 Controle de acesso
**Permissões necessárias:**
- **Criar ServiceAccount:** Permissão de gerenciamento de ServiceAccounts no Tenant
- **Consultar ServiceAccounts:** Permissão de leitura de ServiceAccounts no Tenant
- **Atualizar ServiceAccount:** Permissão de gerenciamento de ServiceAccounts no Tenant
- **Rotacionar Secret:** Permissão de gerenciamento de ServiceAccounts + possível MFA
- **Ativar/Desativar:** Permissão de gerenciamento de ServiceAccounts no Tenant
- **Remover ServiceAccount:** Permissão de gerenciamento de ServiceAccounts + possível MFA

### 6.4 Auditoria de segurança
- Registrar todas as operações críticas (criação, rotação, desativação, remoção)
- Incluir contexto completo do usuário (IP, User Agent, etc.)
- Monitorar tentativas de autenticação falhas
- Log especial para rotações de secret
- Alertas para uso anormal (múltiplas autenticações de IPs diferentes, etc.)

### 6.5 Proteções adicionais
**Rate Limiting:**
- Limitar tentativas de autenticação por ClientId (ex: 10 por minuto)
- Bloquear temporariamente após múltiplas falhas consecutivas
- Implementar backoff exponencial

**Monitoramento de anomalias:**
- Detectar autenticações de IPs/regiões incomuns
- Alertar sobre mudanças súbitas de padrão de uso
- Monitorar uso de permissões de alto risco

**Restrições de acesso:**
- Permitir lista branca de IPs (AllowedIps) - funcionalidade futura
- Restringir horários de acesso (funcionalidade futura)
- Limitar scopes disponíveis por ServiceAccount

### 6.6 Validação de entrada
- Sanitizar campos de entrada
- Validar GUIDs de referência
- Verificar existência de entidades referenciadas
- Prevenir SQL injection e XSS
- Validar comprimento e formato de campos

---

## 7. Regras de Governança

### 7.1 Gestão de ServiceAccounts
- Revisar periodicamente ServiceAccounts para detectar contas obsoletas
- Implementar processo de aprovação para criação de ServiceAccounts
- Documentar finalidade de cada ServiceAccount
- Manter princípio do menor privilégio necessário
- Implementar recertificação periódica

### 7.2 Lifecycle management
- Definir ciclo de vida claro para ServiceAccounts
- Processos para revisão periódica de uso
- Remoção automática de ServiceAccounts sem acesso há X dias
- Comunicação prévia de mudanças impactantes
- Workflow de criação/desativação

### 7.3 Rotação de Secrets
- Política de rotação periódica obrigatória (ex: 90 dias)
- Alertas antes da expiração recomendada
- Processo documentado para rotação
- Período de transição quando necessário
- Auditoria completa de rotações

### 7.4 Monitoramento de Uso
- Rastrear último acesso de cada ServiceAccount
- Identificar ServiceAccounts inativos (sem uso há X dias)
- Monitorar padrões de uso anormais
- Gerar relatórios de uso para administradores
- Alertar sobre ServiceAccounts sem uso há muito tempo

### 7.5 Documentação
- Manter documentação atualizada de cada ServiceAccount: 
  - Finalidade/objetivo
  - Sistema/integração que utiliza
  - Responsável técnico
  - ApplicationRoles atribuídos
  - Data de criação e última rotação de secret
- Incluir informações sobre riscos e controles
- Manter matriz de integrações atualizada

---

## 8. Estrutura da API

### 8.1 Endpoints
```
POST   /v1/tenants/{tenantId}/service-accounts
GET    /v1/tenants/{tenantId}/service-accounts
GET    /v1/tenants/{tenantId}/service-accounts/{id}
PUT    /v1/tenants/{tenantId}/service-accounts/{id}
DELETE /v1/tenants/{tenantId}/service-accounts/{id}

PATCH  /v1/tenants/{tenantId}/service-accounts/{id}/activate
PATCH  /v1/tenants/{tenantId}/service-accounts/{id}/deactivate
POST   /v1/tenants/{tenantId}/service-accounts/{id}/rotate-secret

GET    /v1/tenants/{tenantId}/service-accounts/check-clientid/{clientId}
GET    /v1/tenants/{tenantId}/service-accounts/{id}/access-history
```

### 8.2 DTOs

#### ServiceAccountCreateDto
```csharp
public class ServiceAccountCreateDto
{
    [Required]
    [StringLength(200, MinimumLength = 3)]
    public string Name { get; set; }
    
    [StringLength(500)]
    public string Description { get; set; }
    
    [StringLength(100)]
    [RegularExpression(@"^[a-zA-Z0-9-_]+$")]
    public string Code { get; set; }  // Optional, auto-generated if not provided
}
```

#### ServiceAccountResponseDto
```csharp
public class ServiceAccountResponseDto
{
    public Guid Id { get; set; }
    public Guid TenantId { get; set; }
    public Guid ClientId { get; set; }
    public string Code { get; set; }
    public string Name { get; set; }
    public string Description { get; set; }
    public DateTime?  LastAccessAt { get; set; }
    public int Status { get; set; }
    public bool IsActive { get; set; }
    public bool IsDeleted { get; set; }
    public DateTime CreatedAt { get; set; }
    public Guid CreatedBy { get; set; }
    public string CreatedByUserName { get; set; }
    public DateTime? UpdatedAt { get; set; }
    public Guid?  UpdatedBy { get; set; }
    public string UpdatedByUserName { get; set; }
    
    // Estatísticas
    public int ApplicationRolesCount { get; set; }
    public int DaysSinceLastAccess { get; set; }
}
```

#### ServiceAccountCreateResponseDto
```csharp
public class ServiceAccountCreateResponseDto :  ServiceAccountResponseDto
{
    // WARNING: ClientSecret is only returned on creation
    // Store it securely - it cannot be retrieved later
    public string ClientSecret { get; set; }
}
```

#### ServiceAccountUpdateDto
```csharp
public class ServiceAccountUpdateDto
{
    [Required]
    [StringLength(200, MinimumLength = 3)]
    public string Name { get; set; }
    
    [StringLength(500)]
    public string Description { get; set; }
}
```

#### ServiceAccountRotateSecretResponseDto
```csharp
public class ServiceAccountRotateSecretResponseDto
{
    public Guid ClientId { get; set; }
    
    // WARNING: New ClientSecret is only returned once
    // Store it securely - it cannot be retrieved later
    public string ClientSecret { get; set; }
    
    public DateTime RotatedAt { get; set; }
    public Guid RotatedBy { get; set; }
    public string RotatedByUserName { get; set; }
}
```

#### ServiceAccountAccessHistoryDto
```csharp
public class ServiceAccountAccessHistoryDto
{
    public Guid ServiceAccountId { get; set; }
    public int TotalAccesses { get; set; }
    public DateTime?  LastAccessAt { get; set; }
    public List<AccessRecordDto> AccessHistory { get; set; }
}

public class AccessRecordDto
{
    public DateTime AccessedAt { get; set; }
    public string IpAddress { get; set; }
    public string UserAgent { get; set; }
    public string Endpoint { get; set; }
    public string GrantType { get; set; }
    public List<string> Scopes { get; set; }
    public bool Success { get; set; }
    public string FailureReason { get; set; }
}
```

---

## 9. Validações

### 9.1 Validações de criação
- `Name`: Obrigatório, 3-200 caracteres
- `Description`: Opcional, máximo 500 caracteres
- `Code`: Opcional (auto-gerado), único no Tenant, formato alfanumérico com hífens/underscores
- `ClientId`: Gerado automaticamente, único globalmente
- `ClientSecret`: Gerado automaticamente, mínimo 32 caracteres seguros
- Verificar limite `MaxServiceAccounts` do plano do Tenant
- Validar permissões do usuário criador

### 9.2 Validações de atualização
- `Name`: 3-200 caracteres (se fornecido)
- `Description`: Máximo 500 caracteres
- ServiceAccount deve existir e pertencer ao Tenant
- ServiceAccount não pode estar deletado
- Campos imutáveis não podem ser alterados

### 9.3 Validações de rotação de secret
- ServiceAccount deve existir e pertencer ao Tenant
- ServiceAccount deve estar ativo
- ServiceAccount não pode estar deletado
- Pode exigir MFA adicional

### 9.4 Validações de ativação/desativação
- ServiceAccount deve existir e pertencer ao Tenant
- ServiceAccount não pode estar deletado
- Ativação:  ServiceAccount não pode estar já ativo
- Desativação: ServiceAccount não pode estar já inativo

### 9.5 Validações de remoção
- ServiceAccount deve existir e pertencer ao Tenant
- Verificar dependências críticas
- Pode exigir MFA adicional
- Documentar motivo obrigatório

---

## 10. Considerações de Performance

### 10.1 Indexação
**Índices obrigatórios:**
- `(ClientId) UNIQUE` - Autenticação rápida
- `(TenantId, Code) UNIQUE` - Unicidade e consultas por Tenant
- `(TenantId, IsActive, IsDeleted)` - Consultas gerais
- `(TenantId, LastAccessAt)` - Identificar ServiceAccounts inativos
- `(TenantId, Name)` - Busca por nome
- `(CreatedAt DESC)` - Ordenação por criação

### 10.2 Caching
**Estratégia de cache:**
- Cachear ServiceAccounts ativos por Tenant (TTL: 10 minutos)
- Cachear lookup de ClientId → ServiceAccount (TTL: 5 minutos)
- Cachear ApplicationRoles por ServiceAccount (TTL: 5 minutos)
- Invalidar cache ao criar/atualizar/desativar/deletar ServiceAccounts
- Usar cache distribuído (Redis) para ambientes multi-servidor

**Chaves de cache:**
```
service-accounts:{tenantId}
service-account:{serviceAccountId}
service-account-by-clientid:{clientId}
service-account-roles:{serviceAccountId}
```

### 10.3 Otimização de consultas
- Sempre aplicar filtro `IsDeleted = false` nas consultas
- Usar paginação em listagens
- Evitar JOIN desnecessários
- Usar projeções específicas ao invés de SELECT *
- Implementar consultas assíncronas para operações não críticas

### 10.4 Autenticação otimizada
- Índice único em `ClientId` para lookup rápido
- Cache de resultados de autenticação bem-sucedida (curto TTL)
- Rate limiting para prevenir ataques de força bruta
- Implementar backoff exponencial após falhas

---

## 11. Cenários de Uso

### 11.1 Setup de nova integração
1. Desenvolvedor identifica necessidade de integração entre sistemas
2. Administrador cria ServiceAccount no Tenant com nome descritivo
3. Sistema retorna `ClientId` e `ClientSecret` (única vez)
4. Desenvolvedor armazena credenciais em vault/secrets manager
5. Administrador atribui ApplicationRoles necessários ao ServiceAccount
6. Desenvolvedor configura aplicação cliente com as credenciais
7. Aplicação autentica usando OAuth2 Client Credentials
8. ServiceAccount acessa recursos baseado em ApplicationRoles atribuídos

### 11.2 Rotação periódica de secret
1. Sistema alerta que secret do ServiceAccount está próximo de 90 dias
2. Administrador agenda janela de manutenção
3. Administrador executa rotação de secret
4. Sistema retorna novo `ClientSecret` (única vez)
5. Administrador atualiza configurações da aplicação cliente
6. Aplicação passa a usar novo secret
7. Secret antigo é invalidado
8. Auditoria registra rotação completa

### 11.3 Investigação de segurança
1. Sistema detecta uso anormal de ServiceAccount (múltiplos IPs, horários estranhos)
2. Gera SecurityEvent de anomalia
3. Administrador de segurança é notificado
4. Desativa imediatamente o ServiceAccount
5. Analisa logs de auditoria e histórico de acessos
6. Identifica causa raiz (comprometimento, bug, etc.)
7. Rotaciona secret e reativa ServiceAccount (se apropriado)
8. Implementa controles adicionais (IP whitelist, etc.)

### 11.4 Offboarding de integração
1. Sistema integrado é descontinuado
2. Administrador identifica ServiceAccount associado
3. Desativa ServiceAccount temporariamente (período de observação)
4. Monitora se algum sistema ainda tenta autenticar
5. Após período de observação, remove ServiceAccount (soft delete)
6. Revoga todos os ApplicationRoles associados
7. Documenta remoção para auditoria
8. Atualiza matriz de integrações

### 11.5 Auditoria de ServiceAccounts
1. Auditor solicita lista de todos os ServiceAccounts do Tenant
2. Identifica ServiceAccounts sem acesso há 90+ dias
3. Identifica ServiceAccounts com ApplicationRoles excessivos
4. Recomenda remoção de ServiceAccounts obsoletos
5. Recomenda redução de privilégios onde aplicável
6. Administrador executa ações recomendadas
7. Auditoria registra mudanças

---

## 12. Testes e Validação

### 12.1 Casos de teste obrigatórios
**Criação:**
- Criar ServiceAccount válido com todos os campos
- Criar ServiceAccount com campos mínimos (apenas Name)
- Verificar geração automática de ClientId único
- Verificar geração automática de ClientSecret seguro
- Verificar geração automática de Code (formato correto)
- Verificar hash correto do ClientSecret
- Rejeitar criação com Name inválido
- Rejeitar criação quando limite do plano é excedido
- Validar unicidade de ClientId globalmente
- Validar unicidade de Code dentro do Tenant

**Consulta:**
- Listar ServiceAccounts com paginação
- Filtrar por IsActive
- Filtrar por Name (busca parcial)
- Consultar por ID
- Verificar que ClientSecretHash nunca é retornado
- Performance com grandes volumes

**Atualização:**
- Atualizar Name e Description
- Rejeitar atualização de campos imutáveis
- Rejeitar atualização de ServiceAccount deletado
- Validar permissões

**Rotação de Secret:**
- Rotacionar secret com sucesso
- Verificar novo secret é diferente do anterior
- Verificar hash correto do novo secret
- Verificar invalidação de secret antigo
- Rejeitar rotação de ServiceAccount inativo
- Rejeitar rotação de ServiceAccount deletado

**Ativação/Desativação:**
- Ativar ServiceAccount inativo
- Rejeitar ativação de ServiceAccount já ativo (validação explícita)
- Desativar ServiceAccount ativo
- Rejeitar desativação de ServiceAccount já inativo (validação explícita)
- Verificar invalidação de tokens ao desativar

**Remoção:**
- Remover ServiceAccount válido
- Verificar soft delete
- Verificar desativação de UserApplicationRoles associados
- Rejeitar remoção de ServiceAccount já deletado

**Autenticação:**
- Autenticar com ClientId e ClientSecret corretos
- Rejeitar autenticação com ClientSecret incorreto
- Rejeitar autenticação de ServiceAccount inativo
- Rejeitar autenticação de ServiceAccount deletado
- Validar rate limiting

### 12.2 Testes de segurança
- Verificar isolamento multi-tenant rigoroso
- Validar que ClientSecretHash nunca é retornado
- Validar hash correto de ClientSecret
- Testar tentativas de acesso cross-tenant
- Validar sanitização de entrada
- Testar rate limiting de autenticação
- Testar proteção contra força bruta

### 12.3 Testes de integridade
- Verificar consistência de foreign keys
- Validar cascata de operações
- Testar constraints de unicidade
- Verificar invalidação adequada de cache
- Validar integridade após operações concorrentes

### 12.4 Testes de performance
- Performance de autenticação (crítica)
- Performance de consultas de ServiceAccounts
- Eficiência do cache
- Tempo de resposta das APIs principais
- Impacto de operações em grande escala

---

## 13. Métricas e Monitoramento

### 13.1 Métricas operacionais
- **ServiceAccounts por Tenant:** Distribuição por cliente
- **ServiceAccounts ativos vs inativos:** Status geral
- **Taxa de criação:** Crescimento de integrações
- **Taxa de rotação de secrets:** Conformidade de segurança
- **ServiceAccounts sem uso há X dias:** Identificar obsoletos

### 13.2 Métricas de segurança
- **Tentativas de autenticação falhas:** Detectar ataques
- **ServiceAccounts com secrets antigos (90+ dias):** Identificar riscos
- **Rotações de secret:** Monitoramento de conformidade
- **ServiceAccounts com ApplicationRoles críticos:** Monitoramento de privilégios
- **Autenticações de IPs incomuns:** Detectar anomalias

### 13.3 Métricas de performance
- **Tempo de autenticação:** Performance crítica
- **Hit ratio de cache:** Eficiência do caching
- **Volume de autenticações:** Carga no sistema
- **Latência de consultas:** Monitoramento de queries

### 13.4 Métricas de governança
- **ServiceAccounts sem documentação:** Qualidade de gestão
- **ServiceAccounts sem acesso há 90+ dias:** Limpeza necessária
- **Taxa de aprovação de criação:** Controle de governança
- **Tempo médio até primeira rotação:** Conformidade

---

## 14. Integração com Outros Módulos

### 14.1 Tenants
- ServiceAccounts pertencem a Tenants (isolamento multi-tenant)
- Respeitam limites do Plan (`MaxServiceAccounts`)
- Desativação de Tenant desativa todos ServiceAccounts
- Validar contexto de Tenant em todas as operações

### 14.2 UserApplicationRoles
- ServiceAccounts recebem ApplicationRoles através de UserApplicationRoles
- ApplicationRoles concedem Permissions aos ServiceAccounts
- Desativação de ServiceAccount desativa UserApplicationRoles
- Cache de permissions deve ser invalidado

### 14.3 AuthorizationGrants
- ServiceAccounts autenticam via OAuth2 Client Credentials
- Geram AuthorizationGrants com tokens de acesso
- Rotação de secret invalida grants existentes
- Desativação invalida todos os grants

### 14.4 AuditLogs
- Todas as operações críticas geram logs de auditoria
- Ações executadas por ServiceAccounts são registradas
- Incluir contexto completo para investigação
- Rastrear criação, rotação, desativação e remoção

### 14.5 SecurityEvents
- Criação, rotação e desativação geram SecurityEvents
- Tentativas de autenticação falhas são monitoradas
- Detecção de anomalias gera alertas
- Integrar com sistema de SIEM

### 14.6 ApiKeys
- ServiceAccounts podem ter ApiKeys como autenticação alternativa
- ApiKeys são vinculadas ao ServiceAccount
- Gerenciamento independente de credenciais

---

## 15. Conclusão
O módulo **ServiceAccounts** é um componente essencial para suportar integrações máquina-a-máquina (M2M) no sistema IAM VianaID. 

As regras aqui definidas garantem:
- **Segurança Robusta:** Armazenamento seguro de credenciais, rotação de secrets e proteções contra ataques
- **Isolamento Multi-tenant:** Garantia de que cada Tenant controla apenas seus próprios ServiceAccounts
- **Flexibilidade:** Suporte completo a OAuth2 Client Credentials e integrações modernas
- **Auditabilidade:** Rastreamento completo de criação, uso e alterações
- **Governança:** Processos claros para criação, rotação, desativação e remoção
- **Performance:** Autenticação rápida e consultas otimizadas
- **Integridade:** Validações rigorosas e consistência de dados
- **Escalabilidade:** Arquitetura preparada para grandes volumes de autenticações

**Diferenciação clara de estados:**
1. **Ativo (`IsActive = true`):** ServiceAccount pode autenticar e acessar recursos
2. **Inativo (`IsActive = false`):** ServiceAccount suspenso temporariamente (reversível)
3. **Deletado (`IsDeleted = true`):** Soft delete permanente (histórico mantido)

Com esta estrutura detalhada, o sistema garante gestão segura e eficiente de identidades não-humanas para integrações, automações e comunicações máquina-a-máquina, mantendo os mais altos padrões de segurança e conformidade.  🤖🔐🚀