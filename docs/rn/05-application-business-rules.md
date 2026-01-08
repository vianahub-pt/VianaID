# Documento de Regras de Negócio — Aplicações

## 1. Introdução
Este documento descreve de forma detalhada as regras de negócio do módulo **Aplicações** no sistema IAM (VianaID).

Uma **Aplicação** representa um software, serviço ou sistema registrado por um Tenant para autenticação, autorização e integração com a plataforma.

---

## 2. Objetivos do Módulo de Aplicações
- Permitir o registro de aplicações cliente (Web, API, Mobile, Serviços).
- Gerenciar credenciais OAuth2 (ClientId e ClientSecret).
- Controlar escopos, permissões e papéis por aplicação.
- Garantir isolamento e segurança no contexto multi-tenant.

---

## 3. Estrutura Geral da Aplicação
Uma **Aplicação** contém:
- `Id`
- `Code` (código técnico gerado automaticamente pelo sistema)
- `TenantId`
- `CategoryId`
- `ClientId`
- `ClientSecretHash`
- Configurações OAuth (RedirectUris, GrantTypes, Scopes)
- Indicadores de estado (`Status`, `IsActive`, `IsDeleted`)
- Dados de auditoria (`CreatedBy`, `CreatedAt`, `UpdatedBy`, `UpdatedAt`)

### 3.1 Regras do campo Code
- O campo **`Code` nunca é informado pelo usuário**.
- O campo **`Code` é imutável** e **nunca pode ser alterado** após a criação da Aplicação.
- O `Code` é **gerado automaticamente pela aplicação**, utilizando o componente `CodeGenerator`.
- O formato do código segue obrigatoriamente o padrão:

```
<PREFIXO><YYMMDD><HASH>
```

Onde:
- **APPL**: prefixo fixo que identifica o recurso Aplicação.
- **YYMMDD**: data UTC de geração do código.
- **HASH**: sequência alfanumérica aleatória de 4 caracteres.

**Exemplo válido:**
```
APPL251214XTG2
```

- A unicidade do `Code` é garantida pelo sistema.
- Qualquer tentativa de envio ou alteração manual do campo `Code` deve ser ignorada ou rejeitada pela API.

### 3.2 Escopo Multi-tenant
- Toda Aplicação pertence obrigatoriamente a um Tenant.
- Uma Aplicação não pode ser transferida entre Tenants.
- Todas as operações devem respeitar o contexto do Tenant (TenantContext / RLS).

---

## 4. Regras de Negócio por Operação

### 4.1 Criar Aplicação (POST /v1/applications)
- O Tenant deve existir e estar ativo.
- A Categoria associada deve existir e estar ativa.
- O `Code`, `ClientId` e `ClientSecret` são gerados automaticamente.
- A Aplicação é criada ativa por padrão.

### 4.2 Consultar Aplicações (GET /v1/applications)
- Devem ser retornadas apenas Aplicações não deletadas.
- Consultas devem respeitar isolamento por Tenant.

### 4.3 Atualizar Aplicação (PUT /v1/applications/{id})
- O `Code`, `TenantId` e `ClientId` não podem ser alterados.
- Alterações de configuração OAuth devem ser validadas.
- Alterações devem registrar auditoria.

### 4.4 Ativar Aplicação (PATCH /v1/applications/{id}/activate)
**Contexto:** Reativar uma Aplicação previamente desativada.

**Regras:**
- Só é permitido ativar uma Aplicação existente e não deletada.
- **A Aplicação deve estar inativa** (`IsActive = false`) para ser ativada.
- Validar se o Tenant e a Category associados ainda estão ativos.
- Atualizar `IsActive = true`.
- Atualizar `UpdatedBy` e `UpdatedAt`.

**Validações:**
- A Aplicação deve existir e pertencer ao Tenant.
- A Aplicação não pode estar deletada.
- **A Aplicação não pode estar já ativa** - retorna erro 400 se tentar ativar uma Aplicação que já está ativa.
- O Tenant e a Category associados devem estar ativos.
- A operação **não é idempotente** - valida o estado atual e retorna erro se já estiver no estado desejado.

**Motivo da validação explícita:**
- Evita chamadas desnecessárias ao banco de dados quando a Aplicação já está ativa.
- Detecta bugs no cliente que fazem chamadas duplicadas.
- Melhora a performance ao fazer "early return" sem validar dependências desnecessariamente.
- Fornece feedback explícito sobre tentativas de operação inválidas.

**Auditoria:**
- Registrar ativação em `AuditLogs`.
- Incluir contexto do usuário que ativou.

---

### 4.5 Desativar Aplicação (PATCH /v1/applications/{id}/deactivate)
**Contexto:** Desativar uma Aplicação temporariamente.

**Regras:**
- **A Aplicação deve estar ativa** (`IsActive = true`) para ser desativada.
- A desativação bloqueia emissões de token e acessos.
- Atualizar `IsActive = false`.
- Atualizar `UpdatedBy` e `UpdatedAt`.

**Validações:**
- A Aplicação deve existir, pertencer ao Tenant e estar ativa.
- **A Aplicação não pode estar já inativa** - retorna erro 400 se tentar desativar uma Aplicação que já está inativa.
- Verificar se existem ApplicationRoles, Permissions ou tokens ativos associados.
- Opcionalmente, impedir desativação se há dependências críticas.
- A operação **não é idempotente** - valida o estado atual e retorna erro se já estiver no estado desejado.

**Motivo da validação explícita:**
- Evita chamadas desnecessárias ao banco de dados e verificação de dependências.
- Detecta bugs no cliente que fazem chamadas duplicadas.
- Melhora a performance ao fazer "early return" sem processar operação desnecessária.
- Fornece feedback explícito sobre tentativas de operação inválidas.

**Impacto:**
- Aplicações desativadas bloqueiam autenticação e autorização.
- Todos os ApplicationRoles da aplicação devem ser desativados automaticamente.
- Considerar notificação de usuários e administradores afetados.

**Auditoria:**
- Registrar desativação em `AuditLogs` com motivo (se fornecido).
