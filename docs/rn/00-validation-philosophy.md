# Filosofia de Validação do Sistema VianaID

## 1. Introdução
Este documento define a filosofia de validação adotada pelo sistema IAM VianaID para todas as operações de mudança de estado (ativação/desativação) em entidades do sistema.

**Data da última atualização:** 2025-01-22  
**Versão:** 1.0

---

## 2. Abordagem Adotada: Validação Explícita (Não-Idempotente)

### 2.1 Definição
O sistema VianaID adota **validação explícita de estado** nas operações de ativação/desativação de todas as entidades.

**Comportamento:**
- Operações de **ativação** requerem que a entidade esteja **inativa** (`IsActive = false`)
- Operações de **desativação** requerem que a entidade esteja **ativa** (`IsActive = true`)
- Tentativas de ativar entidade já ativa ou desativar entidade já inativa retornam **HTTP 400 (Bad Request)**
- A operação **NÃO é idempotente** - o estado atual é validado explicitamente

### 2.2 Exemplo de Implementação
```csharp
// Validator para ativação
RuleFor(x => x.IsActive)
    .Equal(false)
    .WithMessage("A entidade já está ativa");

// Validator para desativação  
RuleFor(x => x.IsActive)
    .Equal(true)
    .WithMessage("A entidade já está inativa");
```

### 2.3 Fluxo de Validação

**Ativação:**
```
1. Validar que entidade existe e pertence ao Tenant correto
2. Validar que entidade não está deletada (IsDeleted = false)
3. ? VALIDAR QUE IsActive = false (retorna 400 se já ativa)
4. Validar dependências (entidades relacionadas ativas, etc.)
5. Atualizar IsActive = true
6. Atualizar UpdatedBy e UpdatedAt
7. Registrar auditoria
```

**Desativação:**
```
1. Validar que entidade existe e pertence ao Tenant correto
2. ? VALIDAR QUE IsActive = true (retorna 400 se já inativa)
3. Validar dependências (entidades dependentes ativas, etc.)
4. Atualizar IsActive = false
5. Atualizar UpdatedBy e UpdatedAt
6. Registrar auditoria
```

---

## 3. Justificativa: Por Que Validação Explícita?

### 3.1 Vantagens de Performance
? **Evita chamadas desnecessárias ao banco de dados**
- Quando a entidade já está no estado desejado, retorna imediatamente
- Não precisa consultar dependências ou executar lógica de negócio complexa

? **Early return otimizado**
- Validação de estado é a primeira verificação após validações básicas
- Economiza processamento de validações mais custosas

? **Reduz carga na infraestrutura**
- Menos queries ao banco de dados
- Menos processamento em validadores
- Menos registros de auditoria desnecessários

? **Melhora tempo de resposta**
- Retorna erro 400 imediatamente
- Não processa operação sem efeito

### 3.2 Vantagens de Qualidade e Confiabilidade
? **Detecta bugs no cliente**
- Chamadas duplicadas são identificadas explicitamente
- Fluxos incorretos de negócio são expostos rapidamente
- Facilita debugging ao tornar erros visíveis

? **Feedback explícito**
- Cliente recebe mensagem clara sobre o problema
- Facilita correção de bugs no código cliente
- Melhora experiência do desenvolvedor

? **Comportamento previsível**
- Estado atual importa e é validado
- Não há "efeitos colaterais silenciosos"
- Facilita raciocínio sobre o código

? **Testabilidade**
- Testes podem validar comportamento esperado explicitamente
- Casos de erro são claros e testáveis
- Reduz ambiguidade em testes

### 3.3 Vantagens de Segurança e Auditoria
? **Logs de auditoria significativos**
- Apenas operações que realmente alteram estado são registradas
- Facilita análise de histórico e troubleshooting
- Reduz ruído nos logs

? **Clareza sobre mudanças reais**
- Auditoria reflete apenas alterações efetivas
- Facilita compliance e rastreabilidade
- Melhora qualidade de relatórios

? **Detecção de comportamento anômalo**
- Múltiplas tentativas de ativar/desativar podem indicar problemas
- Facilita identificação de bugs ou ataques
- Melhora monitoramento de segurança

---

## 4. Comparação com Abordagem Idempotente

### 4.1 Idempotente (NÃO utilizada no VianaID)
```
? Ativar entidade já ativa retorna 200 OK (sem alteração)
? Desativar entidade já inativa retorna 200 OK (sem alteração)
? Sempre consulta banco e valida dependências, mesmo sem necessidade
? Pode ocultar bugs do cliente
? Gera logs de auditoria para operações sem efeito
? Mais custoso em termos de performance
? Menos feedback sobre problemas no cliente
```

**Quando idempotente poderia ser útil:**
- APIs públicas com clientes não confiáveis
- Operações de retry automático em sistemas distribuídos
- Cenários onde duplicação de requests é comum e esperada

