# VianaID – Portal Administrativo
## Documento Oficial de Funcionalidades, Fluxos e Regras do Portal de Administração

---

## 1. Objetivo do Documento

Este documento define **de forma explícita, completa e normativa** todas as **funcionalidades do Portal Administrativo do VianaID**, cobrindo desde a **gestão da própria plataforma** até a **gestão de tenants, aplicações, recursos, ações e permissões**.

Ele serve como **guia oficial de implementação** para:
- Engenharia frontend e backend
- Arquitetura e segurança
- Produto
- QA e auditoria

❗ **Não existem funcionalidades implícitas.**
Tudo que o Portal Administrativo pode ou não fazer está descrito neste documento.

---

## 2. Escopo do Portal Administrativo

O Portal Administrativo do VianaID é a **interface central de controle da plataforma IAM**, permitindo:

- Gestão da própria plataforma VianaID
- Gestão de tenants internos e externos
- Gestão de aplicações registradas
- Gestão de recursos e ações das aplicações
- Gestão de permissões e políticas
- Gestão de auditoria e governança

O portal **não é apenas um painel**, mas sim um **instrumento de governança e segurança**.

---

## 3. Tipos de Portal (Separação Explícita)

### 3.1 Portal de Plataforma (Global)

Acessível apenas por **Super Admins do VianaID**.

Permite:
- Criar e gerenciar tenants
- Gerenciar planos e contratos
- Gerenciar chaves globais
- Monitorar uso da plataforma

---

### 3.2 Portal do Tenant

Acessível por administradores de um tenant específico.

Permite:
- Configurar o tenant
- Gerenciar aplicações do tenant
- Gerenciar identidades, recursos e políticas

---

## 4. Papéis Administrativos no Portal

### 4.1 Super Admin (Plataforma)

- Cria tenants internos e externos
- Define limites e planos
- Acessa métricas globais

---

### 4.2 Tenant Admin

- Gerencia aplicações do tenant
- Gerencia recursos e ações
- Gerencia usuários e permissões

---

### 4.3 Application Admin

- Gerencia uma aplicação específica
- Define recursos e ações

---

### 4.4 Security Admin

- Define políticas de acesso
- Gerencia MFA, risco e governança

---

### 4.5 Auditor

- Visualiza logs
- Exporta relatórios
- Não executa mutações

---

## 5. Funcionalidades do Portal – Plataforma

---

## 5.1 Gestão de Tenants (Internos e Externos)

### Criar Tenant

**Ator:** Super Admin

Campos obrigatórios:
- Nome do tenant
- Tipo (Interno / Externo)
- Plano inicial
- Região

Passos explícitos:
1. Validar nome
2. Gerar TenantId
3. Criar configuração inicial
4. Criar admin do tenant
5. Registrar AuditEvent

---

### Editar Tenant

- Alterar status
- Alterar plano
- Suspender tenant

---

## 5.2 Gestão de Planos e Limites

- Definir limites de usuários
- Definir limites de aplicações
- Definir limites de APIs

---

## 6. Funcionalidades do Portal – Tenant

---

## 6.1 Gestão de Aplicações

### Criar Aplicação

**Ator:** Tenant Admin

Campos obrigatórios:
- Nome da aplicação
- Tipo (Web, API, Mobile)
- Ambiente

Passos explícitos:
1. Criar ClientId
2. Gerar segredos ou chaves
3. Associar ao tenant
4. Registrar AuditEvent

---

### Editar Aplicação

- Atualizar configurações
- Rotacionar segredos

---

## 6.2 Gestão de Recursos da Aplicação

### Conceito de Recurso

Recurso representa **algo protegido** dentro da aplicação.

Exemplos:
- endpoint `/orders`
- entidade `Invoice`

---

### Criar Recurso

Campos obrigatórios:
- Nome do recurso
- Identificador único

---

## 6.3 Gestão de Ações do Recurso

### Conceito de Ação

Ação representa **o que pode ser feito sobre um recurso**.

Exemplos:
- read
- create
- update
- delete

---

### Criar Ação

Campos obrigatórios:
- Nome da ação
- Recurso associado

---

## 6.4 Associação de Recursos e Ações

- Cada recurso possui uma ou mais ações
- Ações não existem sem recurso

---

## 6.5 Gestão de Permissões

### Modelo de Permissão

Permissão = Recurso + Ação + Contexto

---

### Atribuição

- Atribuir permissões a roles
- Atribuir roles a identidades

---

## 7. Políticas de Acesso (ABAC)

- Criar políticas baseadas em atributos
- Associar políticas a aplicações
- Simular políticas antes de ativar

---

## 8. Governança e Auditoria no Portal

### Auditoria

- Visualizar eventos
- Filtrar por tenant, aplicação, identidade

---

### Governança

- Access reviews
- Attestation
- SoD

---

## 9. Segurança do Portal Administrativo

- MFA obrigatório
- Sessões curtas
- Confirmação para ações críticas
- RLS aplicado a todas as operações

---

## 10. Proibições Explícitas

❌ Criar aplicações fora de um tenant
❌ Criar recursos sem aplicação
❌ Criar ações sem recurso
❌ Atribuir permissões diretamente a usuários
❌ Bypass de políticas

---

## 11. Auditoria de Ações Administrativas

Cada ação administrativa:
- Gera AuditEvent
- Registra ator, tenant, ação
- É imutável

---

## 12. Conclusão

O Portal Administrativo do VianaID:
- Centraliza governança IAM
- Elimina ambiguidade operacional
- Garante segurança por design
- É auditável e escalável

Este documento define **a única forma válida de administrar o VianaID**.

**Fim do Documento**

