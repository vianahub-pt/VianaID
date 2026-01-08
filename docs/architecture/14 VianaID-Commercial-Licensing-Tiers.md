# VianaID – Modelo Comercial, Licenciamento e Tiers IAM SaaS
## Documento Oficial de Estratégia Comercial e Implementação de Licenças

---

## 1. Objetivo do Documento
Este documento define o **modelo comercial oficial do VianaID**, incluindo **estratégia de monetização, licenciamento, métricas de cobrança (billing meters)** e **tiers de produto**, alinhados às capacidades técnicas já documentadas.

Ele serve como **guia definitivo** para:
- Liderança de produto
- Engenharia (implementação de limites e medições)
- Comercial e parcerias
- Financeiro e faturamento
- Suporte e Customer Success

O objetivo é garantir que o VianaID seja **tecnicamente monetizável**, **comercialmente competitivo** e **simples de operar em escala SaaS**.

---

## 2. Princípios do Modelo Comercial

1. **Preço alinhado a valor entregue**
2. **Crescimento progressivo, não punitivo**
3. **Métricas claras e auditáveis**
4. **Sem surpresas para o cliente**
5. **Flexibilidade enterprise**
6. **Separação entre capacidade técnica e preço**

---

## 3. Unidade Econômica (Billing Units)

O VianaID utiliza múltiplas unidades de cobrança, combináveis.

### 3.1 Identidades Ativas (Core Unit)

- Usuários humanos ativos
- Service accounts
- Dispositivos gerenciados

Cobrança baseada em **identidades ativas no período**.

---

### 3.2 Autenticações / MAU

- Logins mensais
- Sessões ativas

Usado para tiers de entrada.

---

### 3.3 APIs e Tokens

- Chamadas protegidas pelo Gateway
- Tokens emitidos

Usado para planos focados em APIs.

---

### 3.4 Módulos Avançados

- MDM/UEM
- IGA
- Risk Engine
- Conectores premium

Licenciados separadamente ou por tier.

---

## 4. Estrutura de Tiers (Visão Geral)

| Tier | Público-alvo | Objetivo |
|-----|-------------|----------|
| Starter | Startups / SMB | Entrada rápida |
| Growth | Empresas em expansão | Escala controlada |
| Enterprise | Grandes corporações | Governança total |
| Sovereign | Setores regulados | Isolamento máximo |

---

## 5. Tier Starter

### 5.1 Perfil

- Pequenas empresas
- Startups
- MVPs e POCs

### 5.2 Funcionalidades

- Core IAM
- OAuth 2.0 / OIDC
- SSO básico
- API Gateway (limites)
- Logs básicos

### 5.3 Limitações Técnicas

- Limite de identidades
- Sem IGA
- Sem MDM
- Sem SAML

---

## 6. Tier Growth

### 6.1 Perfil

- Empresas em crescimento
- Produtos B2B/B2C

### 6.2 Funcionalidades

- Tudo do Starter
- MFA adaptativo
- ABAC completo
- Risk Engine
- Conectores básicos (AD, Google)
- SAML (SP)

### 6.3 Limitações

- IGA limitada
- MDM parcial

---

## 7. Tier Enterprise

### 7.1 Perfil

- Grandes empresas
- Ambientes regulados

### 7.2 Funcionalidades

- Tudo do Growth
- IGA completo (reviews, attestation, SoD)
- MDM/UEM completo
- SAML IdP + SP
- API Gateway avançado
- SLAs enterprise

---

## 8. Tier Sovereign

### 8.1 Perfil

- Governo
- Bancos
- Saúde
- Infraestrutura crítica

### 8.2 Características Exclusivas

- Isolamento dedicado
- Chaves próprias (BYOK/HSM)
- On-prem ou híbrido
- Compliance avançado
- Suporte dedicado

---

## 9. Add-ons e Upsell

- Conectores premium (SAP, Oracle)
- IA avançada de risco
- Retenção estendida de logs
- Relatórios customizados
- Ambientes adicionais

---

## 10. Implementação Técnica do Licenciamento

### 10.1 Feature Flags

- Funcionalidades habilitadas por tenant
- Controladas no core IAM

### 10.2 Enforcement

- Limites aplicados no Decision Engine
- API Gateway aplica quotas
- Jobs de verificação periódica

---

## 11. Medição e Auditoria de Uso

- Métricas persistidas
- Relatórios por tenant
- Auditoria de billing

Transparência é mandatória.

---

## 12. Upgrade, Downgrade e Overages

- Upgrade imediato
- Downgrade controlado
- Overages com notificação

Sem bloqueios inesperados.

---

## 13. Contratos Enterprise

- Preço negociado
- SLAs customizados
- Termos de compliance
- Suporte 24x7

---

## 14. Posicionamento Competitivo

VianaID se posiciona como:
- Mais integrado que Auth0
- Mais flexível que Entra ID
- Mais transparente que Okta

Preço alinhado à arquitetura.

---

## 15. Conclusão

O modelo comercial do VianaID:
- Reflete valor técnico real
- Escala com o cliente
- Facilita vendas enterprise
- Evita complexidade excessiva

Ele transforma a arquitetura robusta do VianaID em **produto SaaS sustentável e competitivo**.

**Fim do Documento**

