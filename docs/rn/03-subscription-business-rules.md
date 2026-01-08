# Documento de Regras de Negócio — Subscriptions

## 1. Introdução
Este documento descreve as regras de negócio necessárias para o módulo **Subscriptions**, valida se estão alinhadas com as rotas REST já desenvolvidas e identifica eventuais regras adicionais que se tornam necessárias com base nas operações expostas.

As subscriptions representam a relação entre um **Tenant** e um **Plano**, controlando período vigente, trial, cancelamentos e estado da assinatura.

---

## 2. Estrutura Geral da Subscription

Uma **Subscription** contém:
- `Id` (Guid único)
- `Code` (código técnico gerado automaticamente pelo sistema) ⭐ **NOVO**
- `TenantId` (FK para Tenants)
- `PlanId` (FK para Plans)
- Período vigente (`CurrentPeriodStart`, `CurrentPeriodEnd`)
- Período de trial (`TrialStart`, `TrialEnd`)
- Cancelamento (`CancelAtPeriodEnd`, `CanceledAt`, `CancellationReason`)
- Integração Stripe (`StripeCustomerId`, `StripeSubscriptionId`)
- Estado (`Status`, `IsActive`, `IsDeleted`)
- Auditoria (`CreatedBy`, `CreatedAt`, `UpdatedBy`, `UpdatedAt`)

### 2.1 Regras do campo Code ⭐

- O campo **`Code` nunca é informado pelo usuário**.
- O campo **`Code` é imutável** e **nunca pode ser alterado** após a criação da subscription.
- O `Code` é **gerado automaticamente pela aplicação**, utilizando o componente `CodeGenerator`.
- O formato do código segue obrigatoriamente o padrão definido em `00-code-generation-business-rules.md`:

```
<PREFIXO><YYMMDD><HASH>
```

Onde:
- **SUBS**: prefixo fixo que identifica o recurso Subscription.
- **YYMMDD**: data UTC de geração do código.
- **HASH**: sequência alfanumérica aleatória de 4 caracteres.

**Exemplo válido:**
```
SUBS251230XTG2  ← Subscription criada em 30/12/2025
```

- A unicidade do `Code` é garantida pelo sistema através de índice único no banco de dados.
- Qualquer tentativa de envio ou alteração manual do campo `Code` deve ser ignorada ou rejeitada pela API.

**Uso do Code:**
- Identificação única legível para humanos
- Referência em logs e auditoria
- Comunicação com clientes (emails, faturas, suporte)
- Integrações externas (webhooks, billing, relatórios)
- Troubleshooting e debugging

Para detalhes completos sobre o padrão de geração de códigos, consulte: `docs/rn/00-code-generation-business-rules.md`

---

## 3. Regras de Negócio Existentes

### 3.1. Criar assinatura (POST /v1/subscriptions)
- Um Tenant pode possuir **apenas uma assinatura ativa** por vez.
- O **Plano deve existir** e estar ativo.
- O campo **`Code` é gerado automaticamente** no momento da criação (nunca enviado pelo usuário).
- Caso start de trial seja solicitado:
  - `TrialStart` = data/hora atual (UTC)
  - `TrialEnd` = data definida pelo negócio (fixa, por configuração ou enviada no payload)
  - Durante trial, `CurrentPeriodStart` pode permanecer nulo até o fim da trial ou iniciar imediatamente conforme a política.
- Caso **não** haja trial:
  - `CurrentPeriodStart` = agora
  - `CurrentPeriodEnd` = agora + duração padrão (30 dias ou configurável)
- Registar `CreatedBy` com o utilizador que executa a operação.
- A assinatura é criada com `IsActive = true` e `IsDeleted = false`.

### 3.2. Listagem e consulta (GET /v1/subscriptions, GET /v1/subscriptions/{id}, GET /v1/subscriptions/paged)
- Devem retornar apenas subscriptions **não apagadas** (`IsDeleted = false`).
- O campo **`Code` deve ser incluído em todas as respostas** para facilitar rastreabilidade.
- Para sistemas multi-tenant, devem respeitar políticas de RLS ou TenantId no contexto.
- Paginação deve aplicar filtros opcionais (status, tenant, plano, code, intervalos, etc.).
- Suportar busca por `Code` para facilitar troubleshooting.

### 3.3. Atualizar assinatura (PUT /v1/subscriptions/{id})
- O campo **`Code` não pode ser alterado** (é imutável).
- Permite alterar:
  - Plano ativo
  - Cancelamento ao final do período (`CancelAtPeriodEnd`)
  - Motivo de cancelamento
- Troca de plano:
  - Validar se o novo plano existe e está ativo.
  - Pode aplicar regra: troca de plano só surte efeito no próximo período, a menos que exista política de ajuste imediato.
