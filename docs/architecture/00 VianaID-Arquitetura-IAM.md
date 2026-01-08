# 📘 Documento de Engenharia Reversa e Arquitetura  
## IAM VianaID – Plataforma de Identidade de Próxima Geração

---

## 1️⃣ Engenharia Reversa – Gigantes do Mercado IAM

### 🔹 Microsoft (Entra ID / Azure AD)

**Pontos Fortes**
- Diretório global altamente escalável  
- Zero Trust nativo  
- Conditional Access extremamente poderoso  
- Integração profunda com o ecossistema corporativo  
- PAM, JIT e Identity Governance maduros  

**Pontos Fracos**
- Modelo de dados complexo e pouco transparente  
- Forte lock-in  
- Difícil auditoria externa  
- Customizações profundas são caras e engessadas  

---

### 🔹 Google (Google Identity / Workspace)

**Pontos Fortes**
- UX excelente  
- Autenticação sem senha avançada  
- Context-aware access  
- Escalabilidade absurda  

**Pontos Fracos**
- Governança limitada para empresas grandes  
- PAM fraco  
- Pouco controle granular do ciclo de vida  
- IAM não é core business  

---

### 🔹 Apple (Apple ID)

**Pontos Fortes**
- Segurança de hardware (Secure Enclave)  
- Biometria impecável  
- Privacidade forte  

**Pontos Fracos**
- Não é IAM corporativo  
- Sem RBAC real  
- Sem governança  
- Pouca integração externa  

---

### 🔹 IBM (Verify)

**Pontos Fortes**
- Compliance, auditoria e relatórios  
- IAM clássico robusto  
- Forte suporte a LDAP/AD  

**Pontos Fracos**
- UX ruim  
- Pouca inovação  
- Arquitetura pesada  
- Alto custo operacional  

---

### 🔹 Facebook (Meta Identity)

**Pontos Fortes**
- Identidade distribuída  
- Login social altamente escalável  
- Telemetria e detecção de fraude  

**Pontos Fracos**
- Foco em consumidor  
- Governança inexistente  
- Baixa transparência  

---

## 2️⃣ Princípios Fundamentais do VianaID

O **VianaID não é apenas um diretório**.  
Ele é um **Identity Fabric**.

**Princípios:**
- Zero Trust by Design  
- Policy-Driven Everything  
- Event-Driven Architecture  
- SQL Server como fonte de verdade  
- IAM ≠ Autenticação  
- Identidade é temporal, contextual e dinâmica  

---

## 3️⃣ Arquitetura Conceitual do VianaID

```
┌───────────────────────────────┐
│ Identity Experience Layer     │ (SSO, MFA, Passwordless)
├───────────────────────────────┤
│ Policy & Decision Engine      │ (RBAC + ABAC + Context)
├───────────────────────────────┤
│ Identity Governance Layer     │ (Lifecycle, PAM, JIT)
├───────────────────────────────┤
│ Directory & Credential Layer  │
├───────────────────────────────┤
│ Integration & Federation      │ (OAuth, OIDC, SAML)
├───────────────────────────────┤
│ Audit, Risk & AI              │
├───────────────────────────────┤
│ SQL Server Core Identity DB   │
└───────────────────────────────┘
```

---

## 4️⃣ Modelo de Dados – Núcleo do IAM (Alta Normalização)

### 🔐 Identidade NÃO é Usuário

### 🧠 Identity
- IdentityId (GUID)  
- Type (Human, Service, Device)  
- Status  
- CreatedAt  

### 👤 Person
- PersonId  
- IdentityId  
- LegalName  
- PreferredName  
- DateOfBirth  

### 🔑 Credential
- CredentialId  
- IdentityId  
- Type (Password, FIDO2, OTP, Biometric)  
- Hash  
- PublicKey  
- IsRevoked  
- ExpiresAt  

### 📱 Device
- DeviceId  
- IdentityId  
- OS  
- IsManaged  
- TrustLevel  

### 🌐 Session
- SessionId  
- IdentityId  
- DeviceId  
- IpAddress  
- GeoLocation  
- RiskScore  
- StartedAt  
- EndedAt  

### 📜 Policy (ABAC)
- PolicyId  
- Name  
- Expression (JSON / DSL)  
- Effect (Allow/Deny)  

### 🎭 Role (RBAC)
- RoleId  
- Name  

### 🔗 RoleAssignment
- RoleId  
- IdentityId  
- Scope  

### 🔐 PrivilegedAccess (PAM / JIT)
- IdentityId  
- RoleId  
- ApprovedBy  
- ValidFrom  
- ValidTo  

### 📊 AuditEvent
- EventId  
- IdentityId  
- Action  
- Resource  
- Result  
- Timestamp  
- Metadata (JSON)  

---

## 5️⃣ Normalização Avançada (4NF / 5NF)

**Decisões Críticas**
- Nenhuma permissão direta no usuário  
- Tudo passa por Policy + Context  
- Grupos aninhados  
- Dispositivos desacoplados de usuários  
- Sessões imutáveis (append-only)  
- Auditoria 100% rastreável  

---

## 6️⃣ Zero Trust na Prática

| Elemento | Implementação |
|--------|---------------|
| Nunca confiar | RiskScore por sessão |
| Sempre verificar | Policy Engine |
| Mínimo privilégio | PAM + JIT |
| Contextual | Device + Location |
| Auditável | AuditEvent append-only |

---

## 7️⃣ MFA, Passwordless, FIDO e Biometria
- Múltiplos métodos por identidade  
- Chaves públicas versionadas  
- Revogação imediata  
- Suporte FIDO2  
- OTP e Push desacoplados  

---

## 8️⃣ SSO, OAuth, OIDC e Federação
**Entidades**
- ClientApplication  
- OAuthGrant  
- Token  
- RefreshToken  
- FederationProvider  

- Tokens stateless e revogáveis  
- Rotação automática de chaves  
- Suporte multi-tenant  

---

## 9️⃣ Integrações Corporativas
- Active Directory  
- LDAP  
- Google Workspace  
- VPN / Firewall  
- UEM / MDM  
- Apps SaaS  
- APIs internas  

Tudo via **Connector Framework**.

---

## 🔟 Diferencial Estratégico do VianaID
- Modelo de dados transparente  
- SQL Server como fonte auditável  
- ABAC real  
- PAM e JIT nativos  
- IAM como produto central  
- Preparado para IA  
- Cloud, on-prem e híbrido  

---

## 1️⃣1️⃣ Próximos Passos
- ERD completo  
- Scripts SQL Server  
- Policy DSL  
- Decision Engine  
- Arquitetura multi-tenant  
- Risk Engine com IA  
