# VianaID – Modelo de APIs e API Gateway
## Documento Oficial de Arquitetura e Proteção de APIs (Nível Enterprise)

---

## 1. Objetivo do Documento
Este documento descreve o **modelo oficial de APIs do VianaID** e a **arquitetura do API Gateway**, responsável por proteger, expor, governar e observar APIs internas e externas.

Ele serve como **guia definitivo de implementação** para:
- Arquitetos de software e segurança
- Engenheiros backend e plataforma
- Times de IAM e Zero Trust
- Operação e SRE

O objetivo é permitir a implementação de um **API Gateway enterprise**, totalmente integrado ao OAuth/OIDC, Decision Engine e Risk Engine do VianaID.

---

## 2. Papel do API Gateway no VianaID

O API Gateway é o **ponto único de entrada (control plane)** para todas as APIs protegidas pelo VianaID.

Responsabilidades principais:
- Autenticação de chamadas
- Autorização baseada em contexto
- Proteção contra abuso
- Observabilidade
- Governança e versionamento

> **Nenhuma API crítica deve ser acessível sem passar pelo Gateway.**

---

## 3. Princípios Arquiteturais

1. **Zero Trust para APIs**
2. Toda requisição é avaliada
3. Tokens não são suficientes sozinhos
4. Decisão sempre contextual
5. Segurança antes da lógica de negócio
6. Auditoria obrigatória

---

## 4. Tipos de APIs no VianaID

### 4.1 APIs Públicas
- Consumidas por aplicações externas
- Sempre protegidas por OAuth/OIDC

### 4.2 APIs Internas
- Comunicação entre serviços
- Protegidas por Client Credentials + policies

### 4.3 APIs Administrativas
- Operação e governança
- Proteção reforçada (MFA, IP allowlist)

---

## 5. Arquitetura Lógica do API Gateway

```
[Client]
   ↓
[API Gateway]
   ↓
[AuthN/AuthZ]
   ↓
[Decision Engine]
   ↓
[Backend Service]
   ↓
[Audit & Telemetry]
```

O Gateway **nunca decide sozinho**: ele orquestra decisões.

---

## 6. Autenticação no Gateway

### 6.1 Validação de Tokens

- Validação de assinatura (JWKS)
- Validação de expiração
- Validação de audience e issuer

Tokens inválidos são rejeitados imediatamente.

---

### 6.2 Autenticação M2M

- Client Credentials
- mTLS (opcional)
- private_key_jwt

---

## 7. Autorização Contextual

### 7.1 Integração com Decision Engine

Para cada request:
- Contexto é montado
- Decision Engine é consultado
- Policy ABAC avaliada

Resultado:
- ALLOW
- DENY
- CHALLENGE

---

### 7.2 RBAC + ABAC

- Scopes indicam **intenção**
- Policies decidem **permissão real**

---

## 8. Proteção Avançada de APIs

### 8.1 Rate Limiting

- Por client
- Por identidade
- Por IP
- Por tenant

---

### 8.2 Throttling e Quotas

- Limites configuráveis
- Políticas por tipo de API

---

### 8.3 Proteção contra Ataques

- Replay attacks
- Token stuffing
- Brute force
- Abuse detection

---

## 9. Integração com Risk Engine

- RiskScore avaliado por request
- Risco alto → bloqueio ou challenge
- Sessões podem ser encerradas

Zero Trust contínuo aplicado às APIs.

---

## 10. Versionamento de APIs

- Versionamento explícito (v1, v2)
- Múltiplas versões coexistem
- Depreciação controlada

---

## 11. Observabilidade e Telemetria

### 11.1 Logs
- Requests
- Responses
- Decisões

### 11.2 Métricas
- Latência
- Erros
- Taxa de bloqueio

### 11.3 Tracing
- Correlação end-to-end

---

## 12. Auditoria e Compliance

Cada request relevante gera:
- AuditEvent
- Decisão aplicada
- Identidade / client
- Tenant

Auditoria é mandatória.

---

## 13. Multi-Tenant no Gateway

- TenantId resolvido no início da request
- Isolamento garantido até o backend
- Nenhum roteamento cruzado

---

## 14. Topologias de Implantação

- Gateway centralizado
- Gateway distribuído
- Sidecar por serviço

A escolha depende de escala e latência.

---

## 15. Considerações de Implementação

- Pode usar soluções comerciais ou open source
- Gateway é stateless
- Escala horizontal

---

## 16. Conclusão

O modelo de APIs e API Gateway do VianaID:
- Protege APIs de forma contextual
- Integra IAM, OAuth, ABAC e risco
- Suporta escala enterprise
- Aplica Zero Trust real

Ele é o **guardião do acesso às APIs**.

**Fim do Documento**

