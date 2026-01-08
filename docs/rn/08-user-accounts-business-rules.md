# Documento de Regras de Negócio — UserAccounts

## 1. Introdução
Este documento descreve de forma detalhada as regras de negócio do módulo **UserAccounts** no sistema IAM (VianaID).

Um **UserAccount** representa um usuário individual vinculado a um Tenant, sendo a entidade central para autenticação, MFA, controle de acesso e auditoria.

---

## 2. Objetivos do Módulo de UserAccounts
- Gerenciar identidade de usuários por Tenant.
- Garantir autenticação segura (hashing de senhas, lockout, MFA).
- Suportar MFA (e-mail OTP, TOTP, códigos de backup).
- Registrar telemetria de login e auditoria.
- Integrar provedores externos (OAuth/OIDC).

---

## 3. Estrutura Geral do UserAccount
Um **UserAccount** contém:
- `Id`
- `TenantId`
- `Code` (código técnico gerado automaticamente pelo sistema)
- `Name`
- `Email` e `NormalizedEmail`
- `PasswordHash` e `SecurityStamp`
- Indicadores de verificação (`EmailConfirmed`, `PhoneNumberConfirmed`)
- MFA (`TwoFactorEnabled`, `MFAType`)
- Integração externa (`ExternalProvider`, `ExternalId`)
- Segurança operacional (`LastLoginAt`, `LockoutEnd`, `AccessFailedCount`)
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
- **USER**: prefixo fixo que identifica o recurso UserAccount.
- **YYMMDD**: data UTC de geração do código.
- **HASH**: sequência alfanumérica aleatória de 4 caracteres.

**Exemplo válido:**
```
USER251214XTG2
```

- A unicidade do `Code` é garantida pelo sistema.
- Qualquer tentativa de envio ou alteração manual do campo `Code` deve ser ignorada ou rejeitada pela API.

### 3.2 Escopo Multi-tenant
- Todo UserAccount pertence exatamente a um Tenant.
- Consultas e operações devem respeitar Row-Level Security (RLS).

---

## 4. Regras de Negócio por Operação

### 4.1 Criar Usuário (POST /v1/tenants/{tenantId}/users)
- O usuário é criado com `IsActive = true` e `IsDeleted = false`.
- O campo `Code` é gerado automaticamente.
- O e-mail é obrigatório e deve ser normalizado.
- A senha deve ser armazenada apenas como hash.

### 4.2 Consultar Usuários (GET /v1/tenants/{tenantId}/users)
- Devem ser retornados apenas usuários não deletados.
- Aplicar filtros por status e paginação.

### 4.3 Atualizar Usuário (PUT /v1/tenants/{tenantId}/users/{id})
- O `Code` não pode ser alterado.
- Alterações críticas devem renovar `SecurityStamp`.

### 4.4 Ativar Usuário (PATCH /v1/tenants/{tenantId}/users/{id}/activate)
**Contexto:** Reativar um usuário previamente desativado.

**Regras:**
- Só é permitido ativar um usuário existente, não deletado e pertencente ao Tenant.
- **O usuário deve estar inativo** (`IsActive = false`) para ser ativado.
- Validar se o Tenant ainda está ativo.
- Atualizar `IsActive = true`.
- Atualizar `UpdatedBy` e `UpdatedAt`.

**Validações:**
- O usuário deve existir e pertencer ao Tenant.
- O usuário não pode estar deletado.
- **O usuário não pode estar já ativo** - retorna erro 400 se tentar ativar um usuário que já está ativo.
- O Tenant associado deve estar ativo.
- A operação **não é idempotente** - valida o estado atual e retorna erro se já estiver no estado desejado.

**Motivo da validação explícita:**
- Evita chamadas desnecessárias ao banco de dados quando o usuário já está ativo.
- Detecta bugs no cliente que fazem chamadas duplicadas.
- Melhora a performance ao fazer "early return" sem validar dependências desnecessariamente.
- Fornece feedback explícito sobre tentativas de operação inválidas.

**Auditoria:**
- Registrar ativação em `AuditLogs`.
- Incluir contexto do usuário administrativo que ativou.

---

### 4.5 Desativar Usuário (PATCH /v1/tenants/{tenantId}/users/{id}/deactivate)
**Contexto:** Desativar um usuário temporariamente.

**Regras:**
- **O usuário deve estar ativo** (`IsActive = true`) para ser desativado.
- Usuário desativado não pode iniciar novas sessões.
- Sessões ativas podem ser invalidadas (dependendo da configuração).
- Atualizar `IsActive = false`.
- Atualizar `UpdatedBy` e `UpdatedAt`.

**Validações:**
- O usuário deve existir, pertencer ao Tenant e estar ativo.
- **O usuário não pode estar já inativo** - retorna erro 400 se tentar desativar um usuário que já está inativo.
- A operação **não é idempotente** - valida o estado atual e retorna erro se já estiver no estado desejado.

**Motivo da validação explícita:**
- Evita chamadas desnecessárias ao banco de dados e verificação de sessões.
- Detecta bugs no cliente que fazem chamadas duplicadas.
- Melhora a performance ao fazer "early return" sem processar operação desnecessária.
- Fornece feedback explícito sobre tentativas de operação inválidas.

**Impacto:**
- Usuário desativado não pode fazer login ou renovar tokens.
- Considerar invalidação de sessões e tokens ativos.
- Notificar o usuário sobre a desativação (se configurado).

**Auditoria:**
- Registrar desativação em `AuditLogs` com motivo (se fornecido).
- Incluir contexto do usuário administrativo que desativou.

---

## 5. Regras de Autenticação e MFA
- Login com senha exige usuário ativo e não deletado.
- Incrementar contador de falhas e aplicar lockout quando necessário.
- MFA via e-mail OTP ou TOTP deve seguir política de tentativas e expiração.

---

## 6. Sessões e Tokens
- Criar registro em UserSessions com hash do refresh token.
- Renovação de tokens deve validar sessão ativa.

---

## 7. Regras de Integridade e Dependência
- Associação obrigatória a um Tenant ativo.
- Respeitar limites do plano (ex.: número máximo de usuários).

---

## 8. Governança e Segurança
- Registrar auditoria em operações críticas.
- Nunca armazenar dados sensíveis em claro.
- Aplicar RLS em todas as consultas.

---

## 9. Conclusão
O módulo **UserAccounts** é essencial para identidade, autenticação e autorização no IAM VianaID. As regras aqui definidas garantem segurança, consistência e escalabilidade.
