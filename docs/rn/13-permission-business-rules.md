# Documento de Regras de Negócio — Permissions

## 1. Introdução
Este documento descreve de forma detalhada as regras de negócio do módulo **Permissions** no sistema IAM (VianaID).

Uma **Permission** representa a ligação entre uma Application, um Resource e uma Action no contexto de um Tenant, definindo uma permissão específica que pode ser atribuída a Roles.   As Permissions são o componente central do sistema de autorização, estabelecendo "quem pode fazer o quê, onde e como".

---

## 2. Objetivos do Módulo de Permissions
- Definir permissões granulares baseadas na combinação Application + Resource + Action
- Servir como unidade básica de autorização no sistema
- Permitir controle de acesso fino e específico por contexto
- Facilitar gestão centralizada de permissões por categoria
- Garantir isolamento multi-tenant de permissões
- Suportar avaliação de risco de segurança por permissão
- Integrar com sistema de Roles para atribuição a usuários

---

## 3. Estrutura Geral da Permission
Uma **Permission** contém:
- `Id`
- `TenantId` (FK para Tenants)
- `CategoryId` (FK para Categories)
- `ApplicationId` (FK para Applications)
- `ResourceId` (FK para Resources)
- `ActionId` (FK para Actions)
- `Code` (código técnico gerado automaticamente pelo sistema)
- `Name` (nome da permissão)
- `Description` (descrição detalhada)
- `RiskLevel` (nível de risco de segurança)
- Estado (`Status`, `IsActive`, `IsDeleted`)
- Auditoria (`CreatedBy`, `CreatedAt`, `UpdatedBy`, `UpdatedAt`)

### 3.1 Regras do campo Code
- O campo **`Code` nunca é informado pelo usuário**
- O campo **`Code` é imutável** e **nunca pode ser alterado** após a criação
- O `Code` é **gerado automaticamente pela aplicação**, utilizando o componente `CodeGenerator`
- O formato do código segue obrigatoriamente o padrão:   

```
<PREFIXO><YYMMDD><HASH>
```

Onde:
- **PERM**:  prefixo fixo que identifica o recurso Permission (conforme 00-code-generation-business-rules.md)
- **YYMMDD**: data UTC de geração do código
- **HASH**: sequência alfanumérica aleatória de 4 caracteres

**Exemplo válido:**
```
PERM251221XTG2
```

- A unicidade do `Code` é garantida pelo sistema
- Qualquer tentativa de envio ou alteração manual do campo `Code` deve ser ignorada ou rejeitada pela API

### 3.2 Escopo Multi-tenant
- Toda Permission pertence exatamente a um Tenant específico
- Permissions são isoladas por Tenant através de Row-Level Security (RLS)
- Um Tenant não pode acessar Permissions de outros Tenants
- Permissions podem ser reutilizadas em diferentes Roles do mesmo Tenant
- Consultas e operações devem sempre respeitar o contexto do Tenant autenticado

### 3.3 Composição de Permission
- Toda Permission é formada pela combinação obrigatória de:
  - **Application**: A aplicação onde a permissão se aplica
  - **Resource**:  O recurso sendo protegido
  - **Action**:  A ação que pode ser executada sobre o recurso
- A combinação (TenantId, ApplicationId, ResourceId, ActionId) deve ser única
- Todos os componentes devem pertencer ao mesmo Tenant

### 3.4 Categorização
- Toda Permission deve estar associada a uma Category válida do mesmo Tenant
- A Category permite organização lógica e facilita governança
- Permissions da mesma categoria compartilham características de segurança similares

### 3.5 Nível de Risco
- Campo `RiskLevel` é um índice numérico configurável que indica o nível de risco da permissão
- Escala sugerida: 0 (sem risco) a 10 (risco crítico)
- Usado para avaliação de segurança e políticas de aprovação
- Permissions com alto nível de risco podem exigir aprovações adicionais

---

## 4. Regras de Negócio por Operação

### 4.1 Criar Permission (POST /v1/tenants/{tenantId}/permissions)
**Contexto:** Criação de uma nova permissão no contexto de um Tenant específico.  

