# VianaID – ERD e Modelo de Identidade
## Documento Oficial de Arquitetura de Dados (Recriado do Zero)

---

## 1. Objetivo do Documento
Este documento define **o modelo oficial de dados (ERD – Entity Relationship Diagram)** do VianaID, servindo como **fonte única de verdade** para a implementação do banco de dados IAM.

Ele foi **recriado do zero** para:
- Eliminar ambiguidades arquiteturais
- Formalizar normas obrigatórias (auditoria e RLS)
- Garantir compatibilidade com auditorias enterprise
- Sustentar Zero Trust, multi-tenancy e compliance regulatório

Este documento deve ser tratado como **contrato arquitetural**, não como material explicativo opcional.

---

## 2. Princípios Fundamentais do Modelo de Identidade

1. **Identidade ≠ Usuário**
2. Identidade é a entidade central do sistema
3. Todos os dados são multi-tenant por padrão
4. Nenhum dado crítico é fisicamente apagado
5. Auditoria é obrigatória
6. Isolamento entre tenants é inegociável
7. Segurança deve existir mesmo com falha da aplicação

---

## 3. Normas Transversais Obrigatórias (CRÍTICAS)

Esta seção se aplica **a todas as entidades persistentes do VianaID**, exceto exceções explicitamente declaradas.

---

## 3.1 Norma Oficial de Campos de Auditoria

### 3.1.1 Campos Obrigatórios (Tabelas Mutáveis)

Todas as tabelas mutáveis DEVEM conter, obrigatoriamente:

```sql
IsActive   BIT NOT NULL DEFAULT 1,
CreatedBy UNIQUEIDENTIFIER NOT NULL,
CreatedAt DATETIME2 NOT NULL DEFAULT GETDATE(),
UpdatedBy UNIQUEIDENTIFIER NULL,
UpdatedAt DATETIME2 NULL
```

### 3.1.2 Regras Arquiteturais

- `CreatedBy` e `CreatedAt` são **imutáveis**
- `UpdatedBy` e `UpdatedAt` só podem ser alterados via UPDATE válido
- Exclusão lógica é feita **exclusivamente** via `IsActive = 0`
- **DELETE físico é proibido** em dados de domínio

---

## 3.2 Norma Oficial de Row-Level Security (RLS)

### 3.2.1 Escopo

Toda tabela que contenha `TenantId` DEVE estar protegida por **Row-Level Security nativo do SQL Server**.

### 3.2.2 Operações Protegidas (OBRIGATÓRIO)

O RLS deve ser aplicado para:

- SELECT (leitura)
- INSERT (before insert)
- UPDATE (before update)
- DELETE (before delete)

Nenhuma operação de escrita pode ocorrer fora do escopo do tenant.

### 3.2.3 Mecanismo Técnico

- O `TenantId` corrente DEVE ser resolvido via:

```sql
SESSION_CONTEXT('TenantId')
```

- O contexto DEVE ser definido no início de toda conexão
- O banco **não pode confiar na aplicação** para isolamento

### 3.2.4 Consequências

- INSERT com TenantId diferente → bloqueado
- UPDATE cross-tenant → bloqueado
- DELETE cross-tenant → bloqueado
- SELECT cross-tenant → bloqueado

RLS é tratado como **defesa em profundidade obrigatória**.

---

## 3.3 Entidades Append-Only (Exceções Formais)

As seguintes entidades são **imutáveis por definição**:

| Entidade | Justificativa |
|--------|---------------|
| AuditEvent | Trilha forense |
| Session | Histórico temporal |
| AuthCode / Token | Efêmero |
| EventStore | Integridade de eventos |

Essas entidades:
- Não possuem `UpdatedBy` / `UpdatedAt`
- Não sofrem UPDATE ou DELETE

---

## 4. Domínios do Modelo de Dados

O ERD do VianaID é dividido nos seguintes domínios:

1. Core Identity
2. Perfil Humano
3. Credenciais
4. Dispositivos
5. Sessões
6. Autorização (RBAC + ABAC)
7. Acesso Privilegiado (PAM)
8. Auditoria

