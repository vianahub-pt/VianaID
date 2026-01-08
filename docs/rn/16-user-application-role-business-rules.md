# Documento de Regras de Negócio — UserApplicationRoles

## 1. Introdução
Este documento descreve de forma detalhada as regras de negócio do módulo **UserApplicationRoles** no sistema IAM (VianaID).

Um **UserApplicationRole** representa a atribuição de um ApplicationRole (papel/função) a um UserAccount ou ServiceAccount dentro de uma Application específica, no contexto de um Tenant.  Este é o módulo que efetivamente **concede acesso** aos usuários e serviços, conectando-os às permissões definidas através dos ApplicationRoles.

**UserApplicationRoles** é a ponte final entre: 
- **Identidades** (UserAccounts ou ServiceAccounts)
- **Papéis** (ApplicationRoles)
- **Permissões** (através de RolePermissions)

---

## 2. Objetivos do Módulo de UserApplicationRoles
- Atribuir ApplicationRoles a UserAccounts ou ServiceAccounts em Applications específicas
- Estabelecer o vínculo entre identidades e privilégios dentro do sistema RBAC
- Permitir gestão centralizada de acessos por aplicação
- Garantir isolamento multi-tenant das atribuições
- Suportar auditoria completa de concessões e revogações de acesso
- Permitir revogação granular e temporária de acesso
- Facilitar consultas de "quem tem acesso a quê"
- Suportar gestão diferenciada para usuários humanos e contas de serviço

---

## 3. Estrutura Geral do UserApplicationRole
Um **UserApplicationRole** contém:
- `Id`
- `TenantId` (FK para Tenants)
- `ApplicationId` (FK para Applications)
- `ApplicationRoleId` (FK para ApplicationRoles)
- `UserAccountId` (FK para UserAccounts) — **Exclusivo com ServiceAccountId**
- `ServiceAccountId` (FK para ServiceAccounts) — **Exclusivo com UserAccountId**
- Datas de atribuição e revogação (`AssignedAt`, `RevokedAt`)
- Estado (`Status`, `IsActive`, `IsDeleted`)
- Auditoria (`CreatedBy`, `CreatedAt`, `UpdatedBy`, `UpdatedAt`)

### 3.1 Escopo Multi-tenant
- Todo UserApplicationRole pertence exatamente a um Tenant específico
- UserApplicationRoles são isolados por Tenant através de Row-Level Security (RLS)
- Um Tenant não pode acessar UserApplicationRoles de outros Tenants
- Consultas e operações devem sempre respeitar o contexto do Tenant autenticado

### 3.2 Dualidade UserAccount vs ServiceAccount
**Constraint de Exclusividade:**
```sql
CONSTRAINT CK_UserApplicationRoles_AccountType CHECK (
    (UserAccountId IS NOT NULL AND ServiceAccountId IS NULL) OR
    (UserAccountId IS NULL AND ServiceAccountId IS NOT NULL)
)
```

**Regras:**
- Todo UserApplicationRole deve referenciar **OU** um UserAccount **OU** um ServiceAccount
- **Nunca ambos** simultaneamente
- **Nunca nenhum** (ambos NULL)
- Esta distinção permite tratamento diferenciado entre usuários humanos e serviços automatizados

### 3.3 Composição de UserApplicationRole
- Todo UserApplicationRole é formado pela combinação obrigatória de:
  - **Identidade**: UserAccount OU ServiceAccount
  - **Application**: A aplicação onde o acesso é concedido
  - **ApplicationRole**: O papel/função sendo atribuído
- A combinação (TenantId, ApplicationId, ApplicationRoleId, UserAccountId) deve ser única
- A combinação (TenantId, ApplicationId, ApplicationRoleId, ServiceAccountId) deve ser única
- Application, ApplicationRole e a Identidade devem pertencer ao mesmo Tenant

### 3.4 Relacionamento com outros módulos
- Application, ApplicationRole e Identidade (User/Service) devem existir e pertencer ao mesmo Tenant
- ApplicationRole deve referenciar a mesma Application
- Todas as entidades relacionadas devem estar ativas para permitir a atribuição
- UserApplicationRoles ativos concedem todas as Permissions associadas ao ApplicationRole

---

## 4. Regras de Negócio por Operação

### 4.1 Atribuir ApplicationRole a UserAccount (POST /v1/tenants/{tenantId}/applications/{applicationId}/users/{userId}/roles)
**Contexto:** Conceder um ApplicationRole a um usuário específico dentro de uma aplicação. 

**Regras:**
- O UserApplicationRole é criado com `IsActive = true` e `IsDeleted = false`
- O campo `TenantId` deve corresponder ao Tenant do contexto da requisição
- O `ApplicationId` deve corresponder à aplicação especificada na URL
- O `UserAccountId` deve corresponder ao usuário especificado na URL
- O `ServiceAccountId` deve ser NULL (exclusividade)
- O `ApplicationRoleId` deve referenciar ApplicationRole válido, ativo e da mesma Application
- A combinação (TenantId, ApplicationId, ApplicationRoleId, UserAccountId) deve ser única
- O `CreatedBy` deve ser preenchido com o ID do usuário autenticado
- O `AssignedAt` deve ser preenchido com a data/hora atual
- O `Status` deve ser inicializado com valor padrão (1 - Ativo)

**Validações:**
- O Tenant deve existir, estar ativo e não deletado
- O UserAccount deve existir, estar ativo, não deletado e pertencer ao Tenant
- A Application deve existir, estar ativa, não deletada e pertencer ao Tenant
- O ApplicationRole deve existir, estar ativo, não deletado e pertencer à Application
- Não deve existir atribuição idêntica já criada (incluindo soft-deleted)
- O usuário deve ter permissão para gerenciar roles na Application
- Verificar limites do plano (MaxUsers, roles por usuário, etc.)
- Validar políticas de segregação de funções (SoD) se aplicável

**Pós-criação:**
- Registrar evento de auditoria da atribuição
- Invalidar cache de permissions para o UserAccount
- As Permissions do ApplicationRole ficam imediatamente disponíveis ao usuário
- Disparar webhook se configurado (user. role.assigned)
- Notificar o usuário sobre nova atribuição (opcional)