- Se cancelar ao final do período:
  - `CancelAtPeriodEnd = true`
  - se ainda não cancelada, não deve definir `CanceledAt` imediatamente.
- Atualizar `UpdatedAt` e `UpdatedBy`.

### 3.4. Ativar assinatura (PATCH /v1/subscriptions/{id}/activate)
**Contexto:** Reativar uma assinatura previamente desativada.

**Regras:**
- Apenas subscriptions **não apagadas** podem ser ativadas.
- **A subscription deve estar inativa** (`IsActive = false`) para ser ativada.
- Validar se o Tenant e o Plano ainda estão ativos.
- Se estiver cancelada, a regra deve definir:
  - se é permitido reativar **após** período encerrado
  - se deve iniciar um novo ciclo automaticamente
- Define `IsActive = true`.
- Pode exigir: limpar flags de cancelamento se aplicável.
- Atualizar `UpdatedBy` e `UpdatedAt`.

**Validações:**
- A subscription deve existir e não estar deletada.
- **A subscription não pode estar já ativa** - retorna erro 400 se tentar ativar uma subscription que já está ativa.
- O Tenant e o Plano associados devem estar ativos.
- A operação **não é idempotente** - valida o estado atual e retorna erro se já estiver no estado desejado.

**Motivo da validação explícita:**
- Evita chamadas desnecessárias ao banco de dados quando a subscription já está ativa.
- Detecta bugs no cliente que fazem chamadas duplicadas.
- Melhora a performance ao fazer "early return" sem validar dependências desnecessariamente.
- Fornece feedback explícito sobre tentativas de operação inválidas.

**Auditoria:**
- Registrar ativação em `AuditLogs`.
- Incluir `Code` da subscription nos logs para rastreabilidade.
- Incluir contexto do usuário que ativou.

---

### 3.5. Desativar assinatura (PATCH /v1/subscriptions/{id}/deactivate)
**Contexto:** Desativar uma assinatura temporariamente.

**Regras:**
- **A subscription deve estar ativa** (`IsActive = true`) para ser desativada.
- Define `IsActive = false`.
- Não remove a assinatura, apenas a torna inativa.
- Uma assinatura desativada não deve permitir cobranças automáticas nem renovação.
- Atualizar `UpdatedBy` e `UpdatedAt`.

**Validações:**
- A subscription deve existir e estar ativa.
- **A subscription não pode estar já inativa** - retorna erro 400 se tentar desativar uma subscription que já está inativa.
- A operação **não é idempotente** - valida o estado atual e retorna erro se já estiver no estado desejado.

**Motivo da validação explícita:**
- Evita chamadas desnecessárias ao banco de dados.
- Detecta bugs no cliente que fazem chamadas duplicadas.
- Melhora a performance ao fazer "early return" sem processar operação desnecessária.
- Fornece feedback explícito sobre tentativas de operação inválidas.

**Impacto:**
- Durante desativação, garantir que não há tentativas de renovar o ciclo.
- Definir impacto em pagamentos automáticos (ex.: Stripe).
- Considerar notificação do Tenant sobre a desativação.

**Auditoria:**
- Registrar desativação em `AuditLogs` com motivo (se fornecido).
- Incluir `Code` da subscription nos logs para rastreabilidade.

### 3.6. Cancelar assinatura (PATCH /v1/subscriptions/{id}/cancel)
Dois tipos de cancelamento:
- **Cancelamento ao fim do período**:
  - `CancelAtPeriodEnd = true`
  - `CanceledAt` continua nulo.
- **Cancelamento imediato** (caso suportado pelo produto):
  - `CanceledAt = agora`
  - `IsActive = false`
  - Pode encurtar o período vigente (`CurrentPeriodEnd = agora`).
- Registar `CancellationReason` quando enviado.
- Incluir `Code` da subscription em notificações de cancelamento.

### 3.7. Remover assinatura (DELETE /v1/subscriptions/{id}) — Soft delete
- Definir `IsDeleted = true`.
- `IsActive` deve ser automaticamente definido para `false`.
- Não deve permitir remoção se a assinatura estiver em período ativo, **a menos** que isso seja política intencional.
- Deve manter integridade histórica: não apagar registos dependentes.
- O `Code` permanece no registro para histórico e auditoria.

---

## 4. Validação das Regras de Negócio vs Rotas Implementadas

### 4.1 Cobertura adequada pelas rotas
As rotas existentes permitem:
- Criar subscription ✔
- Consultar individualmente, listar e paginar ✔
- Buscar por Code ✔ (sugerido)
- Atualizar subscription ✔
- Ativar e desativar ✔
- Cancelar ✔
- Apagar via soft delete ✔

Ou seja, todas as operações principais encontram-se representadas.