**Regras:**
- A Permission é criada com `IsActive = true` e `IsDeleted = false`
- O campo `Code` é gerado automaticamente
- O campo `Name` é obrigatório e deve ser único dentro do Tenant
- O campo `TenantId` deve corresponder ao Tenant do contexto da requisição
- Todos os IDs de referência devem pertencer ao mesmo Tenant:  
  - `CategoryId` deve referenciar Category válida e ativa do Tenant
  - `ApplicationId` deve referenciar Application válida e ativa do Tenant
  - `ResourceId` deve referenciar Resource válido e ativo do Tenant
  - `ActionId` deve referenciar Action válida e ativa do Tenant
- A combinação (TenantId, ApplicationId, ResourceId, ActionId) deve ser única
- O campo `Description` é opcional mas recomendado para documentação
- O campo `RiskLevel` é opcional, padrão 0 (sem risco)
- O `CreatedBy` deve ser preenchido com o ID do usuário autenticado
- O `Status` deve ser inicializado com valor padrão (1 - Ativo)

**Validações:**
- O Tenant deve existir, estar ativo e não deletado
- Todos os componentes (Category, Application, Resource, Action) devem:  
  - Existir no banco de dados
  - Estar ativos (`IsActive = true`)
  - Não estar deletados (`IsDeleted = false`)
  - Pertencer ao mesmo Tenant
- O `Name` deve ser único dentro do escopo do Tenant
- O `RiskLevel` deve estar entre 0 e 10
- A combinação (ApplicationId, ResourceId, ActionId) deve ser única no Tenant
- O usuário deve ter permissão para criar Permissions no Tenant

**Pós-criação:**
- Registrar evento de auditoria da criação
- A Permission fica disponível para uso em Roles imediatamente
- Se `RiskLevel` >= 8, gerar alerta de segurança para revisão

---

### 4.2 Consultar Permissions (GET /v1/tenants/{tenantId}/permissions)
**Contexto:** Listar todas as Permissions de um Tenant específico.

**Regras:**
- Devem ser retornadas apenas Permissions não deletadas (`IsDeleted = false`)
- Aplicar isolamento por Tenant através de RLS ou filtro explícito
- Aplicar filtros opcionais por:  
  - `CategoryId` (Permissions de uma categoria específica)
  - `ApplicationId` (Permissions de uma aplicação específica)
  - `ResourceId` (Permissions de um recurso específico)
  - `ActionId` (Permissions de uma ação específica)
  - `IsActive` (ativas ou inativas)
  - `RiskLevel` (nível de risco específico ou range)
  - `Name` (busca parcial case-insensitive)
  - `CreatedAt` (filtros de data de criação)
- Ordenação padrão:   `CategoryId ASC, ApplicationId ASC, RiskLevel DESC, Name ASC`
- Suportar paginação obrigatória para melhor performance

**Projeção de dados:**
- Incluir todos os campos da Permission
- Incluir dados básicos dos componentes relacionados:  
  - Category (Name, Description)
  - Application (Name, Description)
  - Resource (Name, Description)
  - Action (Name, Description, HttpVerb)
- Incluir contador de quantos Roles utilizam esta Permission (opcional)

**Permissões:**
- Apenas usuários com permissão de leitura de Permissions no Tenant podem consultar
- Aplicar RLS automaticamente baseado no TenantId do contexto

---

### 4.3 Consultar Permission por ID (GET /v1/tenants/{tenantId}/permissions/{id})
**Contexto:** Obter detalhes de uma Permission específica.  

**Regras:**
- Retornar apenas se a Permission pertencer ao Tenant especificado
- Não retornar Permissions deletadas
- Incluir informações detalhadas de todos os componentes relacionados
- Incluir lista de Roles que utilizam esta Permission (opcional)
- Incluir histórico de alterações se disponível (opcional)

**Validações:**
- A Permission deve existir e pertencer ao Tenant do contexto
- A Permission não pode estar deletada
- Aplicar RLS baseado no TenantId

**Permissões:**
- Mesmo controle de acesso da listagem geral

---

### 4.4 Consultar Permission por Code (GET /v1/tenants/{tenantId}/permissions/code/{code})
**Contexto:** Buscar Permission pelo código único gerado automaticamente.

**Regras:**
- Buscar Permission pelo campo `Code` único
- Retornar 404 se não encontrada, deletada ou não pertencer ao Tenant
- Mesmas regras de projeção da consulta por ID

**Validações:**
- O código deve existir e pertencer ao Tenant especificado
- Aplicar mesmo controle de acesso das outras consultas

---

### 4.5 Atualizar Permission (PUT /v1/tenants/{tenantId}/permissions/{id})
**Contexto:** Modificar uma Permission existente.