---

### 4.2 Atribuir ApplicationRole a ServiceAccount (POST /v1/tenants/{tenantId}/applications/{applicationId}/service-accounts/{serviceAccountId}/roles)
**Contexto:** Conceder um ApplicationRole a uma conta de serviço específica dentro de uma aplicação.

**Regras:**
- O UserApplicationRole é criado com `IsActive = true` e `IsDeleted = false`
- O campo `TenantId` deve corresponder ao Tenant do contexto da requisição
- O `ApplicationId` deve corresponder à aplicação especificada na URL
- O `ServiceAccountId` deve corresponder à conta de serviço especificada na URL
- O `UserAccountId` deve ser NULL (exclusividade)
- O `ApplicationRoleId` deve referenciar ApplicationRole válido, ativo e da mesma Application
- A combinação (TenantId, ApplicationId, ApplicationRoleId, ServiceAccountId) deve ser única
- O `CreatedBy` deve ser preenchido com o ID do usuário autenticado
- O `AssignedAt` deve ser preenchido com a data/hora atual
- O `Status` deve ser inicializado com valor padrão (1 - Ativo)

**Validações:**
- O Tenant deve existir, estar ativo e não deletado
- O ServiceAccount deve existir, estar ativo, não deletado e pertencer ao Tenant
- A Application deve existir, estar ativa, não deletada e pertencer ao Tenant
- O ApplicationRole deve existir, estar ativo, não deletado e pertencer à Application
- Não deve existir atribuição idêntica já criada
- O usuário deve ter permissão para gerenciar service accounts na Application
- Verificar limites do plano (MaxServiceAccounts, etc.)

**Pós-criação:**
- Registrar evento de auditoria da atribuição
- Invalidar cache de permissions para o ServiceAccount
- As Permissions do ApplicationRole ficam imediatamente disponíveis ao serviço
- Disparar webhook se configurado (service.role. assigned)

---

### 4.3 Listar ApplicationRoles de um UserAccount (GET /v1/tenants/{tenantId}/applications/{applicationId}/users/{userId}/roles)
**Contexto:** Listar todos os ApplicationRoles atribuídos a um usuário específico em uma aplicação.

**Regras:**
- Devem ser retornados apenas UserApplicationRoles não deletados (`IsDeleted = false`)
- Aplicar isolamento por Tenant através de RLS ou filtro explícito
- Filtrar apenas UserApplicationRoles do UserAccount especificado
- Filtrar apenas UserApplicationRoles da Application especificada
- Aplicar filtros opcionais por: 
  - `IsActive` (ativos ou inativos)
  - `RevokedAt` (apenas revogados ou não revogados)
  - `ApplicationRoleId` (role específico)
- Ordenação padrão: `ApplicationRole.Name ASC, AssignedAt DESC`
- Suportar paginação obrigatória para melhor performance

**Projeção de dados:**
- Incluir todos os campos do UserApplicationRole
- Incluir dados detalhados do ApplicationRole: 
  - Nome, Código, Descrição
- Incluir informações da Application
- Incluir datas de atribuição e revogação
- Incluir usuário que atribuiu e que revogou (se aplicável)
- Incluir contagem de Permissions associadas ao ApplicationRole

**Permissões:**
- Usuários podem consultar seus próprios ApplicationRoles
- Administradores podem consultar ApplicationRoles de qualquer usuário
- Aplicar RLS automaticamente baseado no TenantId do contexto

---

### 4.4 Listar ApplicationRoles de um ServiceAccount (GET /v1/tenants/{tenantId}/applications/{applicationId}/service-accounts/{serviceAccountId}/roles)
**Contexto:** Listar todos os ApplicationRoles atribuídos a uma conta de serviço específica em uma aplicação.

**Regras:**
- Mesmas regras da seção 4.3, mas para ServiceAccounts
- Filtrar apenas UserApplicationRoles onde `ServiceAccountId IS NOT NULL`

---

### 4.5 Listar Usuários de um ApplicationRole (GET /v1/tenants/{tenantId}/applications/{applicationId}/roles/{roleId}/users)
**Contexto:** Listar todos os UserAccounts que possuem um ApplicationRole específico. 

**Regras:**
- Devem ser retornados apenas UserApplicationRoles não deletados
- Filtrar apenas UserApplicationRoles onde `UserAccountId IS NOT NULL`
- Filtrar apenas UserApplicationRoles do ApplicationRole especificado
- Aplicar filtros opcionais por:
  - `IsActive` (ativos ou inativos)
  - `RevokedAt` (apenas revogados ou não revogados)
- Ordenação padrão: `UserAccount.Name ASC, AssignedAt DESC`
- Suportar paginação obrigatória

**Projeção de dados:**
- Incluir dados do UserAccount (Id, Name, Email)
- Incluir datas de atribuição e revogação
- Incluir usuário que atribuiu
- Incluir informações de último acesso (LastLoginAt)

---

### 4.6 Listar ServiceAccounts de um ApplicationRole (GET /v1/tenants/{tenantId}/applications/{applicationId}/roles/{roleId}/service-accounts)
**Contexto:** Listar todos os ServiceAccounts que possuem um ApplicationRole específico.

**Regras:**
- Mesmas regras da seção 4.5, mas para ServiceAccounts
- Filtrar apenas UserApplicationRoles onde `ServiceAccountId IS NOT NULL`

---

### 4.7 Consultar UserApplicationRole por ID (GET /v1/tenants/{tenantId}/user-application-roles/{id})
**Contexto:** Obter detalhes de um UserApplicationRole específico.

**Regras:**
- Retornar apenas se o UserApplicationRole pertencer ao Tenant especificado
- Não retornar UserApplicationRoles deletados
- Incluir informações detalhadas do ApplicationRole, Application e Identidade
- Incluir lista resumida de Permissions concedidas através do ApplicationRole
- Incluir metadados de auditoria completos

**Validações:**
- O UserApplicationRole deve existir e pertencer ao Tenant do contexto
- O UserApplicationRole não pode estar deletado
- Aplicar RLS baseado no TenantId

