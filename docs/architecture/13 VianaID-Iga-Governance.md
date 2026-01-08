# VianaID – Governança Avançada de Identidades (IGA)
## Documento Oficial de Arquitetura e Implementação (Access Reviews, Attestation, SoD)

---

## 1. Objetivo do Documento
Este documento descreve a **arquitetura oficial de Governança de Identidade (IGA – Identity Governance and Administration)** do VianaID, cobrindo **access reviews, attestation, segregation of duties (SoD)** e automação do ciclo de vida de acessos.

Ele serve como **guia definitivo de implementação** para:
- Arquitetos de IAM e segurança
- Engenheiros backend e de dados
- Times de governança, risco e compliance (GRC)
- Auditores internos e externos

O objetivo é permitir que o VianaID ofereça **governança contínua, auditável e automatizada**, compatível com ambientes enterprise altamente regulados.

---

## 2. Papel da IGA no VianaID

A camada de IGA responde à pergunta:
> **“Quem tem acesso a quê, por quê e por quanto tempo?”**

No VianaID, a IGA:
- Não substitui IAM operacional
- Atua sobre **acessos já concedidos**
- Garante conformidade contínua
- Reduz riscos acumulados ao longo do tempo

---

## 3. Princípios Fundamentais de Governança

1. **Acesso é temporário por natureza**
2. **Privilégios devem ser revisados periodicamente**
3. **Decisões devem ser justificáveis**
4. **Automação primeiro, intervenção humana quando necessário**
5. **Auditoria como requisito estrutural**
6. **Governança orientada a risco**

---

## 4. Componentes da Governança IGA

### 4.1 Access Review Engine

Responsável por:
- Revisão periódica de acessos
- Aprovação, revogação ou ajuste
- Geração de evidências de compliance

---

### 4.2 Attestation Engine

Responsável por:
- Coletar declarações formais de responsabilidade
- Registrar quem aprovou o quê
- Manter trilhas legais de decisão

---

### 4.3 SoD Engine (Segregation of Duties)

Responsável por:
- Detectar conflitos de função
- Prevenir acessos incompatíveis
- Sinalizar violações

---

## 5. Access Reviews

### 5.1 Conceito

Access Review é o processo de **reavaliar periodicamente acessos existentes**.

Perguntas-chave:
- O acesso ainda é necessário?
- O nível de acesso é adequado?
- O risco é aceitável?

---

### 5.2 Tipos de Reviews

- Por usuário
- Por role
- Por aplicação
- Por privilégio
- Baseado em risco

---

### 5.3 Ciclo de Vida de um Review

1. Geração automática
2. Notificação de revisores
3. Decisão (approve / revoke / adjust)
4. Aplicação automática
5. Registro de auditoria

---

## 6. Attestation

### 6.1 Conceito

Attestation é a **declaração formal** de que um acesso é legítimo e necessário.

Ela responde:
> “Quem assumiu responsabilidade por este acesso?”

---

### 6.2 Quem Pode Atestar

- Gestores
- Donos de aplicação
- Donos de dados
- Compliance officers

---

### 6.3 Evidência Legal

Cada attestation registra:
- Identidade do aprovador
- Data e contexto
- Justificativa

---

## 7. Segregation of Duties (SoD)

### 7.1 Conceito

SoD previne que **uma única identidade concentre poderes incompatíveis**.

Exemplo clássico:
- Criar fornecedor
- Aprovar pagamento

---

### 7.2 Modelagem de Regras SoD

- Baseada em roles
- Baseada em atributos
- Baseada em aplicações

---

### 7.3 Tratamento de Violações

- Bloqueio preventivo
- Exceção temporária (com attestation)
- Alerta e auditoria

---

## 8. Integração com IAM Operacional

- RBAC e ABAC fornecem base
- Decision Engine aplica decisões
- Risk Engine prioriza revisões

IGA **não atua isoladamente**.

---

## 9. Governança Orientada a Risco

- Acessos de alto risco revisados com maior frequência
- Violações aumentam RiskScore
- Prioridade automática de ações

---

## 10. Automação do Ciclo de Vida

- Joiner: concessões iniciais
- Mover: ajustes automáticos
- Leaver: revogação total

Automação reduz erro humano.

---

## 11. Auditoria e Compliance

Cada ação de governança gera:
- AuditEvent
- Evidência
- Contexto
- Resultado

Compatível com:
- SOX
- ISO 27001
- LGPD / GDPR

---

## 12. Multi-Tenant e Governança

- Políticas por tenant
- Reviews isolados
- Evidências segregadas

---

## 13. Considerações de Implementação

- Engine dedicada
- Jobs agendados
- UX simples para revisores
- Escala horizontal

---

## 14. Conclusão

A governança avançada (IGA) do VianaID:
- Reduz riscos acumulados
- Garante conformidade contínua
- Automatiza decisões repetitivas
- Fornece evidência auditável

Ela eleva o VianaID ao patamar de **plataforma IAM completa para ambientes altamente regulados**.

**Fim do Documento**

