# VianaID – Risk Engine e IA Adaptativa
## Documento Oficial de Detecção de Risco e Zero Trust Contínuo (Passo 6)

---

## 1. Objetivo deste Documento
Este documento descreve o **Risk Engine do VianaID**, responsável por calcular, atualizar e interpretar o **RiskScore** de identidades, sessões e acessos, utilizando **sinais contextuais, regras determinísticas e inteligência artificial adaptativa**.

Ele serve como **guia oficial de implementação** para:
- Arquitetos de segurança
- Engenheiros de dados
- Engenheiros backend
- Times de IAM e Zero Trust

O Risk Engine é o elemento que transforma o VianaID em um **IAM adaptativo e proativo**, e não apenas reativo.

---

## 2. Papel do Risk Engine no VianaID

O Risk Engine atua como um **sistema nervoso de segurança**, fornecendo sinais contínuos para:
- Decision Engine
- Policy Engine
- MFA adaptativo
- Revogação de sessões
- Acesso just-in-time

Sem Risk Engine, não existe **Zero Trust real**.

---

## 3. Princípios Fundamentais

1. **Risco é dinâmico**
2. **Confiança nunca é permanente**
3. **Todo acesso altera o risco**
4. **Fail-safe sempre**
5. **IA complementa regras, não substitui**
6. **Explicabilidade é obrigatória**

---

## 4. Conceito de RiskScore

### 4.1 Definição

O **RiskScore** é um valor numérico normalizado (0–100) que representa a **probabilidade relativa de comportamento malicioso ou anômalo**.

- 0–30: baixo risco
- 31–60: risco moderado
- 61–100: alto risco

---

### 4.2 Onde o RiskScore é usado

- Avaliação de policies (ABAC)
- Decisão de MFA adaptativo
- Bloqueio ou challenge de acesso
- Logoff forçado
- Alertas de segurança

---

## 5. Fontes de Sinais de Risco

### 5.1 Sinais de Identidade
- Histórico de falhas
- Mudança brusca de comportamento
- Privilégios elevados

### 5.2 Sinais de Sessão
- Localização incomum
- IP suspeito
- Velocidade geográfica impossível

### 5.3 Sinais de Dispositivo
- Device não gerenciado
- Queda de trust level
- Mudança de fingerprint

### 5.4 Sinais Temporais
- Horário atípico
- Acesso fora do padrão

---

## 6. Arquitetura do Risk Engine

```
[Signals Ingestion]
        ↓
[Rules Engine]
        ↓
[Risk Aggregator]
        ↓
[ML Models]
        ↓
[RiskScore Output]
        ↓
[Decision Engine / Audit]
```

Arquitetura híbrida: **regras + IA**.

---

## 7. Rules Engine (Determinístico)

### 7.1 Finalidade

Cobrir cenários conhecidos e exigências de compliance.

### 7.2 Exemplos de Regras

- Login de país bloqueado → +40
- Device não gerenciado → +20
- MFA falhou → +30

Regras são **versionadas e auditáveis**.

---

## 8. IA e Modelos Adaptativos

### 8.1 Função da IA

- Detectar padrões anômalos
- Aprender comportamento normal
- Ajustar pesos dinamicamente

### 8.2 Tipos de Modelos

- Anomaly Detection
- Behavioral Profiling
- Risk Classification

IA **nunca toma decisão sozinha**, apenas influencia o score.

---

## 9. Atualização Contínua do Risco

### 9.1 Quando o RiskScore muda

- Novo login
- Mudança de device
- Elevação de privilégio
- Evento suspeito

### 9.2 Sessões Ativas

Sessões podem:
- Ser reavaliadas
- Ser encerradas
- Exigir reautenticação

---

## 10. Persistência e Auditoria

### 10.1 Armazenamento

- RiskScore por sessão
- Histórico de eventos
- Metadados explicativos

### 10.2 Explicabilidade

Cada score deve ser explicável:
- Quais sinais
- Quais regras
- Influência da IA

---

## 11. Integração com Decision Engine

- RiskScore entra como atributo ABAC
- Policies definem thresholds
- Decision Engine nunca recalcula risco

Separação clara de responsabilidades.

---

## 12. Integração com MFA Adaptativo

Exemplos:
- RiskScore < 30 → sem MFA
- 30–60 → MFA leve
- > 60 → MFA forte ou bloqueio

---

## 13. Zero Trust Contínuo

- Nenhuma sessão é definitiva
- Confiança expira
- Risco é reavaliado constantemente

Zero Trust é **estado contínuo**, não evento.

---

## 14. Considerações de Implementação

- Pode operar como serviço separado
- Pode consumir eventos (event-driven)
- Pode escalar horizontalmente

---

## 15. Conclusão

O Risk Engine do VianaID:
- Eleva o IAM a nível adaptativo
- Reduz falsos positivos
- Aumenta segurança real
- Mantém explicabilidade

Ele é o diferencial entre **IAM tradicional** e **IAM de próxima geração**.

---

**Fim do Documento – Passo 6**