---

### 4.8 Consultar Permissions Efetivas de um UserAccount (GET /v1/tenants/{tenantId}/users/{userId}/effective-permissions)
**Contexto:** Obter todas as Permissions efetivas de um usuário através de todos seus ApplicationRoles.

**Regras:**
- Buscar todos os UserApplicationRoles ativos e não revogados do usuário
- Para cada ApplicationRole, buscar todas as Permissions através de RolePermissions
- Consolidar lista eliminando duplicatas
- Aplicar filtros opcionais por: 
  - `ApplicationId` (permissions de uma aplicação específica)
  - `CategoryId` (permissions de uma categoria específica)
  - `RiskLevel` (permissions acima de determinado nível de risco)
- Incluir informação de qual ApplicationRole concedeu cada Permission
- Suportar paginação

**Projeção de dados:**
```json
{
  "userId": "guid",
  "userName": "string",
  "totalPermissions": 0,
  "permissions": [
    {
      "permissionId": "guid",
      "permissionCode": "PERM-251221-XTG2",
      "permissionName":  "string",
      "riskLevel": 5,
      "applicationName": "string",
      "resourceName": "string",
      "actionName": "string",
      "categoryName": "string",
      "grantedThrough": [
        {
          "applicationRoleId": "guid",
          "applicationRoleName": "string",
          "assignedAt": "2025-01-01T00:00:00Z"
        }
      ]
    }
  ]
}
```

**Performance:**
- Implementar cache agressivo (TTL:  2-5 minutos)
- Invalidar cache ao criar/revogar/deletar UserApplicationRoles
- Considerar views materializadas para queries frequentes

---

### 4.9 Consultar Permissions Efetivas de um ServiceAccount (GET /v1/tenants/{tenantId}/service-accounts/{serviceAccountId}/effective-permissions)
**Contexto:** Obter todas as Permissions efetivas de uma conta de serviço. 

**Regras:**
- Mesmas regras da seção 4.8, mas para ServiceAccounts

---

### 4.10 Avaliar Acesso de UserAccount (POST /v1/tenants/{tenantId}/users/{userId}/evaluate-access)
**Contexto:** Verificar se um usuário tem Permission específica através de seus ApplicationRoles.

**Payload de entrada:**
```json
{
  "applicationId": "guid",
  "resourceId": "guid",
  "actionId": "guid"
}
```

**Regras:**
- Buscar todos os UserApplicationRoles ativos e não revogados do usuário na Application
- Para cada ApplicationRole, verificar se possui a Permission solicitada através de RolePermissions
- Retornar resultado booleano com detalhes da concessão
- Considerar apenas entidades ativas (UserApplicationRoles, ApplicationRoles, RolePermissions, Permissions)

**Resposta:**
```json
{
  "hasAccess": true,
  "permissionId": "guid",
  "permissionCode": "PERM-251221-XTG2",
  "permissionName": "string",
  "riskLevel": 5,
  "grantedThrough": {
    "userApplicationRoleId": "guid",
    "applicationRoleId": "guid",
    "applicationRoleName": "Manager",
    "assignedAt":  "2025-01-01T00:00:00Z",
    "assignedBy": "admin-user-guid"
  }
}
```

**Performance:**
- Implementar cache de resultados (TTL: 1 minuto)
- Esta operação é crítica para performance (usada em cada request autenticado)
- Considerar cache distribuído (Redis) para ambientes multi-servidor

---

### 4.11 Avaliar Acesso de ServiceAccount (POST /v1/tenants/{tenantId}/service-accounts/{serviceAccountId}/evaluate-access)
**Contexto:** Verificar se uma conta de serviço tem Permission específica. 

**Regras:**
- Mesmas regras da seção 4.10, mas para ServiceAccounts

---

### 4.12 Ativar UserApplicationRole (PATCH /v1/tenants/{tenantId}/user-application-roles/{id}/activate)
**Contexto:** Reativar um UserApplicationRole previamente desativado.

**Regras:**
- Só é permitido ativar um UserApplicationRole existente, não deletado e pertencente ao Tenant
- **O UserApplicationRole deve estar inativo** (`IsActive = false`) para ser ativado
- Validar se o ApplicationRole e a Identidade relacionados ainda estão ativos
- Atualizar `IsActive = true`
- Atualizar `UpdatedBy` e `UpdatedAt`
- Não alterar `RevokedAt` (revogação é diferente de desativação)

**Validações:**
- O UserApplicationRole deve existir e pertencer ao Tenant
- O UserApplicationRole não pode estar deletado
- **O UserApplicationRole não pode estar já ativo** - retorna erro 400 se tentar ativar um que já está ativo
- O ApplicationRole associado deve estar ativo
- A Identidade (UserAccount ou ServiceAccount) deve estar ativa
- A Application deve estar ativa
- A operação **não é idempotente** - valida o estado atual e retorna erro se já estiver no estado desejado

**Motivo da validação explícita:**
- Evita chamadas desnecessárias ao banco de dados quando já está ativo
- Detecta bugs no cliente que fazem chamadas duplicadas
- Melhora a performance ao fazer "early return"
- Fornece feedback explícito sobre tentativas de operação inválidas

**Auditoria:**
- Registrar ativação em `AuditLogs`
- Incluir contexto do usuário que ativou
- Invalidar cache de permissions para a identidade afetada

**Impacto:**
- UserApplicationRoles ativados restauram imediatamente o acesso às Permissions
- Usuário/Serviço recupera privilégios do ApplicationRole

---

### 4.13 Desativar UserApplicationRole (PATCH /v1/tenants/{tenantId}/user-application-roles/{id}/deactivate)
**Contexto:** Desativar um UserApplicationRole temporariamente sem revogar formalmente.

**Regras:**
- Só é permitido desativar um UserApplicationRole ativo, não deletado e pertencente ao Tenant
- **O UserApplicationRole deve estar ativo** (`IsActive = true`) para ser desativado
- Atualizar `IsActive = false`
- Atualizar `UpdatedBy` e `UpdatedAt`
- Não alterar `RevokedAt` (desativação é temporária, revogação é formal)

