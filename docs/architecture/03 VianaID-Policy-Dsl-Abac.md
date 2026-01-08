# VianaID – Policy DSL e ABAC
## Documento Oficial de Políticas de Acesso

---

## 1. Objetivo do Documento
Este documento define o **modelo oficial de políticas de acesso do VianaID**, baseado em ABAC, com RBAC como mecanismo complementar.

---

## 2. Princípios de Controle de Acesso

1. Deny by default
2. Contexto sempre importa
3. Tempo é atributo
4. Decisões explicáveis
5. Policies são versionáveis

---

## 3. Por que ABAC é o Núcleo

RBAC define **capacidade potencial**. ABAC decide **uso real da capacidade**, com base em contexto dinâmico.

---

## 4. Arquitetura Lógica da Policy Engine

```
Request → Context → Policies → Decision → Audit
```

---

## 5. Fontes de Atributos

- Identidade
- Sessão
- Dispositivo
- Tempo
- Tenant
- Risco

---

## 6. Estrutura Conceitual da Policy DSL

Uma policy é composta por:
- Identificador
- Escopo
- Condições
- Efeito
- Prioridade

---

## 7. Sintaxe Conceitual

```
WHEN
  identity.role == "Admin"
  AND session.riskScore < 40
  AND device.trustLevel >= 80
THEN
  ALLOW
```

---

## 8. Efeitos Suportados

- ALLOW
- DENY
- CHALLENGE

---

## 9. Prioridade e Conflito

1. DENY sempre vence
2. Maior prioridade vence
3. Sem match → DENY

---

## 10. Persistência das Policies

Policies são armazenadas como dados:
- Versionáveis
- Auditáveis
- Tenant-aware

---

## 11. Auditoria e Explicabilidade

Cada decisão registra:
- Policies avaliadas
- Resultado
- Contexto

---

## 12. Conclusão

A Policy DSL do VianaID permite controle de acesso dinâmico, seguro e escalável.

**Fim do Documento**

