# VianaID – Schema SQL Server Core IAM
## Documento Oficial de Implementação de Banco de Dados (Contrato Técnico Definitivo)

---

## 1. Objetivo do Documento

Este documento define **de forma explícita, completa e não ambígua** o **schema oficial do banco de dados SQL Server do VianaID**.

Ele é o **contrato técnico definitivo** para:
- Engenheiros backend
- DBAs
- Arquitetos de segurança
- Auditores

❗ **Nenhuma tabela, relacionamento, índice ou regra de segurança é implícita.**
Tudo que existe no banco **está declarado aqui**.

---

## 2. Princípios Arquiteturais do Schema

1. SQL Server é a **última linha de defesa**
2. Multi-tenancy é obrigatório
3. Auditoria é estrutural
4. DELETE físico é proibido
5. Soft delete é padrão
6. RLS protege **leitura e escrita**
7. Segurança não depende da aplicação

---

## 3. Normas Transversais Obrigatórias

### 3.1 Campos de Auditoria (Tabelas Mutáveis)

```sql
IsActive   BIT NOT NULL DEFAULT 1,
CreatedBy UNIQUEIDENTIFIER NOT NULL,
CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
UpdatedBy UNIQUEIDENTIFIER NULL,
UpdatedAt DATETIME2 NULL
```

**Regras:**
- `Created*` são imutáveis
- DELETE físico proibido
- Exclusão lógica via `IsActive = 0`

---

### 3.2 Row-Level Security (RLS) – Norma Obrigatória

RLS é aplicado a **todas as tabelas com TenantId**, protegendo:

- SELECT → FILTER PREDICATE
- INSERT → BLOCK PREDICATE (AFTER INSERT)
- UPDATE → BLOCK PREDICATE (AFTER UPDATE)
- DELETE → BLOCK PREDICATE (BEFORE DELETE)

Baseado exclusivamente em:

```sql
SESSION_CONTEXT('TenantId')
```

---

## 4. Infraestrutura de Segurança (RLS)

### 4.1 Função de Predicado

```sql
CREATE FUNCTION security.fn_TenantPredicate (@TenantId UNIQUEIDENTIFIER)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN SELECT 1 AS Allowed
WHERE @TenantId = CAST(SESSION_CONTEXT(N'TenantId') AS UNIQUEIDENTIFIER);
```

---

### 4.2 Política de Segurança (Modelo)

```sql
CREATE SECURITY POLICY security.TenantIsolationPolicy
ADD FILTER PREDICATE security.fn_TenantPredicate(TenantId)
    ON dbo.Identity,
ADD BLOCK PREDICATE security.fn_TenantPredicate(TenantId)
    ON dbo.Identity AFTER INSERT,
ADD BLOCK PREDICATE security.fn_TenantPredicate(TenantId)
    ON dbo.Identity AFTER UPDATE,
ADD BLOCK PREDICATE security.fn_TenantPredicate(TenantId)
    ON dbo.Identity BEFORE DELETE
WITH (STATE = ON);
```

⚠️ **Esta policy deve ser aplicada a TODAS as tabelas com TenantId.**

---

## 5. Tabelas Core IAM (Explícitas)

---

### 5.1 Tenant

```sql
CREATE TABLE dbo.Tenant (
    TenantId UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
    Name NVARCHAR(200) NOT NULL,
    Status INT NOT NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    IsDeleted BIT NOT NULL DEFAULT 0,
    CreatedBy UNIQUEIDENTIFIER NOT NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedBy UNIQUEIDENTIFIER NULL,
    UpdatedAt DATETIME2 NULL
);
```

Índices:
- PK(TenantId)

---

### 5.2 Identity

```sql
CREATE TABLE dbo.Identity (
    IdentityId UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
    TenantId UNIQUEIDENTIFIER NOT NULL,
    IdentityType INT NOT NULL,
    Status INT NOT NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    IsDeleted BIT NOT NULL DEFAULT 0,
    CreatedBy UNIQUEIDENTIFIER NOT NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedBy UNIQUEIDENTIFIER NULL,
    UpdatedAt DATETIME2 NULL,
    CONSTRAINT FK_Identity_Tenant FOREIGN KEY (TenantId) REFERENCES dbo.Tenant(TenantId)
);
```

Índices:
```sql
CREATE INDEX IX_Identity_Tenant ON dbo.Identity (TenantId);
```