**Validações:**
- O UserApplicationRole deve existir, pertencer ao Tenant e estar ativo
- **O UserApplicationRole não pode estar já inativo** - retorna erro 400 se tentar desativar um que já está inativo
- A operação **não é idempotente** - valida o estado atual e retorna erro se já estiver no estado desejado

**Motivo da validação explícita:**
- Evita chamadas desnecessárias ao banco de dados
- Detecta bugs no cliente que fazem chamadas duplicadas
- Melhora a performance ao fazer "early return"
- Fornece feedback explícito sobre tentativas de operação inválidas

**Impacto:**
- UserApplicationRoles desativados removem temporariamente o acesso às Permissions
- Usuário/Serviço perde privilégios do ApplicationRole imediatamente
- Pode ser reativado posteriormente (reversível)

**Auditoria:**
- Registrar desativação em `AuditLogs` com motivo (se fornecido)
- Invalidar cache de permissions para a identidade afetada

---

### 4.14 Revogar UserApplicationRole (PATCH /v1/tenants/{tenantId}/user-application-roles/{id}/revoke)
**Contexto:** Revogar formalmente um UserApplicationRole (mais forte que desativar).

**Regras:**
- Só é permitido revogar um UserApplicationRole não deletado e pertencente ao Tenant
- O UserApplicationRole deve estar ativo ou inativo (revogação é independente)
- Atualizar `RevokedAt` com data/hora atual
- Atualizar `IsActive = false` (revogação implica desativação)
- Atualizar `UpdatedBy` e `UpdatedAt`

**Payload de entrada (opcional):**
```json
{
  "reason": "Mudança de função do usuário"
}
```

**Validações:**
- O UserApplicationRole deve existir e pertencer ao Tenant
- O UserApplicationRole não pode estar deletado
- O UserApplicationRole não pode estar já revogado (`RevokedAt IS NOT NULL`)

**Diferença entre Revogar e Desativar:**
- **Desativar**:  Temporário, reversível, sem registro formal de motivo
- **Revogar**: Formal, registra data e motivo, indica decisão administrativa

**Auditoria:**
- Registrar revogação em `AuditLogs` com motivo obrigatório
- Incluir detalhes completos do ApplicationRole revogado
- Invalidar cache de permissions para a identidade afetada

**Impacto:**
- Usuário/Serviço perde acesso às Permissions imediatamente
- Registro permanente da revogação para auditoria
- Pode ser revertido criando nova atribuição (não reativa a mesma)

---

### 4.15 Remover UserApplicationRole (DELETE /v1/tenants/{tenantId}/user-application-roles/{id})
**Contexto:** Excluir logicamente um UserApplicationRole (soft delete).

**Regras:**
- Aplicar soft delete: 
  - `IsDeleted = true`
  - `IsActive = false`
  - `UpdatedBy` = ID do usuário autenticado
  - `UpdatedAt` = data/hora atual
- Se ainda não revogado, atualizar `RevokedAt` com data/hora atual

**Validações:**
- O UserApplicationRole deve existir e pertencer ao Tenant
- O UserApplicationRole não pode estar já deletado
- Verificar se a remoção não viola políticas de segurança: 
  - Não remover último usuário com role administrativo
  - Não remover própria atribuição de role administrativo

**Impacto:**
- Remove permanentemente (logicamente) a atribuição
- Usuário/Serviço perde acesso às Permissions imediatamente
- Registro mantido para auditoria histórica
- Não pode ser reativado (seria necessário criar nova atribuição)

**Auditoria:**
- Registrar exclusão em `AuditLogs` com motivo (se fornecido)
- Incluir informações detalhadas do ApplicationRole removido
- Invalidar cache de permissions para a identidade afetada

---

## 5. Regras de Integridade e Dependência

### 5.1 Dependências obrigatórias
- Todo UserApplicationRole deve referenciar um `TenantId` válido e ativo
- Todo UserApplicationRole deve referenciar: 
  - `ApplicationId` válido, ativo e do mesmo Tenant
  - `ApplicationRoleId` válido, ativo e da mesma Application
  - `UserAccountId` **OU** `ServiceAccountId` válido, ativo e do mesmo Tenant (exclusivo)
- A combinação (TenantId, ApplicationId, ApplicationRoleId, UserAccountId) deve ser única
- A combinação (TenantId, ApplicationId, ApplicationRoleId, ServiceAccountId) deve ser única
- ApplicationRole deve pertencer à Application especificada

### 5.2 Integridade referencial
- UserApplicationRoles são a fonte final de autorização para acesso
- Não permitir exclusão de ApplicationRoles que tenham UserApplicationRoles ativos
- Não permitir exclusão de UserAccounts/ServiceAccounts com UserApplicationRoles ativos
- Implementar verificação de dependências antes de operações destrutivas

### 5.3 Cascata de operações
**Desativação de ApplicationRole:**
- Desativar automaticamente todos os UserApplicationRoles associados
- Notificar usuários afetados sobre perda de privilégios
- Registrar evento de segurança em SecurityEvents

**Desativação de Application:**
- Desativar automaticamente todos os UserApplicationRoles da Application
- Notificar administradores sobre impacto

**Desativação de UserAccount/ServiceAccount:**
- Desativar automaticamente todos os UserApplicationRoles da identidade
- Não permitir criação de novos UserApplicationRoles

**Desativação de Tenant:**
- Desativar automaticamente todos os UserApplicationRoles do Tenant
- Não permitir criação de novos UserApplicationRoles

### 5.4 Consistência de dados
- UserApplicationRoles ativos devem sempre ter ApplicationRole, Application e Identidade ativos
- Manter consistência temporal entre criação/atualização de registros relacionados
- Garantir que associações órfãs não sejam criadas
- Validar que ApplicationRole pertence à Application especificada

---

## 6. Regras de Segurança

### 6.1 Isolamento multi-tenant
- Implementar Row-Level Security (RLS) baseado em TenantId
- Todas as consultas devem automaticamente filtrar pelo Tenant do contexto
- Validar TenantId em todas as operações para prevenir vazamento de dados
- Validar que Application, ApplicationRole e Identidade pertencem ao mesmo Tenant