---

## 5. Entidade Central – Identity

### 5.1 Finalidade

Representar qualquer ator autenticável:
- Usuário humano
- Conta de serviço
- Identidade técnica

### 5.2 Atributos

- IdentityId (PK)
- TenantId (FK)
- IdentityType
- Status
- IsActive
- CreatedBy
- CreatedAt
- UpdatedBy
- UpdatedAt

### 5.3 Relacionamentos

- 1:N Credential
- 1:N Device
- 1:N Session
- 1:N RoleAssignment
- 1:1 Person (opcional)

---

## 6. Perfil Humano – Person

### 6.1 Responsabilidade

Armazenar dados civis e pessoais, separados da identidade lógica.

### 6.2 Atributos

- PersonId (PK)
- TenantId (FK)
- IdentityId (FK)
- LegalName
- PreferredName
- Locale
- IsActive
- CreatedBy
- CreatedAt
- UpdatedBy
- UpdatedAt

---

## 7. Credenciais – Credential

### 7.1 Princípios

- Múltiplas credenciais por identidade
- Passwordless como padrão
- Revogação imediata

### 7.2 Atributos

- CredentialId (PK)
- TenantId (FK)
- IdentityId (FK)
- CredentialType
- SecretHash / PublicKey
- IsPrimary
- IsRevoked
- ExpiresAt
- IsActive
- CreatedBy
- CreatedAt
- UpdatedBy
- UpdatedAt

---

## 8. Dispositivos – Device

### 8.1 Papel

Dispositivo é entidade de primeira classe no Zero Trust.

### 8.2 Atributos

- DeviceId (PK)
- TenantId (FK)
- IdentityId (FK)
- DeviceType
- OperatingSystem
- TrustLevel
- IsManaged
- LastSeenAt
- IsActive
- CreatedBy
- CreatedAt
- UpdatedBy
- UpdatedAt

---

## 9. Sessões – Session (Append-Only)

### 9.1 Natureza

Sessões representam contexto temporal e são imutáveis.

### 9.2 Atributos

- SessionId (PK)
- TenantId (FK)
- IdentityId (FK)
- DeviceId (FK)
- IpAddress
- GeoLocation
- RiskScore
- StartedAt
- EndedAt

---

## 10. Autorização – RBAC

### 10.1 Role

- RoleId (PK)
- TenantId (FK)
- Name
- Description
- IsActive
- CreatedBy
- CreatedAt
- UpdatedBy
- UpdatedAt

### 10.2 RoleAssignment

- RoleAssignmentId (PK)
- TenantId (FK)
- RoleId (FK)
- IdentityId (FK)
- Scope
- AssignedAt
- IsActive
- CreatedBy
- CreatedAt
- UpdatedBy
- UpdatedAt

---

## 11. Autorização – ABAC (Policy)

- PolicyId (PK)
- TenantId (FK)
- Name
- Expression
- Effect
- Priority
- IsActive
- CreatedBy
- CreatedAt
- UpdatedBy
- UpdatedAt

---

## 12. Acesso Privilegiado – PAM

- PrivilegedAccessId (PK)
- TenantId (FK)
- IdentityId (FK)
- RoleId (FK)
- ApprovedBy
- ValidFrom
- ValidTo
- IsActive
- CreatedBy
- CreatedAt

---

## 13. Auditoria – AuditEvent (Append-Only)

- AuditEventId (PK)
- TenantId (FK)
- IdentityId (FK)
- Action
- Resource
- Result
- Timestamp
- Metadata (JSON)

---

## 14. Normalização e Integridade

- Modelo em 4NF / 5NF
- Nenhuma permissão direta em usuário
- Todas as permissões são indiretas

---

## 15. Conclusão

Este ERD define uma base:
- Segura por padrão
- Auditável
- Multi-tenant
- Preparada para Zero Trust e compliance

Ele deve ser seguido **sem exceções** em toda implementação do VianaID.

**Fim do Documento**