---

### 5.3 Person

```sql
CREATE TABLE dbo.Person (
    PersonId UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
    TenantId UNIQUEIDENTIFIER NOT NULL,
    IdentityId UNIQUEIDENTIFIER NOT NULL,
    LegalName NVARCHAR(200) NOT NULL,
    PreferredName NVARCHAR(200) NULL,
    Locale NVARCHAR(20) NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    IsDeleted BIT NOT NULL DEFAULT 0,
    CreatedBy UNIQUEIDENTIFIER NOT NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedBy UNIQUEIDENTIFIER NULL,
    UpdatedAt DATETIME2 NULL,
    CONSTRAINT FK_Person_Tenant FOREIGN KEY (TenantId) REFERENCES dbo.Tenant(TenantId),
    CONSTRAINT FK_Person_Identity FOREIGN KEY (IdentityId) REFERENCES dbo.Identity(IdentityId)
);
```

Índices:
```sql
CREATE INDEX IX_Person_Tenant ON dbo.Person (TenantId);
CREATE UNIQUE INDEX UX_Person_Identity ON dbo.Person (IdentityId);
```

---

### 5.4 Credential

```sql
CREATE TABLE dbo.Credential (
    CredentialId UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
    TenantId UNIQUEIDENTIFIER NOT NULL,
    IdentityId UNIQUEIDENTIFIER NOT NULL,
    CredentialType INT NOT NULL,
    SecretHash VARBINARY(MAX) NULL,
    PublicKey VARBINARY(MAX) NULL,
    IsPrimary BIT NOT NULL,
    IsRevoked BIT NOT NULL DEFAULT 0,
    ExpiresAt DATETIME2 NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    IsDeleted BIT NOT NULL DEFAULT 0,
    CreatedBy UNIQUEIDENTIFIER NOT NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedBy UNIQUEIDENTIFIER NULL,
    UpdatedAt DATETIME2 NULL,
    CONSTRAINT FK_Credential_Tenant FOREIGN KEY (TenantId) REFERENCES dbo.Tenant(TenantId),
    CONSTRAINT FK_Credential_Identity FOREIGN KEY (IdentityId) REFERENCES dbo.Identity(IdentityId)
);
```

Índices:
```sql
CREATE INDEX IX_Credential_Tenant ON dbo.Credential (TenantId);
CREATE INDEX IX_Credential_Identity ON dbo.Credential (IdentityId);
```

---

## 6. Entidades Append-Only (Explícitas)

### 6.1 Session

```sql
CREATE TABLE dbo.Session (
    SessionId UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
    TenantId UNIQUEIDENTIFIER NOT NULL,
    IdentityId UNIQUEIDENTIFIER NOT NULL,
    DeviceId UNIQUEIDENTIFIER NULL,
    IpAddress NVARCHAR(45) NOT NULL,
    RiskScore INT NOT NULL,
    StartedAt DATETIME2 NOT NULL,
    EndedAt DATETIME2 NULL,
    CONSTRAINT FK_Session_Tenant FOREIGN KEY (TenantId) REFERENCES dbo.Tenant(TenantId)
);
```

---

### 6.2 AuditEvent

```sql
CREATE TABLE dbo.AuditEvent (
    AuditEventId UNIQUEIDENTIFIER NOT NULL PRIMARY KEY,
    TenantId UNIQUEIDENTIFIER NOT NULL,
    IdentityId UNIQUEIDENTIFIER NULL,
    Action NVARCHAR(200) NOT NULL,
    Resource NVARCHAR(200) NOT NULL,
    Result NVARCHAR(50) NOT NULL,
    OccurredAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    Metadata NVARCHAR(MAX) NULL
);
```

---

## 7. Índices e Performance (Obrigatório)

- Todo FK possui índice
- Índices compostos por `(TenantId, FK)`
- Preparado para particionamento por TenantId

---

## 8. Proibições Explícitas

❌ Views sem RLS
❌ DELETE físico
❌ Bypass de SESSION_CONTEXT
❌ Cross-tenant joins

---

## 9. Conclusão

Este documento:
- Não contém tabelas implícitas
- Não permite interpretação ambígua
- É auditável
- É implementável sem decisões locais

Ele define **o único schema válido** para o VianaID.

**Fim do Documento**

