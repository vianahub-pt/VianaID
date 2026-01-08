# Documento de Regras de Negócio — ApplicationRoles

## 1. Introdução
Este documento descreve de forma detalhada as regras de negócio do módulo **ApplicationRoles** no sistema IAM (VianaID).

Um **ApplicationRole** representa um papel/função específico dentro de uma Application no contexto de um Tenant. Os ApplicationRoles agrupam Permissions relacionadas e são atribuídos a usuários ou service accounts através de UserApplicationRoles, formando a base do sistema de autorização baseado em papéis (RBAC).

---

## 2. Objetivos do Módulo de ApplicationRoles
- Definir papéis específicos dentro de cada aplicação por tenant
- Agrupar Permissions logicamente relacionadas em roles funcionais
- Facilitar gestão de autorização através de atribuição de papéis
- Permitir hierarquia organizacional e segregação de responsabilidades
- Suportar isolamento multi-tenant de roles customizados
- Simplificar administração de permissões através de roles reutilizáveis
- Integrar com sistema de usuários e service accounts para atribuição

---

## 3. Estrutura Geral do ApplicationRole
Um **ApplicationRole** contém: 
- `Id`
- `TenantId` (FK para Tenants)
- `ApplicationId` (FK para Applications)
- `Code` (código técnico gerado automaticamente pelo sistema)
- `Name` (nome do papel)
- `Description` (descrição detalhada)
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
- **ROLE**:  prefixo fixo que identifica o recurso ApplicationRole (conforme 00-code-generation-business-rules.md)
- **YYMMDD**: data UTC de geração do código
- **HASH**: sequência alfanumérica aleatória de 4 caracteres

**Exemplo válido:**
```
ROLE251221XTG2
```

- A unicidade do `Code` é garantida pelo sistema
- Qualquer tentativa de envio ou alteração manual do campo `Code` deve ser ignorada ou rejeitada pela API

### 3.2 Escopo Multi-tenant
- Todo ApplicationRole pertence exatamente a um Tenant específico
- ApplicationRoles são isolados por Tenant através de Row-Level Security (RLS)
- Um Tenant não pode acessar ApplicationRoles de outros Tenants
- ApplicationRoles podem ser atribuídos a múltiplos usuários do mesmo Tenant
- Consultas e operações devem sempre respeitar o contexto do Tenant autenticado

### 3.3 Relacionamento com Application
- Todo ApplicationRole deve estar associado a uma Application específica do mesmo Tenant
- ApplicationRoles são específicos por Application (um role "Admin" em App A é diferente do role "Admin" em App B)
- A combinação (TenantId, ApplicationId, Name) deve ser única
- ApplicationRoles de uma Application não podem ser usado em outra Application

### 3.4 Tipos de ApplicationRoles
**Roles Administrativos:**
- Roles com alto nível de privilégios dentro da aplicação
- Exemplos: "Super Admin", "Application Admin", "Tenant Admin"

**Roles Funcionais:**
- Roles baseados em funções específicas do negócio
- Exemplos:  "Manager", "Supervisor", "Analyst", "Operator"

**Roles de Acesso:**
- Roles baseados em níveis de acesso a recursos
- Exemplos: "Read Only", "Editor", "Contributor", "Viewer"

**Roles Temporários:**
- Roles para situações específicas ou temporárias
- Exemplos:  "Guest", "Trial User", "Temporary Access"

---

## 4. Regras de Negócio por Operação

### 4.1 Criar ApplicationRole (POST /v1/tenants/{tenantId}/applications/{applicationId}/roles)
**Contexto:** Criação de um novo papel no contexto de uma Application específica. 

**Regras:**
- O ApplicationRole é criado com `IsActive = true` e `IsDeleted = false`
- O campo `Code` é gerado automaticamente
- O campo `Name` é obrigatório e deve ser único dentro da Application do Tenant
- O campo `TenantId` deve corresponder ao Tenant do contexto da requisição
- O campo `ApplicationId` deve corresponder à Application do contexto da requisição
- A Application deve existir, estar ativa e pertencer ao mesmo Tenant
- A combinação (TenantId, ApplicationId, Name) deve ser única
- O campo `Description` é opcional mas recomendado para documentação
- O `CreatedBy` deve ser preenchido com o ID do usuário autenticado
- O `Status` deve ser inicializado com valor padrão (1 - Ativo)

