# Documento de Regras de Negócio — Tenants

## 1. Introdução
Este documento descreve de forma detalhada as regras de negócio do módulo **Tenants** no sistema IAM (VianaID).

Um **Tenant** representa um cliente (empresa ou organização) da plataforma e é a unidade central de isolamento de dados, permissões, billing e governança.

---

## 2. Objetivos do Módulo de Tenants
- Representar clientes da plataforma.
- Garantir isolamento lógico e de dados (multi-tenant).
- Centralizar configurações, identidade e governança.
- Servir como base para usuários, aplicações, permissões e assinaturas.

---

## 3. Estrutura Geral do Tenant
Um **Tenant** contém:
- `Id`
- `Code` (código técnico gerado automaticamente pelo sistema)
- `Name`
- `Domain`
- `PlanId`
- Configurações (`Settings`, identidade visual, etc.)
- Indicadores de estado (`Status`, `IsActive`, `IsDeleted`)
- Dados de auditoria (`CreatedBy`, `CreatedAt`, `UpdatedBy`, `UpdatedAt`)

### 3.1 Regras do campo Code
- O campo **`Code` nunca é informado pelo usuário**.
- O campo **`Code` é imutável** e **nunca pode ser alterado** após a criação do Tenant.
- O `Code` é **gerado automaticamente pela aplicação**, utilizando o componente `CodeGenerator`.
- O formato do código segue obrigatoriamente o padrão:

```
<PREFIXO><YYMMDD><HASH>
```

Onde:
- **TENT**: prefixo fixo que identifica o recurso Tenant.
- **YYMMDD**: data UTC de geração do código.
- **HASH**: sequência alfanumérica aleatória de 4 caracteres.

**Exemplo válido:**
```
TENT251214XTG2
```

- A unicidade do `Code` é garantida pelo sistema.
- Qualquer tentativa de envio ou alteração manual do campo `Code` deve ser ignorada ou rejeitada pela API.

### 3.2 Escopo Multi-tenant
- O Tenant é a **unidade raiz de isolamento** da plataforma.
- Todas as entidades do sistema devem estar associadas a exatamente um Tenant.
- Operações devem respeitar o contexto do Tenant (TenantContext / RLS).

---

## 4. Regras de Negócio por Operação

### 4.1 Criar Tenant (POST /v1/tenants)
- O Tenant deve ser criado com um Plano válido.
- O campo `Code` é gerado automaticamente.
- Estado inicial:
  - `IsActive = true`
  - `IsDeleted = false`

### 4.2 Consultar Tenants (GET /v1/tenants)
- Devem ser retornados apenas Tenants não deletados.
- Consultas devem respeitar isolamento por Tenant.

### 4.3 Atualizar Tenant (PUT /v1/tenants/{id})
- O `Code` não pode ser alterado.
- Alterações de plano devem respeitar limites já utilizados.
- Alterações devem registrar auditoria.

### 4.4 Ativar Tenant (PATCH /v1/tenants/{id}/activate)
**Contexto:** Reativar um Tenant previamente desativado.

**Regras:**
- Só é permitido ativar um Tenant existente e não deletado.
- **O Tenant deve estar inativo** (`IsActive = false`) para ser ativado.
- Validar se o Plano associado ainda está ativo.
- Validar se há Subscription válida.
- Atualizar `IsActive = true`.
- Atualizar `UpdatedBy` e `UpdatedAt`.

**Validações:**
- O Tenant deve existir.
- O Tenant não pode estar deletado.
- **O Tenant não pode estar já ativo** - retorna erro 400 se tentar ativar um Tenant que já está ativo.
- O Plano associado deve estar ativo.
- Deve existir uma Subscription válida.
- A operação **não é idempotente** - valida o estado atual e retorna erro se já estiver no estado desejado.

**Motivo da validação explícita:**
- Evita chamadas desnecessárias ao banco de dados quando o Tenant já está ativo.
- Detecta bugs no cliente que fazem chamadas duplicadas.
- Melhora a performance ao fazer "early return" sem validar dependências desnecessariamente.
- Fornece feedback explícito sobre tentativas de operação inválidas.

**Auditoria:**
- Registrar ativação em `AuditLogs`.
- Incluir contexto do usuário que ativou.

---

### 4.5 Desativar Tenant (PATCH /v1/tenants/{id}/deactivate)
**Contexto:** Desativar um Tenant temporariamente.

**Regras:**
- **O Tenant deve estar ativo** (`IsActive = true`) para ser desativado.
- A desativação suspende acessos e operações do Tenant.
- Atualizar `IsActive = false`.
- Atualizar `UpdatedBy` e `UpdatedAt`.

**Validações:**
- O Tenant deve existir e estar ativo.
- **O Tenant não pode estar já inativo** - retorna erro 400 se tentar desativar um Tenant que já está inativo.
- Verificar se existem usuários, aplicações ou recursos ativos associados.
- Opcionalmente, impedir desativação se há operações críticas em andamento.
- A operação **não é idempotente** - valida o estado atual e retorna erro se já estiver no estado desejado.

**Motivo da validação explícita:**
- Evita chamadas desnecessárias ao banco de dados e verificação de dependências.
- Detecta bugs no cliente que fazem chamadas duplicadas.
- Melhora a performance ao fazer "early return" sem processar operação desnecessária.
- Fornece feedback explícito sobre tentativas de operação inválidas.

**Impacto:**
- Tenant desativado bloqueia todas as autenticações e autorizações.
- Todas as entidades associadas (Applications, Resources, Actions, Permissions, Roles) devem ser desativadas automaticamente.
- Considerar notificação de todos os usuários e administradores do Tenant.

**Auditoria:**
- Registrar desativação em `AuditLogs` com motivo (se fornecido).

---

## 5. Regras de Integridade e Dependência

### 5.1 Dependência obrigatória
- Todo Tenant deve possuir exatamente um Plano ativo.
- Todo Tenant deve possuir uma Subscription válida.

### 5.2 Consistência do Tenant
- Alterações no Tenant impactam todas as entidades associadas.

---

## 6. Regras de Governança e Segurança

### 6.1 Auditoria
- Toda operação relevante deve ser registrada.

### 6.2 Segurança
- A desativação de um Tenant deve bloquear autenticações e autorizações.

---

## 7. Regras Complementares
- Tenants raramente devem ter seu plano alterado sem impacto controlado.
- Mudanças estruturais exigem validação prévia.

---

## 8. Conclusão
O módulo **Tenants** é um pilar central do IAM VianaID.

As regras aqui definidas garantem isolamento, segurança, governança e previsibilidade para evolução da plataforma.
