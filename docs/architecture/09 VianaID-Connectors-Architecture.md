# VianaID – Arquitetura de Conectores
## Documento Oficial de Integração, Sincronização e Federação

---

## 1. Objetivo do Documento
Este documento define a **arquitetura oficial de Conectores do VianaID**, responsável por integrar **diretórios externos, provedores de identidade e aplicações SaaS**, mantendo o VianaID como **autoridade central de decisão e governança**.

Ele foi **recriado do zero** para:
- Garantir coerência total com o ERD e o Schema SQL Server Core IAM
- Formalizar auditoria e Row-Level Security (RLS) como normas obrigatórias
- Eliminar ambiguidades sobre sincronização, federação e isolamento multi-tenant
- Sustentar integrações enterprise com segurança e rastreabilidade

Este documento é **normativo** e deve ser seguido sem exceções.

---

## 2. Princípios Fundamentais da Arquitetura de Conectores

1. **VianaID é a autoridade de decisão**
2. Sistemas externos nunca decidem acesso
3. Conectores são adaptadores, não fontes de verdade
4. Falha de conector não compromete o core IAM
5. Isolamento entre tenants é obrigatório
6. Auditoria e rastreabilidade são exigidas

---

## 3. Papel dos Conectores no Ecossistema VianaID

Os conectores permitem ao VianaID:
- Centralizar identidades de múltiplas fontes
- Sincronizar usuários, grupos e atributos
- Federar autenticação (OIDC / SAML)
- Automatizar onboarding e offboarding
- Aplicar governança uniforme

> **Nenhum sistema externo possui autoridade direta sobre permissões no VianaID.**

---

## 4. Normas Transversais Aplicáveis aos Conectores

Este domínio herda integralmente as normas definidas em:
- ERD e Modelo de Identidade
- Schema SQL Server Core IAM
- Arquitetura Multi-Tenant

Em especial:
- Campos de auditoria obrigatórios
- Soft delete (`IsActive`)
- Proibição de DELETE físico
- RLS aplicado a leitura e escrita

---

## 5. Multi-Tenancy e Isolamento de Conectores

### 5.1 Regra Obrigatória

Toda entidade persistente relacionada a conectores **DEVE** conter `TenantId` e estar protegida por **Row-Level Security (RLS)** nativo do SQL Server.

---

### 5.2 Operações Protegidas por RLS (CRÍTICO)

O RLS deve ser aplicado a **todas as operações DML**:

- **SELECT** → FILTER PREDICATE
- **INSERT** → BLOCK PREDICATE (AFTER INSERT)
- **UPDATE** → BLOCK PREDICATE (AFTER UPDATE)
- **DELETE** → BLOCK PREDICATE (BEFORE DELETE)

Nenhuma configuração, credencial ou mapeamento pode ser criado ou alterado fora do tenant correto.

---

## 6. Componentes da Arquitetura de Conectores

```
[Sistema Externo]
        ↓
[Connector Adapter]
        ↓
[Connector Engine]
        ↓
[Mapping & Normalization]
        ↓
[Core IAM VianaID]
```

O Connector Engine **orquestra**, mas nunca decide acesso.

---

## 7. Entidades do Domínio de Conectores

### 7.1 Connector

#### Finalidade
Representar um conector configurado para um sistema externo.

#### Atributos
- ConnectorId (PK)
- TenantId (FK)
- ConnectorType (EntraID, AD, LDAP, Google, SaaS)
- Name
- Status
- LastSyncAt
- IsActive
- CreatedBy
- CreatedAt
- UpdatedBy
- UpdatedAt

---

### 7.2 ConnectorCredential

#### Finalidade
Armazenar credenciais necessárias para comunicação com sistemas externos.

#### Atributos
- ConnectorCredentialId (PK)
- TenantId (FK)
- ConnectorId (FK)
- CredentialType
- EncryptedSecret
- RotationPolicy
- LastRotatedAt
- IsActive
- CreatedBy
- CreatedAt
- UpdatedBy
- UpdatedAt

---

### 7.3 ConnectorMapping

#### Finalidade
Definir o mapeamento de atributos externos para o modelo interno do VianaID.

#### Atributos
- ConnectorMappingId (PK)
- TenantId (FK)
- ConnectorId (FK)
- ExternalAttribute
- InternalAttribute
- TransformationRule
- IsActive
- CreatedBy
- CreatedAt
- UpdatedBy
- UpdatedAt

---

### 7.4 ConnectorSyncJob

#### Finalidade
Registrar execuções de sincronização.

#### Atributos
- ConnectorSyncJobId (PK)
- TenantId (FK)
- ConnectorId (FK)
- SyncType (Full / Incremental / Event)
- Status
- StartedAt
- FinishedAt
- TriggeredBy

**Entidade append-only** (não sofre UPDATE nem DELETE).

---

### 7.5 ConnectorEvent (Append-Only)

#### Finalidade
Registrar eventos relevantes de integração.

#### Atributos
- ConnectorEventId (PK)
- TenantId (FK)
- ConnectorId (FK)
- EventType
- Payload (JSON)
- OccurredAt

---

## 8. Sincronização de Identidades

### 8.1 Modos de Sincronização

- Full Sync (inicial)
- Incremental Sync
- Event-driven (quando suportado)

---

### 8.2 Regras de Sincronização

- Dados externos são validados
- Mapeamento explícito é obrigatório
- Nenhum atributo é aceito implicitamente

---

## 9. Provisionamento e Deprovisionamento

### 9.1 Onboarding

- Criação de Identity
- Associação a roles iniciais
- Aplicação de policies

---

### 9.2 Offboarding

- Desativação imediata (`IsActive = 0`)
- Revogação de sessões
- Atualização de governança

---

## 10. Segurança dos Conectores

- Credenciais criptografadas em repouso
- Rotação periódica
- Least privilege
- Comunicação segura (TLS / mTLS)

---

## 11. Auditoria e Monitoramento

- Toda mutação gera AuditEvent
- Falhas são eventos de segurança
- Tentativas cross-tenant são críticas

---

## 12. Impacto no Decision Engine e IAM

- Dados sincronizados alimentam contexto
- Policies continuam centralizadas
- Sistemas externos não influenciam decisões

---

## 13. Considerações de Implementação

- Conectores como plugins isolados
- Escala horizontal
- Retry com backoff
- Circuit breaker

---

## 14. Conclusão

A arquitetura de Conectores do VianaID:
- Centraliza identidades externas
- Mantém isolamento absoluto entre tenants
- Aplica auditoria e RLS completos
- Sustenta integrações enterprise com segurança

Este documento define o **contrato definitivo** para integrações no VianaID.

**Fim do Documento**

