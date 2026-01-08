# Documento de Regras de Negócio — ApiKeys

## 1. Introdução
Este documento descreve as regras de negócio do módulo **ApiKeys** no sistema IAM (VianaID). O recurso **ApiKeys** permite gerenciar chaves de API utilizadas para integração de sistemas terceiros ao SaaS, fornecendo autenticação e controle de acessos granulares.

---

## 2. Objetivos do Módulo de ApiKeys
- Criar e gerenciar chaves de API para acessos externos.
- Controlar permissões e escopo de uso das chaves.
- Monitorar e auditar o uso de chaves para segurança e conformidade.
- Restrição baseada em IP e origem para aumentar a segurança.
- Suportar limites de taxa de uso (rate-limiting).
- Facilitar revogação de chaves comprometidas.

---

## 3. Estrutura Geral da ApiKey
Uma **ApiKey** contém:
- `Id`
- `TenantId` (FK para Tenants)
- `Code` (código único da chave)
- `Name` (nome descritivo da chave)
- `KeyHash` (hash seguro do segredo da chave)
- `KeyPrefix` (prefixo público para identificação rápida)
- Controle de escopo:
  - `Scopes` (JSON com escopos permitidos)
  - `AllowedIps` (JSON com IPs permitidos)
  - `AllowedOrigins` (JSON com origens autorizadas)
- Controle de uso:
  - `RateLimit` (chamadas permitidas por período)
  - `UsageCount` (contador de uso)
- Rastreamento:
  - `LastUsedAt` (última vez em que foi usada)
  - `LastUsedIp` (último IP que a utilizou)
- Ciclo de vida:
  - `ExpiresAt` (data de expiração)
  - `RevokedAt` (data de revogação)
  - `RevokedReason` (motivo da revogação)
- Estado (`Status`, `IsActive`, `IsDeleted`)
- Auditoria (`CreatedBy`, `CreatedAt`, `UpdatedBy`, `UpdatedAt`)

### 3.1 Hash de ApiKey
- O segredo (`Key`) da chave **nunca é armazenado em texto puro** no banco.
- Apenas o **hash do segredo** é persistido no campo `KeyHash`.
- O hash deve utilizar um algoritmo seguro (ex.: bcrypt, Argon2) com custo configurável.

### 3.2 Escopo Multi-Tenant
- Toda ApiKey pertence exatamente a um Tenant.
- As chaves de um Tenant são isoladas de outros Tenants.
- Consultas e ações devem respeitar o contexto do Tenant autenticado.

---

## 4. Regras de Negócio por Operação

### 4.1 Criar ApiKey (POST /v1/tenants/{tenantId}/api-keys)
**Contexto:** Criar nova chave de API no contexto de um Tenant.

**Regras:**
- A chave é criada com:
  - `IsActive = true`
  - `UsageCount = 0`
  - `RateLimit` e `Scopes` opcionais (com valores padrão configuráveis).
- O segredo (`Key`) é gerado automaticamente (32+ caracteres seguros).
- O `KeyHash` é calculado e armazenado no banco.
- O `KeyPrefix` é derivado automaticamente (ex.: primeiros 6 caracteres do segredo).
- O `Code` é gerado automaticamente como identificador único.
- Campos configuráveis:
  - `Name` (obrigatório, 3-200 caracteres).
  - `Scopes` (opcional, JSON array).
  - `AllowedIps` (opcional, JSON array de IPs permitidos).
  - `AllowedOrigins` (opcional, JSON array de origens permitidas).
  - `RateLimit` (opcional, limite de chamadas).
  - `ExpiresAt` (opcional, data de expiração).
- O `CreatedBy` deve ser preenchido com o `Id` do usuário autenticado.

**Validações:**
- `Name` deve ser único no escopo do Tenant.
- `AllowedIps` e `AllowedOrigins`, se fornecidos, devem ser arrays JSON válidos.
- `RateLimit`, se fornecido, deve ser maior que zero.
- `ExpiresAt`, se fornecido, deve ser uma data futura.