**Regras:**
- O campo `Code` **não pode ser alterado**
- O campo `TenantId` **não pode ser alterado**
- Os campos de composição básica **não podem ser alterados**:  
  - `ApplicationId` (mudaria a essência da Permission)
  - `ResourceId` (mudaria a essência da Permission)
  - `ActionId` (mudaria a essência da Permission)
- Campos que podem ser alterados: 
  - `Name` (deve manter unicidade dentro do Tenant)
  - `Description`
  - `CategoryId` (deve ser Category válida do mesmo Tenant)
  - `RiskLevel` (validar range 0-10)
  - `IsActive`
- Atualizar `UpdatedBy` com ID do usuário autenticado
- Atualizar `UpdatedAt` com data/hora atual

**Validações:**
- A Permission deve existir, pertencer ao Tenant e não estar deletada
- Se `Name` for alterado, deve manter unicidade dentro do Tenant
- Se `CategoryId` for alterado, a nova Category deve existir, estar ativa e pertencer ao mesmo Tenant
- `RiskLevel` deve estar entre 0 e 10
- Não permitir alteração se a Permission estiver sendo utilizada em Roles críticos (regra configurável)

**Impacto em dependências:**
- Alterações na Permission podem afetar Roles que a utilizam
- Se `IsActive` for alterado para `false`, verificar impacto em Roles ativos
- Se `RiskLevel` for aumentado significativamente, considerar notificação

**Auditoria:**
- Registrar alteração em `AuditLogs` com valores antigos e novos
- Incluir contexto do usuário que fez a alteração
- Se `RiskLevel` for alterado para >= 8, gerar alerta de segurança

---

### 4.6 Ativar Permission (PATCH /v1/tenants/{tenantId}/permissions/{id}/activate)
**Contexto:** Reativar uma Permission previamente desativada.

**Regras:**
- Só é permitido ativar uma Permission existente, não deletada e pertencente ao Tenant
- **A Permission deve estar inativa** (`IsActive = false`) para ser ativada
- Validar se todos os componentes relacionados ainda estão ativos:  
  - Category ativa
  - Application ativa
  - Resource ativo
  - Action ativa
- Atualizar `IsActive = true`
- Atualizar `UpdatedBy` e `UpdatedAt`

**Validações:**
- A Permission deve existir e pertencer ao Tenant
- A Permission não pode estar deletada
- **A Permission não pode estar já ativa** - retorna erro 400 se tentar ativar uma Permission que já está ativa
- Todos os componentes relacionados devem estar ativos
- A operação **não é idempotente** - valida o estado atual e retorna erro se já estiver no estado desejado

**Motivo da validação explícita:**
- Evita chamadas desnecessárias ao banco de dados quando a Permission já está ativa
- Detecta bugs no cliente que fazem chamadas duplicadas
- Melhora a performance ao fazer "early return" sem validar dependências desnecessariamente
- Fornece feedback explícito sobre tentativas de operação inválidas

**Auditoria:**
- Registrar ativação em `AuditLogs`
- Incluir contexto do usuário que ativou

---

### 4.7 Desativar Permission (PATCH /v1/tenants/{tenantId}/permissions/{id}/deactivate)
**Contexto:** Desativar uma Permission temporariamente.

**Regras:**
- Só é permitido desativar uma Permission ativa, não deletada e pertencente ao Tenant
- **A Permission deve estar ativa** (`IsActive = true`) para ser desativada
- Atualizar `IsActive = false`
- Atualizar `UpdatedBy` e `UpdatedAt`

**Validações:**
- A Permission deve existir, pertencer ao Tenant e estar ativa
- **A Permission não pode estar já inativa** - retorna erro 400 se tentar desativar uma Permission que já está inativa
- Verificar se existem Roles ativos que utilizam esta Permission
- Opcionalmente, impedir desativação se há dependências críticas
- A operação **não é idempotente** - valida o estado atual e retorna erro se já estiver no estado desejado

**Motivo da validação explícita:**
- Evita chamadas desnecessárias ao banco de dados e verificação de dependências
- Detecta bugs no cliente que fazem chamadas duplicadas
- Melhora a performance ao fazer "early return" sem processar operação desnecessária
- Fornece feedback explícito sobre tentativas de operação inválidas

