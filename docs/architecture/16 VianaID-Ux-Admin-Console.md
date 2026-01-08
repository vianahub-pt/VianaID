# VianaID – UX e Fluxos Administrativos
## Documento Oficial de Experiência Administrativa e Console de Gestão IAM

---

## 1. Objetivo do Documento

Este documento define **de forma explícita e normativa** a **experiência de usuário (UX)** e os **fluxos administrativos do Console do VianaID**, servindo como **guia oficial de implementação** para times de frontend, backend, produto e segurança.

❗ **Não existem fluxos implícitos.**
Todo comportamento administrativo permitido no sistema está descrito neste documento.

---

## 2. Princípios Fundamentais de UX Administrativa

1. **Segurança antes de conveniência**
2. **Nenhuma ação administrativa sem rastreabilidade**
3. **Menor privilégio por padrão**
4. **Feedback claro para cada ação**
5. **Prevenção de erro é prioridade**
6. **Zero Trust também se aplica ao admin**

---

## 3. Perfis Administrativos (Explícitos)

### 3.1 Super Admin (Plataforma)

Responsabilidades:
- Gerenciar tenants
- Gerenciar contratos e planos
- Gerenciar chaves globais
- Suporte de último nível

Restrições:
- Não gerencia identidades internas de tenants

---

### 3.2 Tenant Admin

Responsabilidades:
- Configuração geral do tenant
- Usuários, dispositivos, políticas
- Conectores e integrações

Restrições:
- Não acessa dados de outros tenants

---

### 3.3 Security Admin

Responsabilidades:
- Policies
- MFA
- Risk Engine
- IGA

---

### 3.4 Read-Only Auditor

Responsabilidades:
- Visualizar logs
- Exportar relatórios

Restrições:
- Nenhuma mutação permitida

---

## 4. Estrutura Global do Admin Console

### 4.1 Navegação Principal

Menus obrigatórios:
- Dashboard
- Identidades
- Dispositivos
- Autenticação & MFA
- Autorização
- Conectores
- Governança (IGA)
- APIs & Aplicações
- Auditoria
- Configurações

---

## 5. Fluxos Administrativos Detalhados

---

## 5.1 Fluxo: Criação de Tenant

**Ator:** Super Admin

Passos obrigatórios:
1. Informar nome do tenant
2. Definir plano/licença
3. Criar TenantId
4. Criar admin inicial
5. Registrar AuditEvent

Erros possíveis:
- Nome duplicado
- Plano inválido

---

## 5.2 Fluxo: Gestão de Usuários (Identity)

**Ator:** Tenant Admin / Security Admin

Ações explícitas:
- Criar identidade
- Ativar / desativar
- Vincular Person
- Revogar sessões

Cada ação:
- Gera AuditEvent
- Exige confirmação

---

## 5.3 Fluxo: Gestão de Credenciais

Ações permitidas:
- Reset de credencial
- Revogação
- Forçar MFA

Restrições:
- Segredos nunca exibidos

---

## 5.4 Fluxo: Gestão de Dispositivos (MDM)

Ações:
- Aprovar enrollment
- Bloquear dispositivo
- Colocar em quarentena

Consequência explícita:
- Sessões encerradas

---

## 5.5 Fluxo: Políticas de Autorização (ABAC/RBAC)

Ações:
- Criar policy
- Testar policy (simulação)
- Ativar / desativar

Mudanças:
- Não afetam retroativamente logs

---

## 5.6 Fluxo: Conectores

Ações:
- Criar conector
- Configurar mapeamentos
- Executar sync manual

Segurança:
- Credenciais mascaradas

---

## 5.7 Fluxo: Governança (IGA)

Ações:
- Iniciar access review
- Executar attestation
- Resolver conflito SoD

Todas as decisões:
- Exigem justificativa

---

## 5.8 Fluxo: APIs e Aplicações

Ações:
- Registrar aplicação
- Definir scopes
- Gerenciar segredos

---

## 5.9 Fluxo: Auditoria

Ações permitidas:
- Visualizar eventos
- Filtrar por período
- Exportar relatórios

Proibição:
- Alterar eventos

---

## 6. Confirmações, Alertas e Prevenção de Erros

- Confirmação obrigatória para ações críticas
- Avisos de impacto
- Rollback quando possível

---

## 7. Segurança do Console Administrativo

- MFA obrigatório
- Sessões curtas
- Reautenticação para ações críticas
- IP allowlist (opcional)

---

## 8. Auditoria e Compliance no UX

- Toda ação gera AuditEvent
- Usuário vê o que foi registrado
- Transparência total

---

## 9. Acessibilidade e Usabilidade

- Navegação clara
- Linguagem não ambígua
- Erros explicativos

---

## 10. Proibições Explícitas

❌ Ações em massa sem confirmação
❌ Edição direta de dados críticos
❌ Bypass de políticas

---

## 11. Conclusão

Este documento garante que o Admin Console do VianaID:
- Seja seguro por padrão
- Seja auditável
- Seja claro para qualquer operador
- Não dependa de interpretação

Ele define **a única experiência administrativa válida** do VianaID.

**Fim do Documento**