**Resposta:**
- Retornar o `Key` gerado (texto puro) **apenas uma vez** na resposta.
- **O segredo não pode ser recuperado posteriormente.**

---

### 4.2 Listar ApiKeys (GET /v1/tenants/{tenantId}/api-keys)
**Contexto:** Permite visualizar as chaves configuradas no Tenant.

**Regras:**
- Retornar apenas chaves não deletadas (`IsDeleted = false`).
- Suportar filtros opcionais:
  - `IsActive`, `IsDeleted`, `Name`, `Code`, `CreatedAt`, `ExpiresAt`.
- Ordenação padrão: `CreatedAt DESC`.

**Projeção de dados:**
- **Nunca retornar o segredo da chave (`Key`) ou o hash (`KeyHash`).**
- Incluir apenas informações acessórias: 
  - `Id`, `Name`, `Code`, `KeyPrefix`, `UsageCount`, `ExpiresAt`, `RateLimit`, `LastUsedAt`.

**Permissões:**
- Apenas usuários com permissão de leitura de chaves podem listar.

---

### 4.3 Consultar ApiKey por ID (GET /v1/tenants/{tenantId}/api-keys/{id})
**Contexto:** Permite obter detalhes de uma chave específica.

**Regras:**
- Aplicar mesmos princípios de exclusão segura e projeção de dados.
- Retornar 404 se a chave não existir ou estiver deletada.

---

### 4.4 Atualizar ApiKey (PUT /v1/tenants/{tenantId}/api-keys/{id})
**Contexto:** Atualizar propriedades da chave existente.

**Campos alteráveis:**
- `Name`, `Scopes`, `AllowedIps`, `AllowedOrigins`, `RateLimit`, `ExpiresAt`, `IsActive`.

**Validações:**
- Não permitir alteração do segredo da chave (`Key`).
- Rejeitar alterações conflitantes de `Name`.

**Impactos:**
- Se `IsActive` for alterado para `false`, considerar revogação implícita.

---

### 4.5 Revogar ApiKey (PATCH /v1/tenants/{tenantId}/api-keys/{id}/revoke)
**Contexto:** Revogar o acesso fornecido por uma chave sem excluí-la.

**Regras:**
- Atualizar `RevokedAt` e `RevokedReason` com valores adequados.
- Definir `IsActive = false`.
- Registrar evento de auditoria.

---

### 4.6 Regenerar Segredo (POST /v1/tenants/{tenantId}/api-keys/{id}/regenerate-secret)
**Contexto:** Rotacionar o segredo de uma chave.

**Regras:**
- Gerar um novo segredo automaticamente.
- Atualizar o `KeyHash` com o hash do novo segredo.
- Invalidar imediatamente o segredo antigo.

---

### 4.7 Excluir ApiKey (DELETE /v1/tenants/{tenantId}/api-keys/{id})
**Contexto:** Excluir logicamente uma ApiKey.

**Regras:**
- Aplicar soft delete (`IsDeleted = true`).
- Atualizar `RevokedAt` se aplicável.
- Registrar auditoria da exclusão.

---

## 5. Segurança e Conformidade

### 5.1 Proteção do Segredo
- **Nunca armazenar o segredo em formato legível.**
- Sempre exibir o segredo apenas na criação ou rotação.

### 5.2 Restrições de Uso
- API deve validar:
  - Escopo da chave.
  - Origem da requisição.
  - IP do cliente.
  - Limites de taxa.

### 5.3 Auditoria e Monitoramento
- Registrar:
  - Uso de chaves (data, IP, origem, endpoint).
  - Alterações e revogações.
- Alertar em casos de abuso.

---

## 6. Conclusão
O módulo **ApiKeys** garante autenticação segura, flexível e auditável para integrações externas. Com as regras descritas, o sistema oferece controle granular e eficiente, reduzindo riscos de segurança sem sacrificar a simplicidade operacional.