# VianaID – MDM / UEM Nativo (Device Trust e Compliance)
## Documento Oficial de Arquitetura de Dispositivos (Recriado do Zero)

---

## 1. Objetivo do Documento
Este documento define a **arquitetura oficial de MDM / UEM nativo do VianaID**, tratando **dispositivos como entidades de primeira classe** dentro do modelo Zero Trust.

Ele foi **recriado do zero** para:
- Garantir coerência total com o ERD e o Schema SQL Server
- Formalizar auditoria e Row-Level Security (RLS) como normas obrigatórias
- Eliminar qualquer ambiguidade sobre isolamento multi-tenant
- Sustentar decisões de acesso baseadas em **device trust contínuo**

Este documento é **normativo** e deve ser seguido sem exceções.

---

## 2. Princípios Fundamentais do MDM / UEM no VianaID

1. **Dispositivo é entidade de segurança**
2. Identidade sem dispositivo confiável não é Zero Trust
3. Confiança em dispositivo é dinâmica e revogável
4. Compliance é contínuo, não pontual
5. Nenhuma decisão depende apenas da aplicação
6. Auditoria e isolamento são obrigatórios

---

## 3. Papel do MDM / UEM na Arquitetura VianaID

O MDM / UEM nativo fornece **sinais de confiança de dispositivo** que alimentam:
- Decision Engine (ABAC)
- Risk Engine
- MFA adaptativo
- Revogação de sessões

O MDM **não decide acesso sozinho**, ele fornece contexto confiável.

---

## 4. Normas Transversais Aplicáveis ao Domínio de Dispositivos

Este domínio herda **integralmente** as normas definidas em:
- ERD e Modelo de Identidade
- Schema SQL Server Core IAM
- Arquitetura Multi-Tenant

Em especial:
- Campos de auditoria obrigatórios
- Soft delete (`IsActive`)
- RLS para leitura e escrita

---

## 5. Multi-Tenancy e Isolamento de Dispositivos

### 5.1 Regra Obrigatória

Toda entidade de dispositivo **DEVE** conter `TenantId` e estar protegida por **RLS nativo do SQL Server**.

---

### 5.2 Operações Protegidas por RLS (CRÍTICO)

O RLS deve ser aplicado às seguintes operações:

- **SELECT** → FILTER PREDICATE
- **INSERT** → BLOCK PREDICATE (AFTER INSERT)
- **UPDATE** → BLOCK PREDICATE (AFTER UPDATE)
- **DELETE** → BLOCK PREDICATE (BEFORE DELETE)

Nenhuma operação de mutação pode ocorrer fora do tenant correto.

---

## 6. Entidades do Domínio MDM / UEM

### 6.1 Device

#### Finalidade
Representar um dispositivo físico ou virtual associado a uma identidade.

#### Atributos
- DeviceId (PK)
- TenantId (FK)
- IdentityId (FK)
- DeviceType
- OperatingSystem
- OsVersion
- TrustLevel (0–100)
- IsManaged
- EnrollmentStatus
- LastSeenAt
- IsActive
- CreatedBy
- CreatedAt
- UpdatedBy
- UpdatedAt

---

### 6.2 DeviceEnrollment

#### Finalidade
Registrar o processo de associação inicial do dispositivo.

#### Atributos
- DeviceEnrollmentId (PK)
- TenantId (FK)
- DeviceId (FK)
- EnrollmentMethod
- EnrollmentStatus
- EnrolledAt
- IsActive
- CreatedBy
- CreatedAt
- UpdatedBy
- UpdatedAt

---

### 6.3 DeviceCompliance

#### Finalidade
Armazenar o estado atual de compliance do dispositivo.

#### Atributos
- DeviceComplianceId (PK)
- TenantId (FK)
- DeviceId (FK)
- PolicyId (FK)
- ComplianceStatus
- LastEvaluatedAt
- IsActive
- CreatedBy
- CreatedAt
- UpdatedBy
- UpdatedAt

---

### 6.4 DeviceSignal (Append-Only)

#### Finalidade
Registrar sinais coletados do dispositivo para análise de risco.

#### Características
- Entidade append-only
- Não sofre UPDATE nem DELETE

#### Atributos
- DeviceSignalId (PK)
- TenantId (FK)
- DeviceId (FK)
- SignalType
- SignalValue
- CollectedAt

---

## 7. Compliance de Dispositivos

### 7.1 Políticas de Compliance

Exemplos:
- Versão mínima de OS
- Criptografia obrigatória
- Bloqueio por PIN/biometria
- Proibição de root/jailbreak

---

### 7.2 Avaliação Contínua

- Avaliações periódicas
- Avaliações sob evento
- Alterações afetam TrustLevel

---

## 8. Trust Level do Dispositivo

### 8.1 Definição

O **TrustLevel** representa o grau de confiança do dispositivo.

- Intervalo: 0 a 100
- Dinâmico
- Recalculado continuamente

---

### 8.2 Uso do TrustLevel

- Entrada para ABAC
- Entrada para Risk Engine
- Gatilho de MFA ou bloqueio

---

## 9. Integração com IAM e Segurança

- Device vinculado à Identity
- Sessões herdam contexto do dispositivo
- TrustLevel pode encerrar sessões ativas

---

## 10. Auditoria e Eventos de Dispositivo

- Toda mutação gera AuditEvent
- Eventos de compliance são rastreáveis
- Tentativas cross-tenant são eventos críticos

---

## 11. Integração com UEMs Externos

O MDM nativo pode coexistir com:
- Microsoft Intune
- Jamf
- VMware Workspace ONE

Sempre via conectores, mantendo o VianaID como autoridade.

---

## 12. Considerações de Implementação

- Agentes leves ou APIs nativas do SO
- Comunicação segura (mTLS)
- Tolerância a offline
- Escala horizontal

---

## 13. Conclusão

O MDM / UEM nativo do VianaID:
- Trata dispositivos como entidades de segurança
- Aplica Zero Trust completo
- Garante auditoria e isolamento
- Não depende exclusivamente de soluções externas

Este documento estabelece o **contrato definitivo** para gerenciamento de dispositivos no VianaID.

**Fim do Documento**