### 6.2 Controle de acesso
**Permissões necessárias:**
- **Atribuir ApplicationRole:** Permissão de gerenciamento de usuários/roles no Tenant
- **Consultar UserApplicationRoles:** Permissão de leitura de usuários ou próprio usuário
- **Ativar/Desativar:** Permissão de gerenciamento de usuários/roles no Tenant
- **Revogar:** Permissão de gerenciamento de usuários/roles no Tenant
- **Remover UserApplicationRole:** Permissão de gerenciamento de usuários/roles no Tenant
- **Avaliar Acesso:** Permissão específica ou próprio usuário consultando próprio acesso

**Proteções especiais:**
- Usuário não pode remover própria atribuição de role administrativo
- Não permitir remoção do último administrador do Tenant
- Validar permissões antes de operações críticas

### 6.3 Políticas de segurança
- ApplicationRoles críticos (`RiskLevel >= 8`) podem exigir aprovação adicional
- Remoção de atribuições administrativas pode exigir confirmação dupla
- Auditoria especial para alterações em UserApplicationRoles críticos
- Monitoramento de uso de Permissions de alto risco
- Detecção de segregação de funções (SoD - Segregation of Duties)
- Alertas para atribuições de múltiplos roles conflitantes

### 6.4 Auditoria de segurança
- Registrar todas as operações críticas (criação, alteração, revogação, remoção)
- Incluir contexto completo do usuário (IP, User Agent, etc.)
- Monitorar tentativas de acesso cross-tenant
- Log especial para avaliações de acesso
- Registrar motivo de revogações
- Manter histórico imutável de atribuições

### 6.5 Validação de entrada
- Sanitizar campos de entrada
- Validar GUIDs de referência
- Verificar existência de entidades referenciadas
- Validar que ApplicationRole pertence à Application especificada

---

## 7. Regras de Governança

### 7.1 Gestão de acessos
- Revisar periodicamente UserApplicationRoles para detectar acessos excessivos
- Implementar processo de aprovação para atribuições críticas
- Documentar justificativa para atribuições de alto risco
- Manter princípio do menor privilégio necessário
- Implementar recertificação periódica de acessos

### 7.2 Lifecycle management
- Definir ciclo de vida claro para UserApplicationRoles
- Processos para revisão periódica de atribuições
- Remoção automática de atribuições obsoletas
- Comunicação prévia de mudanças impactantes
- Workflow de onboarding/offboarding

### 7.3 Segregação de Funções (SoD)
- Detectar atribuições conflitantes (ex: aprovador + executor)
- Alertar administradores sobre violações de SoD
- Permitir exceções documentadas e aprovadas
- Manter registro de conflitos aprovados

### 7.4 Atribuições Temporárias
**Preparação para funcionalidade futura:**
- Suportar atribuições com data de expiração
- Expiração automática de acessos temporários
- Notificações antes da expiração
- Renovação mediante aprovação

### 7.5 Documentação
- Manter documentação atualizada dos acessos por usuário
- Documentar propósito de cada atribuição
- Incluir informações sobre riscos e controles
- Manter matriz de responsabilidades atualizada

---

## 8. Estrutura da API

### 8.1 Endpoints para UserAccounts
```
# Atribuições
POST   /v1/tenants/{tenantId}/applications/{applicationId}/users/{userId}/roles
GET    /v1/tenants/{tenantId}/applications/{applicationId}/users/{userId}/roles
DELETE /v1/tenants/{tenantId}/user-application-roles/{id}

# Operações de estado
PATCH  /v1/tenants/{tenantId}/user-application-roles/{id}/activate
PATCH  /v1/tenants/{tenantId}/user-application-roles/{id}/deactivate
PATCH  /v1/tenants/{tenantId}/user-application-roles/{id}/revoke

# Consultas
GET    /v1/tenants/{tenantId}/user-application-roles/{id}
GET    /v1/tenants/{tenantId}/applications/{applicationId}/roles/{roleId}/users
GET    /v1/tenants/{tenantId}/users/{userId}/effective-permissions
POST   /v1/tenants/{tenantId}/users/{userId}/evaluate-access
```

### 8.2 Endpoints para ServiceAccounts
```
# Atribuições
POST   /v1/tenants/{tenantId}/applications/{applicationId}/service-accounts/{serviceAccountId}/roles
GET    /v1/tenants/{tenantId}/applications/{applicationId}/service-accounts/{serviceAccountId}/roles

# Consultas
GET    /v1/tenants/{tenantId}/applications/{applicationId}/roles/{roleId}/service-accounts
GET    /v1/tenants/{tenantId}/service-accounts/{serviceAccountId}/effective-permissions
POST   /v1/tenants/{tenantId}/service-accounts/{serviceAccountId}/evaluate-access
```

### 8.3 DTOs

#### UserApplicationRoleCreateDto
```csharp
public class UserApplicationRoleCreateDto
{
    public Guid ApplicationRoleId { get; set; }          // Required
}
```

#### UserApplicationRoleResponseDto
```csharp
public class UserApplicationRoleResponseDto
{
    public Guid Id { get; set; }
    public Guid TenantId { get; set; }
    public Guid ApplicationId { get; set; }
    public Guid ApplicationRoleId { get; set; }
    public Guid?  UserAccountId { get; set; }
    public Guid? ServiceAccountId { get; set; }
    public DateTime AssignedAt { get; set; }
    public DateTime? RevokedAt { get; set; }
    public int Status { get; set; }
    public bool IsActive { get; set; }
    public bool IsDeleted { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime?  UpdatedAt { get; set; }
    
    // Dados do ApplicationRole
    public string ApplicationRoleName { get; set; }
    public string ApplicationRoleCode { get; set; }
    public string ApplicationRoleDescription { get; set; }
    
    // Dados da Application
    public string ApplicationName { get; set; }
    
    // Dados da Identidade
    public string IdentityName { get; set; }
    public string IdentityEmail { get; set; }  // Apenas para UserAccount
    public string IdentityType { get; set; }    // "User" ou "Service"
    
    // Dados de auditoria
    public string AssignedByUserName { get; set; }
    public string RevokedByUserName { get; set; }
    
    // Estatísticas
    public int PermissionsCount { get; set; }
}
```