**Por que NÃO usamos no VianaID:**
- Sistema IAM interno com clientes conhecidos
- Preferimos expor bugs explicitamente
- Performance é crítica
- Auditoria deve refletir apenas mudanças reais

### 4.2 Explícita (UTILIZADA no VianaID)
```
? Ativar entidade já ativa retorna 400 Bad Request
? Desativar entidade já inativa retorna 400 Bad Request
? Early return ao detectar estado incorreto
? Expõe bugs do cliente explicitamente
? Logs de auditoria apenas para mudanças reais
? Performance otimizada
? Feedback claro sobre problemas
```

---

## 5. Aplicação Consistente em Todo o Sistema

### 5.1 Módulos que Implementam Validação Explícita
Esta filosofia é aplicada **consistentemente** em todos os módulos principais:

| Módulo | Código | Endpoint Ativação | Endpoint Desativação |
|--------|--------|-------------------|----------------------|
| **Plans** | PLAN-* | PATCH /v1/plans/{id}/activate | PATCH /v1/plans/{id}/deactivate |
| **Tenants** | TENT-* | PATCH /v1/tenants/{id}/activate | PATCH /v1/tenants/{id}/deactivate |
| **Subscriptions** | SUBS-* | PATCH /v1/subscriptions/{id}/activate | PATCH /v1/subscriptions/{id}/deactivate |
| **Categories** | CATE-* | PATCH /v1/categories/{id}/activate | PATCH /v1/categories/{id}/deactivate |
| **Applications** | APPL-* | PATCH /v1/applications/{id}/activate | PATCH /v1/applications/{id}/deactivate |
| **Resources** | RESO-* | PATCH /v1/tenants/{tenantId}/resources/{id}/activate | PATCH /v1/tenants/{tenantId}/resources/{id}/deactivate |
| **Actions** | ACTN-* | PATCH /v1/tenants/{tenantId}/actions/{id}/activate | PATCH /v1/tenants/{tenantId}/actions/{id}/deactivate |
| **Permissions** | PERM-* | PATCH /v1/tenants/{tenantId}/permissions/{id}/activate | PATCH /v1/tenants/{tenantId}/permissions/{id}/deactivate |
| **ApplicationRoles** | ROLE-* | PATCH /v1/tenants/{tenantId}/applications/{applicationId}/roles/{id}/activate | PATCH /v1/tenants/{tenantId}/applications/{applicationId}/roles/{id}/deactivate |
| **UserAccounts** | USER-* | PATCH /v1/tenants/{tenantId}/users/{id}/activate | PATCH /v1/tenants/{tenantId}/users/{id}/deactivate |
| **ServiceAccounts** | SVAC-* | PATCH /v1/tenants/{tenantId}/service-accounts/{id}/activate | PATCH /v1/tenants/{tenantId}/service-accounts/{id}/deactivate |

### 5.2 Importância da Consistência
**Consistência é fundamental para:**
- ? Experiência previsível para desenvolvedores
- ? Facilita compreensão e manutenção do código
- ? Reduz surpresas e comportamentos inesperados
- ? Melhora testabilidade e confiabilidade
- ? Simplifica documentação e treinamento
- ? Facilita criação de bibliotecas cliente
- ? Melhora qualidade geral do sistema

---

## 6. Mensagens de Erro Padronizadas

### 6.1 Formato de Resposta de Erro
```json
{
  "type": "https://tools.ietf.org/html/rfc7231#section-6.5.1",
  "title": "One or more validation errors occurred.",
  "status": 400,
  "errors": {
    "IsActive": [
      "Resource já está ativo"
    ]
  }
}
```

### 6.2 Mensagens por Operação
**Ativação:**
- `"{Entidade} já está ativo"` (masculino)
- `"{Entidade} já está ativa"` (feminino)

**Desativação:**
- `"{Entidade} já está inativo"` (masculino)
- `"{Entidade} já está inativa"` (feminino)

**Exemplos:**
- "Resource já está ativo"
- "Action já está ativa"
- "Permission já está ativa"
- "ApplicationRole já está ativo"
- "Category já está ativa"

### 6.3 Localização
As mensagens devem estar disponíveis nos arquivos de localização:
- `src/VianaHub.VianaID.Api/Localization/messages.pt-BR.json`
- `src/VianaHub.VianaID.Api/Localization/messages.en-US.json` (futuro)

---

## 7. Diretrizes para Implementação

### 7.1 Checklist para Novos Módulos
Ao implementar operações de ativação/desativação em novos módulos:

- [ ] Criar validator para ativação validando `IsActive = false`
- [ ] Criar validator para desativação validando `IsActive = true`
- [ ] Adicionar mensagens de erro localizadas
- [ ] Implementar testes para cenário de entidade já ativa
- [ ] Implementar testes para cenário de entidade já inativa
- [ ] Documentar comportamento nas regras de negócio
- [ ] Validar consistência com outros módulos
- [ ] Atualizar documentação da API (OpenAPI/Swagger)

