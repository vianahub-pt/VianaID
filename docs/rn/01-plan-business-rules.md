# Documento de Regras de Negócio — Planos

## 1. Introdução
Este documento descreve de forma detalhada as regras de negócio do módulo **Planos** no sistema IAM (VianaID).

Um **Plano** representa uma oferta comercial da plataforma, definindo limites operacionais, capacidades técnicas, preços e condições que regulam o uso do sistema por parte dos Tenants.

---

## 2. Objetivos do Módulo de Planos
- Definir ofertas comerciais (Free, Pro, Enterprise, etc.).
- Estabelecer limites operacionais por Tenant.
- Controlar elegibilidade de uso de recursos da plataforma.
- Servir de base para Subscriptions e billing.
- Garantir consistência entre uso contratado e uso efetivo.

---

## 3. Estrutura Geral do Plano
Um **Plano** contém:
- `Id`
- `Code` (código técnico gerado automaticamente pelo sistema)
- `Name`
- `Description`
- Preços (`PriceMonthly`, `PriceYearly`, `Currency`)
- Limites operacionais (usuários, aplicações, service accounts, chamadas de API)
- Indicadores de estado (`Status`, `IsActive`, `IsDeleted`)
- Dados de auditoria (`CreatedBy`, `CreatedAt`, `UpdatedBy`, `UpdatedAt`)

### 3.1 Regras do campo Code
- O campo **`Code` nunca é informado pelo usuário**.
- O campo **`Code` é imutável** e **nunca pode ser alterado** após a criação do plano.
- O `Code` é **gerado automaticamente pela aplicação**, utilizando o componente `CodeGenerator`.
- O formato do código segue obrigatoriamente o padrão:

```
<PREFIXO><YYMMDD><HASH>
```

Onde:
- **PLAN**: prefixo fixo que identifica o recurso Plano.
- **YYMMDD**: data UTC de geração do código.
- **HASH**: sequência alfanumérica aleatória de 4 caracteres.

**Exemplo válido:**
```
PLAN251214XTG2
```

- A unicidade do `Code` é garantida pelo sistema.
- Qualquer tentativa de envio ou alteração manual do campo `Code` deve ser ignorada ou rejeitada pela API.

### 3.2 Escopo Multi-tenant
- Os Planos são entidades **globais da plataforma**, não pertencendo a um Tenant específico.
- Um Plano pode estar associado a múltiplos Tenants simultaneamente.
- Alterações em Planos devem considerar impactos em Tenants e Subscriptions existentes.

---

## 4. Regras de Negócio por Operação

### 4.1 Criar Plano (POST /v1/plans)
- O Plano é criado com `IsActive = true` e `IsDeleted = false`.
- O campo `Code` é gerado automaticamente.
- O nome do plano deve ser informado.
- Preços e limites não podem ser negativos.
- O plano pode ser criado sem preço (ex.: plano gratuito).

### 4.2 Consultar Planos (GET /v1/plans)
- Devem ser retornados apenas Planos não deletados.
- Pode haver filtros por status e ativação.

### 4.3 Atualizar Plano (PUT /v1/plans/{id})
- O `Code` não pode ser alterado.
- Limites não podem ser reduzidos abaixo do consumo atual dos Tenants.
- Alterações devem registrar auditoria.

### 4.4 Ativar Plano (PATCH /v1/plans/{id}/activate)
**Contexto:** Reativar um Plano previamente desativado.

**Regras:**
- Só é permitido ativar um Plano existente e não deletado.
- **O Plano deve estar inativo** (`IsActive = false`) para ser ativado.
- Atualizar `IsActive = true`.
- Atualizar `UpdatedBy` e `UpdatedAt`.

**Validações:**
- O Plano deve existir.
- O Plano não pode estar deletado.
- **O Plano não pode estar já ativo** - retorna erro 400 se tentar ativar um Plano que já está ativo.
- A operação **não é idempotente** - valida o estado atual e retorna erro se já estiver no estado desejado.

**Motivo da validação explícita:**
- Evita chamadas desnecessárias ao banco de dados quando o Plano já está ativo.
- Detecta bugs no cliente que fazem chamadas duplicadas.
- Melhora a performance ao fazer "early return" sem validar dependências desnecessariamente.
- Fornece feedback explícito sobre tentativas de operação inválidas.

**Auditoria:**
- Registrar ativação em `AuditLogs`.
- Incluir contexto do usuário administrativo que ativou.

---

### 4.5 Desativar Plano (PATCH /v1/plans/{id}/deactivate)
**Contexto:** Desativar um Plano temporariamente.

**Regras:**
- **O Plano deve estar ativo** (`IsActive = true`) para ser desativado.
- Um Plano desativado não pode ser utilizado por novos Tenants.
- Tenants existentes com Subscriptions ativas mantêm seus contratos até o término do período.
- Atualizar `IsActive = false`.
- Atualizar `UpdatedBy` e `UpdatedAt`.

**Validações:**
- O Plano deve existir e estar ativo.
- **O Plano não pode estar já inativo** - retorna erro 400 se tentar desativar um Plano que já está inativo.
- Verificar se existem Tenants ou Subscriptions ativas associadas (aviso informativo, não bloqueio).
- A operação **não é idempotente** - valida o estado atual e retorna erro se já estiver no estado desejado.

**Motivo da validação explícita:**
- Evita chamadas desnecessárias ao banco de dados.
- Detecta bugs no cliente que fazem chamadas duplicadas.
- Melhora a performance ao fazer "early return" sem processar operação desnecessária.
- Fornece feedback explícito sobre tentativas de operação inválidas.

**Impacto:**
- Plano desativado impede criação de novos Tenants com este Plano.
- Impede criação de novas Subscriptions com este Plano.
- Subscriptions existentes continuam funcionando até o término do período contratado.
- Considerar comunicação prévia para Tenants afetados.

**Auditoria:**
- Registrar desativação em `AuditLogs` com motivo (se fornecido).
- Incluir informações sobre Tenants e Subscriptions impactadas.

---

## 5. Regras de Integridade e Dependência

### 5.1 Dependência obrigatória
- Todo Tenant deve estar associado a exatamente um Plano válido.
- Toda Subscription deve referenciar um Plano existente.

### 5.2 Consistência do Plano
- Alterações em Planos devem preservar integridade comercial e técnica.

---

## 6. Regras de Governança e Segurança

### 6.1 Auditoria
- Toda operação relevante deve ser registrada para fins de auditoria.

### 6.2 Segurança
- Planos influenciam diretamente os limites de segurança e uso do sistema.

---

## 7. Regras Complementares
- Planos devem sofrer poucas alterações após entrarem em produção.
- Mudanças estruturais podem exigir versionamento de planos.

---

## 8. Conclusão
O módulo **Planos** é um componente central do IAM VianaID.

As regras aqui definidas garantem:
- clareza comercial;
- previsibilidade técnica;
- integridade entre contratos e uso real;
- base sólida para billing e governança.

Com esta estrutura, o sistema fica preparado para escalar com segurança e consistência.