#### EffectivePermissionsResponseDto
```csharp
public class EffectivePermissionsResponseDto
{
    public Guid IdentityId { get; set; }
    public string IdentityName { get; set; }
    public string IdentityType { get; set; }  // "User" ou "Service"
    public int TotalPermissions { get; set; }
    public List<EffectivePermissionDto> Permissions { get; set; }
}

public class EffectivePermissionDto
{
    public Guid PermissionId { get; set; }
    public string PermissionCode { get; set; }
    public string PermissionName { get; set; }
    public string PermissionDescription { get; set; }
    public int RiskLevel { get; set; }
    
    // Dados dos componentes da Permission
    public string ApplicationName { get; set; }
    public string ResourceName { get; set; }
    public string ActionName { get; set; }
    public string CategoryName { get; set; }
    
    // Informações de concessão
    public List<RoleGrantInfoDto> GrantedThrough { get; set; }
}

public class RoleGrantInfoDto
{
    public Guid UserApplicationRoleId { get; set; }
    public Guid ApplicationRoleId { get; set; }
    public string ApplicationRoleName { get; set; }
    public DateTime AssignedAt { get; set; }
    public string AssignedBy { get; set; }
}
```

#### EvaluateAccessRequestDto
```csharp
public class EvaluateAccessRequestDto
{
    public Guid ApplicationId { get; set; }      // Required
    public Guid ResourceId { get; set; }         // Required
    public Guid ActionId { get; set; }           // Required
}
```

#### EvaluateAccessResponseDto
```csharp
public class EvaluateAccessResponseDto
{
    public bool HasAccess { get; set; }
    public Guid?  PermissionId { get; set; }
    public string PermissionCode { get; set; }
    public string PermissionName { get; set; }
    public int?  RiskLevel { get; set; }
    public RoleGrantInfoDto GrantedThrough { get; set; }
    public string DenialReason { get; set; }  // Quando HasAccess = false
}
```

#### RevokeUserApplicationRoleDto
```csharp
public class RevokeUserApplicationRoleDto
{
    public string Reason { get; set; }  // Optional but recommended
}
```

---

## 9. Validações

### 9.1 Validações de criação
- `ApplicationRoleId`: Obrigatório, deve existir e pertencer à Application especificada
- `UserAccountId` ou `ServiceAccountId`: Exatamente um deve ser fornecido (constraint de exclusividade)
- ApplicationRole deve estar ativo e pertencer à Application
- Application deve estar ativa e pertencer ao Tenant
- Identidade (UserAccount ou ServiceAccount) deve estar ativa e pertencer ao Tenant
- Combinação (ApplicationId, ApplicationRoleId, UserAccountId/ServiceAccountId) deve ser única no Tenant
- ApplicationRole deve pertencer à Application especificada (validação cruzada)
- Verificar limites do plano do Tenant

### 9.2 Validações de ativação
- UserApplicationRole deve existir e não estar deletado
- ApplicationRole deve estar ativo
- Application deve estar ativa
- Identidade deve estar ativa
- UserApplicationRole não pode estar já ativo

### 9.3 Validações de revogação
- UserApplicationRole deve existir e pertencer ao Tenant
- UserApplicationRole não pode estar deletado
- UserApplicationRole não pode estar já revogado
- Motivo de revogação é recomendado (pode ser obrigatório por política)

### 9.4 Validações de remoção
- UserApplicationRole deve existir e pertencer ao Tenant
- Verificar políticas de segurança:
  - Não remover último administrador do Tenant
  - Não remover própria atribuição de role administrativo
- Confirmar se não viola políticas de governança

---

## 10. Considerações de Performance

### 10.1 Indexação
**Índices obrigatórios:**
- `(TenantId, ApplicationId, ApplicationRoleId, UserAccountId) UNIQUE WHERE UserAccountId IS NOT NULL`
- `(TenantId, ApplicationId, ApplicationRoleId, ServiceAccountId) UNIQUE WHERE ServiceAccountId IS NOT NULL`
- `(TenantId, UserAccountId, IsActive, IsDeleted) WHERE UserAccountId IS NOT NULL`
- `(TenantId, ServiceAccountId, IsActive, IsDeleted) WHERE ServiceAccountId IS NOT NULL`
- `(TenantId, ApplicationId, IsActive, IsDeleted)`
- `(TenantId, ApplicationRoleId, IsActive, IsDeleted)`
- `(AssignedAt DESC)` - Para ordenação por data
- `(RevokedAt) WHERE RevokedAt IS NOT NULL` - Para consultas de revogados

### 10.2 Caching
**Estratégia de cache:**
- Cachear UserApplicationRoles ativos por UserAccount/ServiceAccount (TTL: 5 minutos)
- Cachear Permissions efetivas por identidade (TTL: 2-5 minutos)
- Cachear resultados de avaliações de acesso (TTL: 1 minuto)
- Invalidar cache ao criar/atualizar/revogar/deletar UserApplicationRoles
- Usar cache distribuído (Redis) para ambientes multi-servidor

**Chaves de cache:**
```
user-app-roles:{tenantId}:{userId}
service-app-roles:{tenantId}:{serviceAccountId}
effective-permissions:{tenantId}:{userId}
evaluate-access:{tenantId}:{userId}:{appId}:{resourceId}:{actionId}
```

### 10.3 Otimização de consultas
- Sempre aplicar filtro `IsDeleted = false` nas consultas
- Usar paginação em listagens
- Considerar views materializadas para consultas frequentes de permissions efetivas
- Denormalizar dados básicos para reduzir joins
- Implementar consultas assíncronas para operações não críticas
- Usar projeções específicas ao invés de SELECT *

