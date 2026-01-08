# VianaID – OAuth 2.0 & OpenID Connect Server
## Documento Oficial de Arquitetura e Implementação (Nível Enterprise)

---

## 1. Objetivo do Documento
Este documento descreve a **arquitetura, responsabilidades e modelo de implementação** do **OAuth 2.0 / OpenID Connect Server do VianaID**, em nível **enterprise**, alinhado às melhores práticas de segurança, Zero Trust e interoperabilidade.

Ele serve como **documentação oficial** para:
- Arquitetos de software e segurança
- Engenheiros backend
- Times de IAM
- Auditores técnicos

O objetivo é permitir a implementação de um **Authorization Server e OpenID Provider robusto**, seguro, escalável e totalmente integrado ao core IAM do VianaID.

---

## 2. Papel do OAuth/OIDC no VianaID

No VianaID, OAuth 2.0 e OpenID Connect **não são o IAM**, mas sim **protocolos de federação e delegação** que:
- Exponibilizam identidade e autorização
- Permitem SSO
- Permitem integração com aplicações e APIs

> **O banco de dados IAM é a fonte de verdade.** Tokens são derivados e efêmeros.

---

## 3. Princípios Arquiteturais

1. **OAuth/OIDC como camada de exposição**
2. **Tokens nunca são fonte de verdade**
3. **Decisão de acesso é externa ao protocolo**
4. **Segurança por design (Zero Trust)**
5. **Revogação real, não apenas expiração**
6. **Multi-tenant nativo**

---

## 4. Componentes do Servidor OAuth/OIDC

### 4.1 Authorization Server
Responsável por:
- Autenticação do usuário
- Emissão de tokens
- Consentimento

### 4.2 OpenID Provider (OP)
Responsável por:
- Emissão de ID Tokens
- Exposição de claims OIDC
- UserInfo Endpoint

### 4.3 Token Service
- Geração e assinatura de tokens
- Rotação de chaves
- Revogação

---

## 5. Entidades de Domínio Relacionadas

### 5.1 ClientApplication
Representa aplicações clientes.

Atributos conceituais:
- ClientId
- TenantId
- Name
- ClientType (Confidential / Public)
- AllowedGrantTypes
- RedirectUris
- AllowedScopes
- IsActive
- CreatedBy / CreatedAt

---

### 5.2 ClientSecret / Key
- Secrets versionados
- Chaves públicas para clients mTLS / private_key_jwt

---

### 5.3 Scope
Define **o que pode ser acessado**.

- ScopeId
- Name
- Description
- IsSensitive

Scopes não são permissões diretas.

---

## 6. Grant Types Suportados (Enterprise)

### 6.1 Authorization Code + PKCE (Obrigatório)
- Fluxo padrão para aplicações web e mobile

### 6.2 Client Credentials
- Comunicação máquina-a-máquina

### 6.3 Refresh Token
- Com rotação obrigatória

### 6.4 Device Code Flow
- Dispositivos sem browser

### 6.5 Implicit Flow
❌ **Não suportado** (inseguro)

---

## 7. Tokens

### 7.1 Tipos
- Access Token
- ID Token
- Refresh Token

### 7.2 Características
- Curtíssima duração
- Assinados (JWT)
- Opcionalmente criptografados (JWE)

---

## 8. Claims e Identidade

### 8.1 Fonte das Claims
Claims são **derivadas do core IAM**, nunca do token anterior.

### 8.2 Exemplos de Claims
- sub (IdentityId)
- tenant_id
- roles (informativo)
- auth_time
- acr

---

## 9. Integração com Decision Engine

### 9.1 Avaliação de Acesso

Antes da emissão do token:
- Decision Engine é consultado
- Policies ABAC são avaliadas
- RiskScore é considerado

OAuth **não decide acesso sozinho**.

---

## 10. MFA e Autenticação Forte

- OIDC suporta `acr` e `amr`
- MFA adaptativo baseado em RiskScore
- Step-up authentication

---

## 11. Multi-Tenant

- Clients pertencem a um Tenant
- Tokens sempre carregam TenantId
- Isolamento garantido por RLS no banco

---

## 12. Revogação e Logoff

### 12.1 Revogação Real
- Tokens revogáveis por:
  - Usuário
  - Sessão
  - Tenant

### 12.2 Logoff
- Front-channel logout
- Back-channel logout

---

## 13. Chaves Criptográficas

- Assinatura assimétrica
- Rotação automática
- JWKS endpoint

Chaves são auditáveis e versionadas.

---

## 14. Segurança Avançada

- PKCE obrigatório
- Rate limiting
- Proteção contra replay
- Binding de token à sessão
- Detecção de abuso

---

## 15. Auditoria e Compliance

Cada emissão ou falha de token gera:
- AuditEvent
- Contexto
- Decisão

Auditoria é **obrigatória**.

---

## 16. Considerações de Implementação

- Pode ser serviço dedicado
- Pode escalar horizontalmente
- Stateless com validação no core IAM

---

## 17. Conclusão

O OAuth 2.0 / OpenID Connect Server do VianaID:
- É seguro por design
- Totalmente integrado ao IAM
- Preparado para escala enterprise
- Compatível com Zero Trust

Ele atua como **ponte**, não como fonte de verdade.

**Fim do Documento**