**Impacto:**
- Permissions desativadas não devem ser utilizadas em novos Roles
- Roles existentes podem ser afetos (dependendo da implementação)
- Considerar notificação de usuários afetados

**Auditoria:**
- Registrar desativação em `AuditLogs` com motivo (se fornecido)

---

### 4.8 Remover Permission (DELETE /v1/tenants/{tenantId}/permissions/{id}) — Exclusão lógica
**Contexto:** Excluir logicamente uma Permission.  

**Regras:**
- Permissions não podem ser removidas se estiverem sendo utilizadas em Roles ativos
- Aplicar soft delete:  
  - `IsDeleted = true`
  - `IsActive = false`
  - `UpdatedBy` = ID do usuário autenticado
  - `UpdatedAt` = data/hora atual

**Validações:**
- A Permission deve existir e pertencer ao Tenant
- A Permission não pode estar já deletada
- Verificar se não há Roles ativos que utilizam esta Permission
- Se houver dependências, retornar erro específico com detalhes

**Auditoria:**
- Registrar exclusão em `AuditLogs` com motivo (se fornecido)
- Incluir informações sobre dependências verificadas

---

### 4.9 Avaliar Permission de Usuário (POST /v1/tenants/{tenantId}/permissions/evaluate)
**Contexto:** Verificar se um usuário possui uma Permission específica. 

**Regras:**
- Verificar se o usuário possui Roles que contêm a Permission solicitada
- Considerar apenas Permissions e Roles ativos
- Retornar resultado booleano com detalhes do caminho de autorização

**Payload de entrada:**
```json
{
  "userId": "guid",
  "applicationId": "guid",
  "resourceId": "guid",
  "actionId": "guid"
}
```

**Resposta:**
```json
{
  "hasPermission": true,
  "permissionId": "guid",
  "permissionCode": "PERM-251221-XTG2",
  "grantedThrough": [
    {
      "roleId": "guid",
      "roleName": "Administrator",
      "assignedAt": "2025-01-01T00:00:00Z"
    }
  ],
  "riskLevel": 5
}
```

---

## 5. Regras de Integridade e Dependência

### 5.1 Dependências obrigatórias
- Toda Permission deve referenciar um `TenantId` válido e ativo
- Toda Permission deve referenciar:  
  - `CategoryId` válida, ativa e do mesmo Tenant
  - `ApplicationId` válida, ativa e do mesmo Tenant
  - `ResourceId` válido, ativo e do mesmo Tenant
  - `ActionId` válida, ativa e do mesmo Tenant
- A combinação (TenantId, ApplicationId, ResourceId, ActionId) deve ser única

### 5.2 Integridade referencial
- Permissions são referenciadas por RolePermissions através de `PermissionId`
- Não permitir exclusão de Permissions que estejam sendo utilizadas
- Implementar verificação de dependências antes de operações destrutivas

### 5.3 Cascata de operações
**Desativação de componentes:**
- Se Category for desativada:   considerar desativação de Permissions associadas
- Se Application for desativada:  desativar automaticamente todas suas Permissions
- Se Resource for desativado: desativar automaticamente Permissions associadas
- Se Action for desativada: desativar automaticamente Permissions associadas

**Desativação de Tenant:**
- Desativar automaticamente todas as Permissions do Tenant
- Não permitir criação de novas Permissions

### 5.4 Consistência de dados
- Permissions ativas devem sempre ter todos os componentes ativos
- Manter consistência temporal entre criação/atualização de registros relacionados
- Garantir que Permissions órfãos não sejam criados

---

## 6. Regras de Segurança

### 6.1 Isolamento multi-tenant
- Implementar Row-Level Security (RLS) baseado em TenantId
- Todas as consultas devem automaticamente filtrar pelo Tenant do contexto
- Validar TenantId em todas as operações para prevenir vazamento de dados
- Validar que todos os componentes pertencem ao mesmo Tenant

### 6.2 Controle de acesso
**Permissões necessárias:**
- **Criar Permission:** Permissão de escrita em Permissions no Tenant
- **Consultar Permissions:** Permissão de leitura em Permissions no Tenant
- **Atualizar Permission:** Permissão de escrita em Permissions no Tenant
- **Ativar/Desativar:** Permissão de gerenciamento em Permissions no Tenant
- **Remover Permission:** Permissão de exclusão em Permissions no Tenant
- **Avaliar Permissions:** Permissão específica ou contextual baseada no usuário