### 10.4 Queries otimizadas
**Consulta de permissions efetivas (exemplo):**
```sql
SELECT DISTINCT 
    p.Id,
    p.Code,
    p.Name,
    p.RiskLevel,
    app.Name AS ApplicationName,
    r.Name AS ResourceName,
    a. Name AS ActionName,
    c.Name AS CategoryName,
    uar.AssignedAt,
    uar.ApplicationRoleId
FROM UserApplicationRoles uar
INNER JOIN ApplicationRoles ar ON uar.ApplicationRoleId = ar.Id
INNER JOIN RolePermissions rp ON ar.Id = rp.ApplicationRoleId
INNER JOIN Permissions p ON rp.PermissionId = p.Id
INNER JOIN Applications app ON p.ApplicationId = app.Id
INNER JOIN Resources r ON p.ResourceId = r.Id
INNER JOIN Actions a ON p.ActionId = a. Id
INNER JOIN Categories c ON p.CategoryId = c.Id
WHERE uar.TenantId = @TenantId
  AND uar.UserAccountId = @UserId
  AND uar.IsActive = 1
  AND uar.IsDeleted = 0
  AND uar.RevokedAt IS NULL
  AND ar.IsActive = 1
  AND ar.IsDeleted = 0
  AND rp.IsActive = 1
  AND rp.IsDeleted = 0
  AND p. IsActive = 1
  AND p.IsDeleted = 0
ORDER BY p.RiskLevel DESC, p.Name ASC;
```

---

## 11. Cenários de Uso

### 11.1 Onboarding de novo usuário
1. Administrador cria UserAccount no Tenant
2. Identifica ApplicationRoles necessários baseados na função do usuário
3. Cria UserApplicationRoles atribuindo ApplicationRoles ao usuário
4. Sistema automaticamente concede todas as Permissions dos ApplicationRoles
5. Usuário pode fazer login e acessar recursos baseado em suas Permissions efetivas
6. Email de boas-vindas é enviado com resumo de acessos concedidos

### 11.2 Mudança de função (promoção/transferência)
1. Administrador revoga UserApplicationRoles antigos (opcional:  mantém alguns)
2. Cria novos UserApplicationRoles com ApplicationRoles da nova função
3. Sistema atualiza Permissions efetivas imediatamente
4. Cache de permissions do usuário é invalidado
5. Usuário ganha/perde acesso conforme novos ApplicationRoles
6. Auditoria registra mudança completa de acessos

### 11.3 Auditoria de acessos
1. Auditor de segurança lista todos os UserApplicationRoles de um usuário específico
2. Consulta Permissions efetivas para identificar privilégios reais
3. Identifica ApplicationRoles excessivos ou desnecessários
4. Revoga UserApplicationRoles que violam políticas de segurança
5. Documenta alterações para conformidade
6. Agenda recertificação periódica

### 11.4 Resposta a incidente de segurança
1. Detectado uso indevido de Permission por um usuário
2. Administrador de segurança desativa imediatamente todos os UserApplicationRoles do usuário
3. Investiga quais ApplicationRoles concediam a Permission abusada
4. Analisa logs de auditoria e SecurityEvents para rastrear ações
5. Revoga formalmente UserApplicationRoles após investigação
6. Implementa controles adicionais antes de restaurar acessos

### 11.5 Offboarding de usuário
1. RH notifica desligamento do funcionário
2. Administrador desativa UserAccount
3. Sistema automaticamente desativa todos os UserApplicationRoles do usuário
4. Acesso é removido imediatamente de todas as Applications
5. Após período de retenção, UserApplicationRoles são deletados (soft delete)
6. Auditoria completa é gerada para conformidade

### 11.6 Setup de ServiceAccount para integração
1. Desenvolvedor cria ServiceAccount para nova integração
2. Identifica Permissions mínimas necessárias
3. Cria ApplicationRole específico para a integração (se não existir)
4. Atribui ApplicationRole ao ServiceAccount via UserApplicationRole
5. Testa integração com as Permissions concedidas
6. Valida que ServiceAccount não tem privilégios excessivos

### 11.7 Recertificação periódica de acessos
1. Sistema gera relatório de todos os UserApplicationRoles ativos
2. Envia para gestores para recertificação
3. Gestores aprovam ou revogam cada atribuição
4. UserApplicationRoles não aprovados são automaticamente revogados
5. Auditoria registra decisões de recertificação
6. Próxima recertificação é agendada (trimestral/semestral)

---

## 12. Testes e Validação

### 12.1 Casos de teste obrigatórios
**Criação:**
- Criar UserApplicationRole válido para UserAccount
- Criar UserApplicationRole válido para ServiceAccount
- Rejeitar criação com ApplicationRoleId inválido
- Rejeitar criação de atribuição duplicada
- Rejeitar criação com ApplicationRole inativo
- Rejeitar criação com Identidade inativa
- Rejeitar criação com Application inativa
- Rejeitar criação violando constraint de exclusividade (UserAccountId e ServiceAccountId)
- Rejeitar criação quando ApplicationRole não pertence à Application
- Validar limites do plano

**Consulta:**
- Listar UserApplicationRoles por UserAccount
- Listar UserApplicationRoles por ServiceAccount
- Listar usuários por ApplicationRole
- Listar ServiceAccounts por ApplicationRole
- Consultar Permissions efetivas por UserAccount
- Consultar Permissions efetivas por ServiceAccount
- Filtrar por status ativo/inativo
- Filtrar por revogados/não revogados
- Performance com grandes volumes de dados

**Avaliação de Acesso:**
- Avaliar acesso com Permission concedida
- Avaliar acesso com Permission não concedida
- Avaliar acesso com UserApplicationRole inativo
- Avaliar acesso com UserApplicationRole revogado
- Performance de avaliações frequentes

**Ativação/Desativação:**
- Ativar UserApplicationRole inativo
- Rejeitar ativação de UserApplicationRole já ativo (validação explícita)
- Desativar UserApplicationRole ativo
- Rejeitar desativação de UserApplicationRole já inativo (validação explícita)
- Verificar invalidação de cache
- Verificar impacto imediato em avaliações de acesso

**Revogação:**
- Revogar UserApplicationRole ativo
- Revogar UserApplicationRole inativo
- Rejeitar revogação de UserApplicationRole já revogado
- Validar registro de motivo de revogação
- Verificar impacto em Permissions efetivas