### 7.2 Ordem de Validações
A validação de estado deve ocorrer **após** validações básicas e **antes** de validações custosas:

```
1. Validações básicas (entidade existe, não está deletada, pertence ao tenant)
2. ? VALIDAÇÃO DE ESTADO (IsActive)
3. Validações de dependências (consultas ao banco)
4. Validações de negócio complexas
5. Execução da operação
```

### 7.3 Tratamento de Exceções
```csharp
// ? NÃO FAZER (idempotente)
if (entity.IsActive)
{
    return Ok(); // Silenciosamente ignora
}

// ? FAZER (explícito)
if (entity.IsActive)
{
    return BadRequest(new { error = "Entidade já está ativa" });
}
```

---

## 8. Casos Especiais

### 8.1 Operações em Lote (Batch)
Para operações em lote (ativar/desativar múltiplas entidades):
- Validar estado de cada entidade individualmente
- Retornar lista de sucessos e falhas
- Não interromper processamento em primeira falha
- Registrar auditoria apenas para operações bem-sucedidas

### 8.2 Operações Administrativas de Emergência
Em casos excepcionais de manutenção ou correção:
- Pode-se ter endpoint separado com comportamento diferente
- Deve exigir permissões elevadas
- Deve ter auditoria especial
- Deve ser usado apenas em situações excepcionais

### 8.3 Migrações e Scripts de Dados
Em scripts de migração ou correção de dados:
- Pode-se usar lógica condicional para evitar erros
- Validação pode ser relaxada com flag especial
- Deve gerar relatório de operações executadas
- Deve ter log detalhado de todas as mudanças

---

## 9. Monitoramento e Métricas

### 9.1 Métricas Recomendadas
- **Taxa de erro 400 em operações de ativação/desativação**: indica bugs no cliente
- **Frequência de tentativas duplicadas por cliente**: identifica problemas específicos
- **Distribuição de erros por módulo**: identifica módulos problemáticos
- **Tendências ao longo do tempo**: melhoria ou degradação de qualidade

### 9.2 Alertas
Configurar alertas para:
- Taxa anormalmente alta de erros 400 nessas operações
- Picos repentinos de tentativas duplicadas
- Padrões suspeitos de uso (possível ataque ou bug grave)

---

## 10. Evolução Futura

### 10.1 Possíveis Extensões
**Headers personalizados:**
```
X-Idempotent: true
```
- Cliente pode requisitar comportamento idempotente explicitamente
- Sistema pode suportar ambos os modos
- Deve ser opt-in, não padrão

**Versão da API:**
```
/v2/resources/{id}/activate?mode=idempotent
```
- Versão futura da API pode oferecer opção
- Mantém retrocompatibilidade
- Permite migração gradual

### 10.2 Feedback da Comunidade
- Coletar feedback de desenvolvedores usando a API
- Avaliar impacto real da abordagem explícita
- Considerar ajustes baseados em uso real
- Manter documentação atualizada com aprendizados

---

## 11. Referências

### 11.1 Documentos Relacionados
- [00-code-generation-business-rules.md](./00-code-generation-business-rules.md) - Geração de códigos únicos
- [11-resource-business-rules.md](./11-resource-business-rules.md) - Seção 14: Filosofia de Validação
- [12-action-business-rules.md](./12-action-business-rules.md) - Ativação e Desativação
- [13-permission-business-rules.md](./13-permission-business-rules.md) - Ativação e Desativação
- [14-application-role-business-rules.md](./14-application-role-business-rules.md) - Ativação e Desativação

### 11.2 Padrões REST
- [RFC 7231 - HTTP/1.1 Semantics](https://tools.ietf.org/html/rfc7231)
- [RFC 7807 - Problem Details for HTTP APIs](https://tools.ietf.org/html/rfc7807)

### 11.3 Boas Práticas
- [RESTful API Design Guidelines](https://restfulapi.net/)
- [Microsoft REST API Guidelines](https://github.com/microsoft/api-guidelines)

---

## 12. Conclusão

A filosofia de **validação explícita (não-idempotente)** adotada pelo VianaID oferece:

? **Performance superior** através de early return e redução de processamento desnecessário

? **Qualidade aprimorada** através de detecção explícita de bugs no cliente

? **Auditoria significativa** registrando apenas mudanças reais de estado

? **Experiência consistente** aplicada uniformemente em todo o sistema

? **Manutenibilidade** através de comportamento previsível e bem documentado

Esta abordagem foi cuidadosamente escolhida para maximizar performance, confiabilidade e qualidade do sistema IAM VianaID, garantindo uma base sólida para evolução futura.

**Revisão:** Este documento deve ser revisado semestralmente ou quando houver mudanças significativas na arquitetura do sistema.

---

**Última atualização:** 2025-01-22  
**Próxima revisão:** 2025-07-22  
**Responsável:** Equipe de Arquitetura VianaID