### 6.3 Avaliação de risco
- Permissions com `RiskLevel >= 8` devem gerar alertas automáticos
- Considerar aprovação adicional para Permissions de alto risco
- Auditoria especial para alterações em RiskLevel
- Monitoramento de uso de Permissions de alto risco

### 6.4 Auditoria de segurança
- Registrar todas as operações críticas (criação, alteração, remoção)
- Incluir contexto completo do usuário (IP, User Agent, etc.)
- Monitorar tentativas de acesso cross-tenant
- Log especial para avaliações de Permission

### 6.5 Validação de entrada
- Sanitizar campos de texto para prevenir XSS
- Validar tamanhos máximos de campos
- Validar GUIDs de referência
- Validar ranges de valores numéricos

---

## 7. Regras de Governança

### 7.1 Naming conventions
**Name:**
- Use formato descritivo combinando componentes
- Exemplos: 
  - "UserAPI. Create.Users"
  - "PaymentModule.Process.Transactions"
  - "ReportDashboard.View.Analytics"
- Seja consistente no formato escolhido
- Máximo 200 caracteres

### 7.2 Categorização
- Permissions devem ser agrupadas em Categories lógicas apropriadas
- Evitar Permissions órfãs ou mal categorizadas
- Revisar periodicamente a organização de Categories
- Manter hierarquia lógica de permissões

### 7.3 Documentação
- Toda Permission deve ter `Description` preenchida
- Documentar o propósito e contexto de uso
- Incluir informações sobre impacto e riscos
- Manter documentação atualizada com mudanças

### 7.4 Gestão de risco
- Avaliar periodicamente o `RiskLevel` de todas as Permissions
- Permissions críticas devem ter revisão regular
- Documentar justificativa para Permissions de alto risco
- Implementar aprovação para alterações em Permissions críticas

### 7.5 Lifecycle management
- Definir ciclo de vida claro para Permissions
- Processos para deprecation de Permissions obsoletas
- Migração de dependências antes de remoção
- Comunicação prévia de mudanças impactantes

---

## 8. Exemplos de Permissions

### 8.1 Permissions de Gerenciamento de Usuários
```json
[
  {
    "name": "UserManagementAPI.Create.Users",
    "description": "Criar novos usuários no sistema",
    "application": "User Management API",
    "resource": "Users",
    "action": "Create",
    "category": "User Management",
    "riskLevel": 6
  },
  {
    "name": "UserManagementAPI.Delete.Users",
    "description":   "Remover usuários do sistema",
    "application": "User Management API", 
    "resource": "Users",
    "action": "Delete",
    "category": "User Management",
    "riskLevel": 9
  }
]
```

### 8.2 Permissions de Relatórios
```json
[
  {
    "name": "ReportingAPI.Generate.  FinancialReports",
    "description": "Gerar relatórios financeiros",
    "application": "Reporting API",
    "resource":   "Financial Reports",
    "action": "Generate",
    "category": "Reporting",
    "riskLevel": 4
  },
  {
    "name": "ReportingAPI.Export.CustomerData",
    "description": "Exportar dados de clientes",
    "application":  "Reporting API",
    "resource": "Customer Data",
    "action":   "Export",
    "category":   "Reporting", 
    "riskLevel":   7
  }
]
```

### 8.3 Permissions Administrativas
```json
[
  {
    "name": "AdminPanel. Manage.SystemConfiguration",
    "description": "Gerenciar configurações do sistema",
    "application": "Admin Panel",
    "resource": "System Configuration",
    "action": "Manage",
    "category":   "Administration",
    "riskLevel":   10
  },
  {
    "name": "AdminPanel.View.AuditLogs",
    "description": "Visualizar logs de auditoria",
    "application": "Admin Panel",
    "resource": "Audit Logs",
    "action": "View",
    "category":  "Administration",
    "riskLevel": 5
  }
]
```

---

## 9. Estrutura da API

### 9.1 Endpoints
```
GET    /v1/tenants/{tenantId}/permissions
GET    /v1/tenants/{tenantId}/permissions/{id}
GET    /v1/tenants/{tenantId}/permissions/code/{code}
POST   /v1/tenants/{tenantId}/permissions
PUT    /v1/tenants/{tenantId}/permissions/{id}
PATCH  /v1/tenants/{tenantId}/permissions/{id}/activate
PATCH  /v1/tenants/{tenantId}/permissions/{id}/deactivate
DELETE /v1/tenants/{tenantId}/permissions/{id}
POST   /v1/tenants/{tenantId}/permissions/evaluate
```