**Validações:**
- O Tenant deve existir, estar ativo e não deletado
- A Application deve existir, estar ativa, não deletada e pertencer ao mesmo Tenant
- O `Name` deve ser único dentro do escopo da Application no Tenant
- O usuário deve ter permissão para criar ApplicationRoles na Application
- O `Name` deve seguir convenções de nomenclatura (sem caracteres especiais prejudiciais)

**Pós-criação:**
- Registrar evento de auditoria da criação
- O ApplicationRole fica disponível para atribuição de Permissions imediatamente
- O ApplicationRole fica disponível para atribuição a usuários imediatamente

---

### 4.2 Consultar ApplicationRoles (GET /v1/tenants/{tenantId}/applications/{applicationId}/roles)
**Contexto:** Listar todos os ApplicationRoles de uma Application específica.

**Regras:**
- Devem ser retornados apenas ApplicationRoles não deletados (`IsDeleted = false`)
- Aplicar isolamento por Tenant através de RLS ou filtro explícito
- Filtrar apenas ApplicationRoles da Application especificada
- Aplicar filtros opcionais por: 
  - `IsActive` (ativos ou inativos)
  - `Name` (busca parcial case-insensitive)
  - `CreatedAt` (filtros de data de criação)
- Ordenação padrão: `Name ASC`
- Suportar paginação obrigatória para melhor performance

**Projeção de dados:**
- Incluir todos os campos do ApplicationRole
- Incluir dados básicos da Application associada (Name, Description)
- Incluir contador de quantas Permissions estão associadas a este Role (opcional)
- Incluir contador de quantos usuários possuem este Role (opcional)

**Permissões:**
- Apenas usuários com permissão de leitura de ApplicationRoles na Application podem consultar
- Aplicar RLS automaticamente baseado no TenantId do contexto

---

### 4.3 Consultar ApplicationRole por ID (GET /v1/tenants/{tenantId}/applications/{applicationId}/roles/{id})
**Contexto:** Obter detalhes de um ApplicationRole específico.

**Regras:**
- Retornar apenas se o ApplicationRole pertencer ao Tenant e Application especificados
- Não retornar ApplicationRoles deletados
- Incluir informações detalhadas da Application associada
- Incluir lista de Permissions associadas a este Role (opcional)
- Incluir lista de usuários que possuem este Role (opcional)

**Validações:**
- O ApplicationRole deve existir e pertencer ao Tenant e Application do contexto
- O ApplicationRole não pode estar deletado
- Aplicar RLS baseado no TenantId

**Permissões:**
- Mesmo controle de acesso da listagem geral

---

### 4.4 Consultar ApplicationRole por Code (GET /v1/tenants/{tenantId}/applications/{applicationId}/roles/code/{code})
**Contexto:** Buscar ApplicationRole pelo código único gerado automaticamente.

**Regras:**
- Buscar ApplicationRole pelo campo `Code` único
- Retornar 404 se não encontrado, deletado ou não pertencer ao Tenant/Application
- Mesmas regras de projeção da consulta por ID

**Validações:**
- O código deve existir e pertencer ao Tenant e Application especificados
- Aplicar mesmo controle de acesso das outras consultas

---

### 4.5 Listar ApplicationRoles do Tenant (GET /v1/tenants/{tenantId}/roles)
**Contexto:** Listar todos os ApplicationRoles de todas as Applications do Tenant.

**Regras:**
- Retornar ApplicationRoles de todas as Applications do Tenant
- Aplicar mesmo isolamento e filtros da consulta por Application
- Incluir informação da Application na projeção
- Ordenação padrão: `ApplicationId ASC, Name ASC`

**Permissões:**
- Usuário deve ter permissão global de leitura de Roles no Tenant

---

### 4.6 Atualizar ApplicationRole (PUT /v1/tenants/{tenantId}/applications/{applicationId}/roles/{id})
**Contexto:** Modificar um ApplicationRole existente.

