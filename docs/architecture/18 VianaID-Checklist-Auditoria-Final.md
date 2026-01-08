# VianaID – Revisão Cruzada Final (Checklist de Auditoria)
## Documento Oficial de Auditoria Técnica, Segurança e Conformidade

---

## 1. Objetivo do Documento

Este documento estabelece o **checklist oficial de auditoria técnica do VianaID**, cobrindo **arquitetura, dados, segurança, governança, operação e UX administrativa**.

Ele foi criado para:
- Validar se o VianaID está **corretamente implementado**
- Servir como **guia de verificação para auditorias internas e externas**
- Garantir que **nenhuma decisão arquitetural dependa de interpretação**
- Fornecer evidências objetivas de conformidade

Este documento é **normativo**. Cada item deve ser verificável.

---

## 2. Escopo da Auditoria

Este checklist cobre:
- Modelo de dados e banco de dados
- Multi-tenancy e isolamento
- Row-Level Security (RLS)
- Autenticação e federação
- Autorização e decisão
- Governança (IGA)
- Dispositivos (MDM/UEM)
- APIs e Gateway
- UX administrativa
- Operação e SRE

---

## 3. Checklist – Modelo de Dados (ERD)

### 3.1 Estrutura de Entidades

- [ ] Todas as entidades persistentes estão documentadas no ERD
- [ ] Não existem entidades implícitas
- [ ] Identity ≠ Person está respeitado
- [ ] Device é entidade de primeira classe

---

### 3.2 Auditoria de Dados

- [ ] Todas as tabelas mutáveis possuem os 5 campos padrão de auditoria
- [ ] `CreatedBy` e `CreatedAt` são imutáveis
- [ ] Soft delete (`IsActive`) é utilizado
- [ ] DELETE físico é proibido

---

## 4. Checklist – Schema SQL Server

### 4.1 Definição Explícita

- [ ] Todas as tabelas estão explicitamente definidas
- [ ] Todas possuem PK, FK e índices declarados
- [ ] Não existem colunas fora do schema documentado

---

### 4.2 Row-Level Security (CRÍTICO)

- [ ] Todas as tabelas com `TenantId` possuem RLS ativo
- [ ] FILTER PREDICATE aplicado para SELECT
- [ ] BLOCK PREDICATE aplicado para INSERT (AFTER INSERT)
- [ ] BLOCK PREDICATE aplicado para UPDATE (AFTER UPDATE)
- [ ] BLOCK PREDICATE aplicado para DELETE (BEFORE DELETE)
- [ ] RLS utiliza exclusivamente `SESSION_CONTEXT('TenantId')`

---

## 5. Checklist – Arquitetura Multi-Tenant

- [ ] Tenant é tratado como fronteira de segurança
- [ ] Não existem joins cross-tenant
- [ ] Escritas cross-tenant são bloqueadas no banco
- [ ] Tentativas de violação geram eventos de auditoria

---

## 6. Checklist – Autenticação e Federação

- [ ] OAuth 2.0 / OIDC implementado conforme documentação
- [ ] Tokens não são fonte de verdade
- [ ] SAML 2.0 usado apenas para federação
- [ ] MFA adaptativo está integrado ao Risk Engine

---

## 7. Checklist – Autorização e Decision Engine

- [ ] RBAC e ABAC estão separados
- [ ] Nenhuma permissão é atribuída diretamente a usuários
- [ ] Decision Engine é o único responsável pela decisão
- [ ] Policies são versionadas e auditáveis

---

## 8. Checklist – Risk Engine e Zero Trust

- [ ] RiskScore é recalculado continuamente
- [ ] Sessões podem ser encerradas por risco
- [ ] Device trust influencia decisões
- [ ] Zero Trust é aplicado após o login

---

## 9. Checklist – MDM / UEM

- [ ] Dispositivos possuem TenantId
- [ ] Entidades de device possuem auditoria
- [ ] RLS protege leitura e escrita de dados de device
- [ ] Device compliance afeta sessões

---

## 10. Checklist – Conectores

- [ ] Conectores não são fonte de verdade
- [ ] Credenciais externas estão criptografadas
- [ ] RLS aplicado a configs e credenciais
- [ ] Sincronizações são auditadas

---

## 11. Checklist – Governança (IGA)

- [ ] Access reviews implementados
- [ ] Attestation registrada com evidência
- [ ] SoD validado preventivamente
- [ ] Governança orientada a risco

---

## 12. Checklist – APIs e API Gateway

- [ ] Todas as APIs passam pelo Gateway
- [ ] Tokens são validados
- [ ] Decision Engine é consultado
- [ ] Rate limiting e quotas aplicados

---

## 13. Checklist – UX Administrativa

- [ ] Papéis administrativos explícitos
- [ ] Nenhuma ação crítica sem confirmação
- [ ] Auditoria visível ao operador
- [ ] MFA obrigatório para admin

---

## 14. Checklist – Operação e SRE

- [ ] SLOs e SLIs definidos
- [ ] Error budgets monitorados
- [ ] Runbooks documentados
- [ ] DR testado periodicamente

---

## 15. Evidências Obrigatórias

Para cada item acima, devem existir:
- Logs
- Configurações
- Capturas ou scripts
- Evidência verificável

---

## 16. Resultado da Auditoria

- [ ] Aprovado sem ressalvas
- [ ] Aprovado com ressalvas
- [ ] Reprovado

Ressalvas devem gerar plano de ação.

---

## 17. Conclusão

Este checklist garante que o VianaID:
- Está conforme a arquitetura definida
- É auditável tecnicamente
- Resiste a auditorias externas
- Não depende de interpretação

Ele representa o **padrão final de qualidade e segurança** do VianaID.

**Fim do Documento**