### 9.2 DTOs

#### PermissionCreateDto
```csharp
public class PermissionCreateDto
{
    public Guid CategoryId { get; set; }        // Required
    public Guid ApplicationId { get; set; }     // Required
    public Guid ResourceId { get; set; }        // Required
    public Guid ActionId { get; set; }          // Required
    public string Name { get; set; }            // Required, max 200 chars
    public string Description { get; set; }     // Optional, max 500 chars
    public int RiskLevel { get; set; }          // Optional, default 0, range 0-10
}
```

#### PermissionUpdateDto
```csharp
public class PermissionUpdateDto
{
    public Guid CategoryId { get; set; }        // Optional
    public string Name { get; set; }            // Optional, max 200 chars
    public string Description { get; set; }     // Optional, max 500 chars
    public int RiskLevel { get; set; }          // Optional, range 0-10
    public bool IsActive { get; set; }          // Optional
}
```

#### PermissionResponseDto
```csharp
public class PermissionResponseDto
{
    public Guid Id { get; set; }
    public string Code { get; set; }
    public Guid TenantId { get; set; }
    public Guid CategoryId { get; set; }
    public Guid ApplicationId { get; set; }
    public Guid ResourceId { get; set; }
    public Guid ActionId { get; set; }
    public string Name { get; set; }
    public string Description { get; set; }
    public int RiskLevel { get; set; }
    public int Status { get; set; }
    public bool IsActive { get; set; }
    public bool IsDeleted { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime?    UpdatedAt { get; set; }
    
    // Dados dos componentes relacionados
    public string CategoryName { get; set; }
    public string ApplicationName { get; set; }
    public string ResourceName { get; set; }
    public string ActionName { get; set; }
    public string ActionHttpVerb { get; set; }
    
    // Estatísticas (opcional)
    public int RolesCount { get; set; }
    public DateTime?    LastUsedAt { get; set; }
}
```

#### PermissionEvaluationDto
```csharp
public class PermissionEvaluationDto
{
    public Guid UserId { get; set; }            // Required
    public Guid ApplicationId { get; set; }     // Required
    public Guid ResourceId { get; set; }        // Required
    public Guid ActionId { get; set; }          // Required
}

public class PermissionEvaluationResponseDto
{
    public bool HasPermission { get; set; }
    public Guid?   PermissionId { get; set; }
    public string PermissionCode { get; set; }
    public int RiskLevel { get; set; }
    public List<RoleGrantInfoDto> GrantedThrough { get; set; }
}

public class RoleGrantInfoDto
{
    public Guid RoleId { get; set; }
    public string RoleName { get; set; }
    public DateTime AssignedAt { get; set; }
}
```

---

## 10. Validações

### 10.1 Validações de criação
- `Name`: Obrigatório, máximo 200 caracteres, único por Tenant
- `CategoryId`: Obrigatório, deve existir e pertencer ao Tenant
- `ApplicationId`: Obrigatório, deve existir e pertencer ao Tenant
- `ResourceId`: Obrigatório, deve existir e pertencer ao Tenant
- `ActionId`: Obrigatório, deve existir e pertencer ao Tenant
- `Description`: Opcional, máximo 500 caracteres
- `RiskLevel`: Opcional, range 0-10, default 0
- Combinação (ApplicationId, ResourceId, ActionId) deve ser única no Tenant

### 10.2 Validações de atualização
- Não permitir alterar `Code`, `TenantId`, `ApplicationId`, `ResourceId`, `ActionId`
- `Name`: Se alterado, deve manter unicidade por Tenant
- `CategoryId`: Deve existir e pertencer ao Tenant
- `RiskLevel`: Deve estar entre 0 e 10

### 10.3 Validações de remoção
- Não permitir remover se há Roles ativos dependentes
- Verificar integridade referencial antes da exclusão

### 10.4 Validações de ativação
- Todos os componentes relacionados devem estar ativos
- Permission deve existir e não estar deletada

---

## 11. Considerações de Performance