**Regras:**
- O campo `Code` **não pode ser alterado**
- O campo `TenantId` **não pode ser alterado**
- O campo `ApplicationId` **não pode ser alterado**
- Campos que podem ser alterados:
  - `Name` (deve manter unicidade dentro da Application)
  - `Description`
  - `IsActive`
- Atualizar `UpdatedBy` com ID do usuário autenticado
- Atualizar `UpdatedAt` com data/hora atual

**Validações:**
- O ApplicationRole deve existir, pertencer ao Tenant/Application e não estar deletado
- Se `Name` for alterado, deve manter unicidade dentro da Application no Tenant
- Não permitir alteração se o ApplicationRole estiver sendo utilizado por usuários críticos (regra configurável)

**Impacto em dependências:**
- Alterações no ApplicationRole podem afetar usuários que o possuem
- Se `IsActive` for alterado para `false`, verificar impacto em usuários ativos
- Considerar notificação ou validação prévia se há dependências críticas

**Auditoria:**
- Registrar alteração em `AuditLogs` com valores antigos e novos
- Incluir contexto do usuário que fez a alteração

---

### 4.7 Ativar ApplicationRole (PATCH /v1/tenants/{tenantId}/applications/{applicationId}/roles/{id}/activate)
**Contexto:** Reativar um ApplicationRole previamente desativado.

**Regras:**
- Só é permitido ativar um ApplicationRole existente, não deletado e pertencente ao Tenant/Application
- **O ApplicationRole deve estar inativo** (`IsActive = false`) para ser ativado
- Validar se a Application associada ainda está ativa
- Atualizar `IsActive = true`
- Atualizar `UpdatedBy` e `UpdatedAt`

**Validações:**
- O ApplicationRole deve existir e pertencer ao Tenant/Application
- O ApplicationRole não pode estar deletado
- **O ApplicationRole não pode estar já ativo** - retorna erro 400 se tentar ativar um ApplicationRole que já está ativo
- A Application associada deve estar ativa
- A operação **não é idempotente** - valida o estado atual e retorna erro se já estiver no estado desejado

**Motivo da validação explícita:**
- Evita chamadas desnecessárias ao banco de dados quando o ApplicationRole já está ativo
- Detecta bugs no cliente que fazem chamadas duplicadas
- Melhora a performance ao fazer "early return" sem validar dependências desnecessariamente
- Fornece feedback explícito sobre tentativas de operação inválidas

**Auditoria:**
- Registrar ativação em `AuditLogs`
- Incluir contexto do usuário que ativou

---

### 4.8 Desativar ApplicationRole (PATCH /v1/tenants/{tenantId}/applications/{applicationId}/roles/{id}/deactivate)
**Contexto:** Desativar um ApplicationRole temporariamente.

**Regras:**
- Só é permitido desativar um ApplicationRole ativo, não deletado e pertencente ao Tenant/Application
- **O ApplicationRole deve estar ativo** (`IsActive = true`) para ser desativado
- Atualizar `IsActive = false`
- Atualizar `UpdatedBy` e `UpdatedAt`

**Validações:**
- O ApplicationRole deve existir, pertencer ao Tenant/Application e estar ativo
- **O ApplicationRole não pode estar já inativo** - retorna erro 400 se tentar desativar um ApplicationRole que já está inativo
- Verificar se existem usuários ativos que possuem este ApplicationRole
- Opcionalmente, impedir desativação se há dependências críticas
- A operação **não é idempotente** - valida o estado atual e retorna erro se já estiver no estado desejado

**Motivo da validação explícita:**
- Evita chamadas desnecessárias ao banco de dados e verificação de dependências
- Detecta bugs no cliente que fazem chamadas duplicadas
- Melhora a performance ao fazer "early return" sem processar operação desnecessária
- Fornece feedback explícito sobre tentativas de operação inválidas

**Impacto:**
- ApplicationRoles desativados não devem ser atribuídos a novos usuários
- Usuários existentes podem ser afetados (dependendo da implementação)
- Considerar notificação de usuários afetados

**Auditoria:**
- Registrar desativação em `AuditLogs` com motivo (se fornecido)