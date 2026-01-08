# VianaID – SSO Federation (SAML 2.0)
## Documento Oficial de Arquitetura e Implementação (Nível Enterprise)

---

## 1. Objetivo do Documento
Este documento descreve a **implementação oficial de SSO Federation via SAML 2.0 no VianaID**, permitindo integração segura com **aplicações legadas, provedores corporativos e ambientes enterprise** que ainda dependem de SAML.

Ele serve como **guia definitivo de implementação** para:
- Arquitetos de IAM e segurança
- Engenheiros backend e integração
- Times de identidade corporativa
- Operação e suporte enterprise

O objetivo é garantir **SSO robusto, auditável e alinhado ao Zero Trust**, sem comprometer a arquitetura moderna baseada em OAuth/OIDC.

---

## 2. Papel do SAML 2.0 no VianaID

No VianaID, o SAML 2.0 é tratado como:
- **Camada de compatibilidade enterprise**
- Mecanismo de federação com sistemas legados
- Ponte entre ambientes modernos e tradicionais

> **SAML não substitui OAuth/OIDC. Ele complementa.**

---

## 3. Princípios Arquiteturais

1. SAML como protocolo de federação, não de decisão
2. Decisões de acesso sempre passam pelo core IAM
3. Identidade centralizada no VianaID
4. Segurança criptográfica forte
5. Auditoria obrigatória
6. Multi-tenant por padrão

---

## 4. Modos de Operação SAML no VianaID

### 4.1 VianaID como Identity Provider (IdP)

- Emissão de assertions SAML
- Autenticação centralizada
- Integração com apps SaaS e on-prem

### 4.2 VianaID como Service Provider (SP)

- Consumo de assertions de IdPs externos
- Federação com AD FS, Entra ID, etc.

Ambos os modos podem coexistir por tenant.

---

## 5. Componentes do SAML no VianaID

```
[User / Browser]
      ↓
[IdP / SP Redirect]
      ↓
[SAML Engine]
      ↓
[Core IAM]
      ↓
[Decision Engine]
      ↓
[Audit]
```

O SAML Engine **nunca decide acesso sozinho**.

---

## 6. Entidades de Domínio Relacionadas

### 6.1 SAMLServiceProvider

Representa um SP confiável.

- ServiceProviderId
- TenantId
- EntityId
- ACS URL
- Certificates
- IsActive
- CreatedBy / CreatedAt

---

### 6.2 SAMLIdentityProvider

Representa um IdP externo.

- IdentityProviderId
- TenantId
- EntityId
- SSO URL
- Certificates
- IsActive

---

## 7. Fluxos SAML Suportados

### 7.1 SP-Initiated SSO

Fluxo mais comum:
1. Usuário acessa o SP
2. Redirecionamento para IdP
3. Autenticação
4. Assertion SAML

---

### 7.2 IdP-Initiated SSO

- Usuário inicia no IdP
- Assertion enviada diretamente ao SP

Ambos são suportados.

---

## 8. Assertions e Claims

### 8.1 Conteúdo da Assertion

- Subject (IdentityId)
- TenantId
- Attributes (claims)
- AuthnContext

### 8.2 Mapeamento de Atributos

- Configurável por tenant
- Normalização antes do uso
- Nenhum atributo externo é confiável por padrão

---

## 9. Integração com Decision Engine

Antes da emissão ou aceite de assertion:
- Contexto é montado
- Policies ABAC são avaliadas
- RiskScore é considerado

SAML **não contorna políticas**.

---

## 10. Segurança Criptográfica

- Assinatura obrigatória de assertions
- Criptografia opcional (recomendada)
- Rotação de certificados
- Validação de audience e issuer

---

## 11. MFA e Step-Up Authentication

- SAML AuthnContext suportado
- MFA pode ser exigido por policy
- Step-up baseado em risco

---

## 12. Single Logout (SLO)

### 12.1 Modos Suportados

- Front-channel logout
- Back-channel logout

### 12.2 Integração com Sessões

Logout invalida:
- Sessões locais
- Tokens associados

---

## 13. Multi-Tenant

- SPs e IdPs sempre associados a um Tenant
- Isolamento completo
- Nenhuma federação cruzada

---

## 14. Auditoria e Compliance

Cada evento SAML gera:
- AuditEvent
- Resultado
- Identidade
- Tenant
- Timestamp

Auditoria é mandatória.

---

## 15. Convivência com OAuth/OIDC

- SAML para legado
- OAuth/OIDC para moderno
- Decisão sempre unificada no IAM

Essa convivência é estratégica.

---

## 16. Considerações de Implementação

- Engine SAML isolada
- Validação rigorosa de XML
- Proteção contra replay
- Clock skew controlado

---

## 17. Conclusão

A federação SAML 2.0 do VianaID:
- Garante compatibilidade enterprise
- Mantém Zero Trust
- Não compromete a arquitetura moderna

Ela permite transição segura do legado para o futuro.

**Fim do Documento**