### 11.1 Indexação
**Índices obrigatórios:**
- `(TenantId, Name) UNIQUE` - Unicidade e busca por nome
- `(TenantId, ApplicationId, ResourceId, ActionId) UNIQUE` - Unicidade de composição
- `(TenantId, CategoryId, IsActive, IsDeleted)` - Filtros comuns
- `(TenantId, ApplicationId, IsActive, IsDeleted)` - Consultas por Application
- `(TenantId, RiskLevel, IsActive, IsDeleted)` - Filtros por risco
- `(Code) UNIQUE` - Busca rápida por código

### 11.2 Caching
- Cachear Permissions ativas por Tenant
- Cachear avaliações de Permission por usuário (TTL curto)
- Invalidar cache ao criar/atualizar/remover Permissions
- TTL do cache: 10 minutos para dados gerais, 2 minutos para avaliações

### 11.3 Otimização de consultas
- Sempre aplicar filtro `IsDeleted = false` nas consultas
- Usar paginação em listagens
- Considerar views materializadas para consultas complexas de avaliação
- Denormalizar dados básicos para reduzir joins

### 11.4 Otimização de avaliação
- Implementar cache distribuído para avaliações de Permission
- Considerar pré-computação de permissões por usuário
- Usar índices compostos para queries de avaliação
- Implementar cache em memória para Permissions mais acessadas

---

## 12. Cenários de Uso

### 12.1 Setup inicial de Application
1. Administrador cria Category para organizar permissions
2. Define Resources da aplicação
3. Define Actions disponíveis
4. Cria Permissions combinando Resources e Actions
5. Organiza Permissions em Roles
6. Atribui Roles aos usuários

### 12.2 Avaliação de acesso em runtime
1. Usuário tenta acessar recurso protegido
2. Sistema identifica Application, Resource e Action necessários
3. Sistema consulta Permissions do usuário via endpoint de avaliação
4. Sistema permite ou nega acesso baseado no resultado
5. Sistema registra tentativa de acesso para auditoria

### 12.3 Gestão de risco de segurança
1. Administrador de segurança revisa Permissions de alto risco
2. Analisa usuários que possuem Permissions críticas
3. Ajusta RiskLevel baseado em análise de ameaças
4. Implementa controles adicionais para Permissions críticas
5. Monitora uso de Permissions de alto risco

### 12.4 Migração de sistema de permissões
1. Analisa sistema legado para mapear permissões
2. Cria estrutura de Categories, Resources e Actions
3. Migra permissões existentes para novo modelo
4. Valida integridade e funcionamento
5. Deprecia sistema antigo gradualmente

---

## 13. Testes e Validação

### 13.1 Casos de teste obrigatórios
**Criação:**
- Criar Permission válida
- Rejeitar criação com Name duplicado no Tenant
- Rejeitar criação com combinação (App+Resource+Action) duplicada
- Rejeitar criação com componentes inválidos ou de outros Tenants
- Validar geração automática de Code no padrão PERM-YYMMDD-HASH

**Atualização:**
- Atualizar campos permitidos
- Rejeitar alteração de campos imutáveis
- Verificar unicidade de Name após alteração
- Validar mudanças de RiskLevel

**Avaliação:**
- Avaliar Permission existente para usuário com Role adequado
- Retornar falso para usuário sem Permission
- Considerar apenas Permissions e Roles ativos
- Performance de avaliação com grandes volumes

**Ativação/Desativação:**
- Ativar Permission com todos componentes ativos
- Rejeitar ativação se componentes inativos
- Desativar Permission ativa

**Remoção:**
- Remover Permission sem dependências
- Rejeitar remoção com dependências ativas

### 13.2 Testes de segurança
- Verificar isolamento multi-tenant rigoroso
- Validar controle de acesso por permissões
- Testar tentativas de acesso cross-tenant
- Validar sanitização de entrada
- Testar avaliação de permissions com dados maliciosos

### 13.3 Testes de integridade
- Verificar consistência de foreign keys
- Validar cascata de operações
- Testar constraints de unicidade
- Verificar consistência entre componentes

### 13.4 Testes de performance
- Avaliação de permissions com milhares de usuários
- Performance de consultas com filtros complexos
- Eficiência do cache de avaliação
- Tempo de resposta das APIs principais

---

## 14. Métricas e Monitoramento

### 14.1 Métricas operacionais
- **Permissions por Tenant:** Distribuição de permissions por cliente
- **Permissions por Application:** Cobertura de permissões por app
- **Permissions por RiskLevel:** Distribuição de risco
- **Taxa de utilização:** Percentual de permissions utilizadas em roles
- **Permissions órfãs:** Permissions sem roles associadas

