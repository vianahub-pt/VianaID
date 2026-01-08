# VianaID – Arquitetura Multi-Tenant
## Documento Oficial de Arquitetura de Isolamento e Segurança

---

## 1. Objetivo do Documento
Este documento define a **arquitetura oficial multi-tenant do VianaID**, estabelecendo de forma **normativa e inequívoca** como ocorre o isolamento de dados, identidades e operações entre tenants.

- Eliminar qualquer ambiguidade sobre isolamento entre tenants
- Formalizar o Tenant como **fronteira de segurança**
- Tornar o Row-Level Security (RLS) um **mecanismo obrigatório e completo**
- Garantir conformidade com auditorias enterprise e requisitos regulatórios

Este documento deve ser tratado como **contrato arquitetural de segurança**.

---

## 2. Princípios Fundamentais de Multi-Tenancy

1. **Tenant é fronteira de segurança, não apenas de organização**
2. Nenhum dado pode ser acessado fora do tenant
3. Nenhuma operação de escrita pode cruzar tenants
4. A aplicação não é confiável por si só
5. Isolamento deve existir mesmo com falha de código
6. Defesa em profundidade é obrigatória

---

## 3. Definição de Tenant no VianaID

### 3.1 Conceito

Um **Tenant** representa uma entidade administrativa isolada, como:
- Empresa
- Organização
- Unidade governamental
- Ambiente soberano

Cada tenant possui:
- Identidades próprias
- Políticas próprias
- Dispositivos próprios
- Governança própria

---

### 3.2 Tenant NÃO é

- Usuário
- Grupo
- Aplicação
- Ambiente lógico compartilhado

Tenant é **boundary técnico e jurídico**.

---

## 4. TenantId como Atributo Transversal

### 4.1 Regra Obrigatória

Toda entidade persistente que represente dado de domínio **DEVE** conter:

- `TenantId UNIQUEIDENTIFIER NOT NULL`

Sem exceções, exceto entidades globais explicitamente declaradas.

---

### 4.2 Entidades Tenant-Aware

Exemplos (não exaustivo):
- Identity
- Person
- Credential
- Device
- Session
- Role
- RoleAssignment
- Policy
- PrivilegedAccess
- ClientApplication
- ConnectorConfig
- AuditEvent

---

## 5. Estratégia Oficial de Isolamento

O VianaID adota **isolamento lógico forte**, composto por três camadas:

1. Isolamento na aplicação
2. Isolamento no banco de dados (RLS)
3. Isolamento operacional e organizacional

Este documento trata **principalmente da camada de banco de dados**.

---

## 6. Row-Level Security (RLS) – Norma Obrigatória

### 6.1 Escopo de Aplicação

Toda tabela que contenha `TenantId` **DEVE** estar protegida por **Row-Level Security nativo do SQL Server**.

Não existe exceção para dados de domínio.

---

### 6.2 Operações Protegidas (CRÍTICO)

O RLS deve ser aplicado **a todas as operações DML**, sem exceção:

- **SELECT** → leitura
- **INSERT** → AFTER INSERT (bloqueio se TenantId inválido)
- **UPDATE** → AFTER UPDATE (bloqueio se TenantId inválido)
- **DELETE** → BEFORE DELETE (bloqueio se TenantId inválido)

Nenhuma operação pode:
- Inserir dados em outro tenant
- Alterar dados de outro tenant
- Remover dados de outro tenant

---

### 6.3 Mecanismo Técnico Obrigatório

O Tenant corrente **DEVE** ser definido no início de toda sessão:

```sql
EXEC sys.sp_set_session_context @key = N'TenantId', @value = @TenantId;
```

O banco de dados **não confia** em parâmetros enviados pela aplicação.

---

### 6.4 Predicados Técnicos

O isolamento é garantido por:

- **FILTER PREDICATE** → SELECT
- **BLOCK PREDICATE** → INSERT, UPDATE, DELETE

Baseados exclusivamente em:

```sql
SESSION_CONTEXT('TenantId')
```

---

## 7. Fluxo de Resolução de Tenant

### 7.1 Origem do TenantId

O TenantId é resolvido a partir de:
- Token OAuth/OIDC
- Assertion SAML
- Certificado de cliente (mTLS)

---

### 7.2 Propagação

- Middleware resolve o TenantId
- TenantId é injetado no SESSION_CONTEXT
- Todas as operações subsequentes herdam o contexto

---

## 8. Escrita e Mutação de Dados

### 8.1 Regra de Ouro

> **Nenhuma operação de escrita pode confiar apenas no código da aplicação.**

Todas as mutações são validadas pelo RLS.

---

### 8.2 Exemplos de Bloqueio

- INSERT com TenantId diferente do contexto → bloqueado
- UPDATE cross-tenant → bloqueado
- DELETE cross-tenant → bloqueado

---

## 9. Entidades Append-Only e Multi-Tenant

Entidades append-only (ex: AuditEvent, Session):
- Ainda possuem TenantId
- Ainda estão sob RLS
- Não sofrem UPDATE ou DELETE

RLS continua protegendo INSERT e SELECT.

---

## 10. Auditoria e Multi-Tenancy

- Todos os eventos possuem TenantId
- Auditorias são isoladas por tenant
- Exportação e retenção são tenant-aware

---

## 11. Impacto no Decision Engine e IAM

- Contexto de tenant sempre presente
- Policies nunca cruzam tenants
- Sessões nunca cruzam tenants
- Risco é calculado por tenant

---

## 12. Segurança e Compliance

Esta arquitetura garante conformidade com:
- LGPD / GDPR (isolamento de dados)
- SOX (controle de acesso)
- ISO 27001 (segurança de informação)

Violação de tenant é considerada **falha crítica de segurança**.

---

## 13. Considerações Operacionais

- RLS é monitorado
- Tentativas de violação são auditadas
- Logs de bloqueio são eventos de segurança

---

## 14. Conclusão

A arquitetura multi-tenant do VianaID:
- Trata Tenant como fronteira de segurança
- Garante isolamento absoluto
- Não depende da aplicação
- Protege leitura e escrita

Este documento deve ser seguido **sem exceções** em qualquer implantação do VianaID.

**Fim do Documento**