**Remoção:**
- Remover UserApplicationRole válido
- Verificar soft delete
- Confirmar impacto em avaliações de acesso
- Rejeitar remoção do último administrador
- Rejeitar auto-remoção de role administrativo

### 12.2 Testes de segurança
- Verificar isolamento multi-tenant rigoroso
- Validar controle de acesso por permissões
- Testar tentativas de acesso cross-tenant
- Validar sanitização de entrada
- Testar proteção contra escalação de privilégios
- Validar que ApplicationRole pertence à Application especificada

### 12.3 Testes de integridade
- Verificar consistência de foreign keys
- Validar cascata de operações
- Testar constraints de unicidade
- Verificar constraint de exclusividade (UserAccountId/ServiceAccountId)
- Verificar invalidação adequada de cache
- Validar integridade após operações concorrentes

### 12.4 Testes de performance
- Performance de consultas de permissions efetivas
- Performance de avaliações de acesso (crítica)
- Eficiência do cache
- Tempo de resposta das APIs principais
- Impacto de operações em grande escala
- Concorrência em criação/revogação

### 12.5 Testes de governança
- Detectar violações de segregação de funções
- Validar limites do plano
- Testar workflows de aprovação
- Validar recertificação periódica
- Testar notificações de mudanças críticas

---

## 13. Métricas e Monitoramento

### 13.1 Métricas operacionais
- **UserApplicationRoles por Tenant:** Distribuição por cliente
- **UserApplicationRoles por UserAccount:** Complexidade de acessos por usuário
- **UserApplicationRoles por ApplicationRole:** Popularidade de cada role
- **Taxa de revogação:** Frequência de alterações em acessos
- **Tempo médio de atribuição:** Eficiência do processo de onboarding
- **UserApplicationRoles ativos vs inativos:** Controle de estado

### 13.2 Métricas de segurança
- **Usuários com ApplicationRoles críticos:** Monitoramento de privilégios
- **Alterações em UserApplicationRoles:** Frequência e padrões
- **Usuários com múltiplos ApplicationRoles:** Identificar excessos
- **Violações de segregação de funções:** Alertas de conflitos
- **UserApplicationRoles revogados:** Análise de tendências
- **Atribuições sem recertificação:** Acessos pendentes de revisão

### 13.3 Métricas de performance
- **Tempo de avaliação de acesso:** Performance crítica para autorização
- **Hit ratio de cache:** Eficiência do caching
- **Volume de atribuições:** Carga no sistema
- **Latência de consultas de permissions efetivas:** Monitoramento de queries complexas

### 13.4 Métricas de governança
- **Taxa de aprovação de recertificação:** Qualidade da gestão de acessos
- **Tempo médio de revogação após detecção de anomalia:** Resposta a incidentes
- **Usuários sem acesso há X dias:** Identificar acessos obsoletos
- **ServiceAccounts sem uso há X dias:** Limpeza de acessos automatizados

---

## 14. Integração com Outros Módulos

### 14.1 ApplicationRoles
- UserApplicationRole depende diretamente de ApplicationRole
- Desativação de ApplicationRole desativa todos UserApplicationRoles associados
- Validar consistência ApplicationRole-Application

### 14.2 RolePermissions
- UserApplicationRoles concedem Permissions através de RolePermissions
- Alterações em RolePermissions afetam imediatamente Permissions efetivas
- Cache de permissions deve ser invalidado

### 14.3 Applications
- UserApplicationRoles vinculam identidades a Applications específicas
- Desativação de Application afeta todos UserApplicationRoles associados
- Validar que ApplicationRole pertence à Application

### 14.4 UserAccounts / ServiceAccounts
- UserApplicationRoles são criados para identidades específicas
- Desativação de identidade desativa todos UserApplicationRoles associados
- Offboarding deve revogar/deletar UserApplicationRoles

### 14.5 Tenants
- UserApplicationRoles estão isolados por Tenant (RLS)
- Desativação de Tenant afeta todos seus UserApplicationRoles
- Validar contexto de Tenant em todas as operações

### 14.6 AuditLogs
- Todas as operações críticas geram logs de auditoria
- Incluir contexto completo para investigação
- Rastrear mudanças em UserApplicationRoles críticos
- Manter histórico imutável

### 14.7 SecurityEvents
- Atribuições/revogações críticas geram SecurityEvents
- Detectar anomalias (múltiplas atribuições em curto período, etc.)
- Integrar com sistema de alertas de segurança

### 14.8 UsageMetrics
- Contabilizar atribuições para limites do plano
- Monitorar uso de ApplicationRoles por Tenant
- Gerar relatórios de consumo

---

## 15. Conclusão
O módulo **UserApplicationRoles** é o componente final e mais crítico do sistema RBAC do IAM VianaID, pois é onde a autorização efetivamente acontece. 

As regras aqui definidas garantem:
- **Controle Granular:** Atribuição precisa de ApplicationRoles a identidades específicas
- **Flexibilidade:** Suporte tanto para UserAccounts quanto ServiceAccounts
- **Segurança:** Isolamento multi-tenant rigoroso, auditoria completa e proteções avançadas
- **Integridade:** Validação rigorosa de dependências e consistência entre módulos
- **Performance:** Cache agressivo e queries otimizadas para avaliações frequentes
- **Governança:** Recertificação periódica, segregação de funções e workflows de aprovação
- **Auditabilidade:** Rastreamento completo de concessões, revogações e mudanças
- **Escalabilidade:** Arquitetura preparada para grandes volumes e alta concorrência

**Diferenciação de Estados:**
1. **Ativo (`IsActive = true`)**: Acesso totalmente funcional
2. **Inativo (`IsActive = false`)**: Acesso temporariamente suspenso (reversível)
3. **Revogado (`RevokedAt != null`)**: Decisão administrativa formal (reversível via nova atribuição)
4. **Deletado (`IsDeleted = true`)**: Soft delete permanente (histórico mantido)

Com esta estrutura detalhada, o sistema garante gestão completa de acessos através de papéis, mantendo simplicidade operacional, segurança empresarial robusta e conformidade com regulamentações. 

O módulo serve como o pilar central do sistema de autorização, conectando identidades a privilégios de forma auditável, segura e eficiente.  🚀🔐