### 14.2 Métricas de segurança
- **Permissions de alto risco:** Contagem e uso de permissions críticas
- **Tentativas de acesso negadas:** Volume de acessos bloqueados
- **Usuários com permissions críticas:** Monitoramento de privilégios
- **Avaliações de permission suspeitas:** Detecção de padrões anômalos

### 14.3 Métricas de performance
- **Tempo de avaliação de permissions:** Performance crítica
- **Hit ratio de cache:** Eficiência do caching
- **Volume de avaliações:** Carga no sistema
- **Consultas mais lentas:** Identificação de gargalos

### 14.4 Métricas de governança
- **Permissions sem descrição:** Qualidade da documentação
- **Permissions inativas há muito tempo:** Candidatas à remoção
- **Crescimento de permissions:** Tendências de complexidade
- **Revisões de risco:** Frequência de avaliações de segurança

---

## 15. Integração com Outros Módulos

### 15.1 Categories
- Permission depende diretamente de Category
- Alterações em Category podem afetar Permissions
- Desativação de Category deve impactar Permissions associadas

### 15.2 Applications
- Permission depende diretamente de Application
- Desativação de Application desativa todas suas Permissions
- **NOTA:** Consultas de Permissions por Application devem ser implementadas no módulo Applications

### 15.3 Resources
- Permission depende diretamente de Resource
- Desativação de Resource desativa Permissions associadas
- Validar consistência Resource-Permission

### 15.4 Actions
- Permission depende diretamente de Action
- Desativação de Action desativa Permissions associadas
- Mapeamento HTTP Verb através da Action

### 15.5 ApplicationRoles
- Permissions são atribuídas através de RolePermissions
- Não permitir exclusão de Permissions com Roles ativos
- Consultar dependências antes de operações destrutivas

### 15.6 UserAccounts
- Avaliação de permissions é feita por usuário
- Integração com sistema de autenticação
- Cache de permissions por usuário

### 15.7 Tenants
- Permissions estão isoladas por Tenant (RLS)
- Desativação de Tenant afeta todas suas Permissions
- Validar contexto de Tenant em todas as operações

### 15.8 AuditLogs
- Todas as operações críticas geram logs de auditoria
- Avaliações de permission são registradas
- Rastrear mudanças em permissions críticas

---

## 16. Casos de Uso Avançados

### 16.1 Permissions condicionais
**Conceito:**
- Permissions que dependem de contexto adicional
- Exemplo: só pode editar próprios registros

**Implementação futura:**
- Campo opcional `Conditions` (JSON)
- Engine de avaliação de condições
- Validação dinâmica em runtime

### 16.2 Permissions temporárias
**Conceito:**
- Permissions com validade limitada no tempo
- Útil para acessos temporários ou emergenciais

**Implementação futura:**
- Campos `ValidFrom` e `ValidUntil`
- Job de limpeza automática
- Notificações de expiração

### 16.3 Permissions delegadas
**Conceito:**
- Usuários podem delegar suas permissions para outros
- Mantém rastreabilidade de delegação

**Implementação futura:**
- Tabela de delegação
- Limites de delegação
- Auditoria de cadeia de delegação

### 16.4 Analytics de permissions
**Conceito:**
- Análise inteligente de padrões de uso
- Recomendações de otimização

**Implementação futura:**
- Coleta de métricas de uso
- ML para detecção de padrões
- Dashboard analítico

---

## 17. Conclusão
O módulo **Permissions** é o componente central do sistema de autorização do IAM VianaID. 

As regras aqui definidas garantem:
- **Granularidade:** Controle fino baseado na combinação Application + Resource + Action
- **Segurança:** Isolamento multi-tenant rigoroso e avaliação de risco
- **Flexibilidade:** Estrutura adaptável a diferentes contextos e aplicações
- **Performance:** Otimizações para avaliação rápida de permissions
- **Integridade:** Validação rigorosa de dependências e consistência
- **Auditoria:** Rastreamento completo de operações e avaliações
- **Governança:** Organização clara e gestão de risco
- **Escalabilidade:** Arquitetura preparada para grandes volumes

Com esta estrutura detalhada, o sistema garante autorização precisa e eficiente, mantendo a simplicidade operacional necessária para ambientes empresariais complexos.  O módulo serve como fundação para um sistema de controle de acesso robusto, flexível e auditável.  🚀