### 4.2 Rotas sugeridas adicionais

#### 🔹 `GET /v1/subscriptions/by-code/{code}` (Opcional)
- Facilita busca por código legível
- Útil para suporte ao cliente
- Melhora troubleshooting

### 4.3 Rotas que exigem regras adicionais
Algumas rotas **introduzem necessidades de negócio adicionais**:

#### 🔹 `PATCH /activate`
- Regras necessárias:
  - Não permitir ativar uma assinatura apagada.
  - Validar se assinaturas canceladas podem ou não ser reativadas.
  - Se já passou do período atual, deve iniciar um novo período automaticamente.

#### 🔹 `PATCH /deactivate`
- Regras necessárias:
  - Durante desativação, garantir que não há tentativas de renovar o ciclo.
  - Definir impacto em pagamentos automáticos (ex.: Stripe).

#### 🔹 `PATCH /cancel`
- Regras adicionais:
  - Se `CancelAtPeriodEnd = true`, impedir novos cancelamentos imediatos a menos que permitido.
  - Se cancelamento imediato for permitido, definir política clara de reembolsos ou ajustes.

#### 🔹 `DELETE /soft delete`
- Regras necessárias:
  - Impedir excluir uma assinatura ativa sem cancelamento prévio, caso o negócio assim defina.
  - Soft delete deve impedir qualquer operação futura (exceto leitura histórica, se existir).

---

## 5. Regras de Negócio Adicionais Necessárias
Com base nas rotas, as seguintes regras ainda precisam ser formalizadas:

### ✔ 5.1. Política de mudança de plano
- Imediata ou ao fim do ciclo?
- Como tratar diferença de preços? (proporcional, ignorado, bloqueado?)

### ✔ 5.2. Política de reativação
- Pode reativar assinatura já cancelada?
- E se o ciclo já expirou?
- Deve gerar novo período automaticamente?

### ✔ 5.3. Política de cancelamento imediato
- É permitido? Sempre? Apenas admin?
- Deve encerrar ciclo?

### ✔ 5.4. Regras específicas para integração de pagamento (Stripe ou outro)
- Quando criar StripeCustomerId?
- Quando gerar StripeSubscriptionId?
- O cancelamento via API deve cancelar no Stripe também?
- Incluir `Code` em metadados do Stripe para correlação?

### ✔ 5.5. Garantia de unicidade de subscription ativa por Tenant
- Necessário validar isso em todos os endpoints relevantes: create, activate, update.

### ✔ 5.6. Validação de integridade temporal
- `CurrentPeriodStart < CurrentPeriodEnd`
- `TrialStart < TrialEnd`
- Não permitir que datas enviadas manualmente criem cenários inconsistentes.

---

## 6. Rastreabilidade e Integração

### 6.1 Uso do Code em Integrações
- **Webhooks**: Incluir `Code` em payloads de eventos
- **Stripe**: Armazenar `Code` em metadata para correlação
- **Emails**: Referenciar subscription pelo `Code` em comunicações com clientes
- **Suporte**: Clientes podem informar o `Code` para identificação rápida
- **Relatórios**: Usar `Code` para rastreamento em dashboards e análises

### 6.2 Logs e Auditoria
- Todas as operações devem logar o `Code` da subscription
- Formato sugerido de log:
  ```
  [INFO] Subscription SUBS251230XTG2 activated by user USER251220AB34
  [WARN] Subscription SUBS251230XTG2 cancelled - Reason: Customer request
  ```

---

## 7. Histórico de Alterações

| Data | Versão | Descrição |
|------|--------|-----------|
| 30/12/2025 | 1.1 | Adição do campo Code e regras associadas |
| - | 1.0 | Versão inicial |

---

## 8. Referências

- **Documento Normativo de Códigos**: `docs/rn/00-code-generation-business-rules.md`
- **Refatoração Subscription**: `docs/REFACTORING_SUBSCRIPTION_CODE.md`
- **Análise de Conformidade**: `docs/ANALYSIS_CODE_FIELD_COMPLIANCE.md`

---

## 9. Conclusão
As regras de negócio inicialmente definidas estão **alinhadas** com as rotas existentes. No entanto, algumas operações introduzidas pelas rotas exigem **regras adicionais obrigatórias**, principalmente relacionadas a:

- transições de estado (ativar, desativar, cancelar),
- mudança de plano,
- impacto temporal nos ciclos de billing,
- políticas de reativação e remoção,
- compatibilidade com mecanismos futuros de cobrança.

Com a adoção destas regras adicionais e a inclusão do campo **`Code`** para rastreabilidade, o módulo de Subscriptions fica coerente, completo e preparado para integrações externas e evolução futura.

---

**Status**: ✅ Atualizado em 30/12/2025 com campo Code

