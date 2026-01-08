# VianaID – Decision Engine
## Documento Oficial de Execução de Decisões de Acesso

---

## 1. Objetivo do Documento
Este documento descreve **como o VianaID executa decisões de acesso**, transformando policies em decisões determinísticas e auditáveis.

---

## 2. Papel do Decision Engine

O Decision Engine:
- Constrói contexto
- Avalia policies
- Resolve conflitos
- Retorna decisão final
- Registra auditoria

---

## 3. Princípios de Execução

1. Determinismo
2. Stateless
3. Fail secure
4. Alta performance
5. Explicabilidade

---

## 4. Fluxo de Decisão

```
Request
 → Context Builder
 → Policy Loader
 → Policy Evaluator
 → Conflict Resolver
 → Decision
 → Audit
```

---

## 5. Context Builder

Responsável por montar:
- Identidade
- Sessão
- Dispositivo
- Tenant
- Tempo

---

## 6. Policy Evaluation

- Policies avaliadas isoladamente
- Sem efeitos colaterais

---

## 7. Resolução de Conflitos

Regras:
- DENY vence
- CHALLENGE > ALLOW
- Prioridade maior vence

---

## 8. Resultado da Decisão

A decisão final contém:
- Decision
- Reason
- RiskScore
- PoliciesApplied

---

## 9. Auditoria

Cada decisão gera evento imutável.

---

## 10. Conclusão

O Decision Engine garante decisões seguras, consistentes e auditáveis.

**Fim do Documento**

