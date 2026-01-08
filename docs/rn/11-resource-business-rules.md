# Documento de Regras de Negócio — Resources

## 1. Introdução
Este documento descreve de forma detalhada as regras de negócio do módulo **Resources** no sistema IAM (VianaID).

Um **Resource** representa um recurso protegido da plataforma (APIs, endpoints, funcionalidades, domínios, etc.) sobre o qual Actions podem ser executadas no contexto de um Tenant.  Os Resources são componentes essenciais do sistema de permissões, definindo "o que" pode ser acessado ou manipulado. 

---

## 2. Objetivos do Módulo de Resources
- Definir recursos protegidos disponíveis na plataforma
- Servir como componente base para construção de permissões granulares  
- Permitir mapeamento direto com APIs, endpoints, funcionalidades e domínios
- Garantir consistência e reutilização de recursos entre diferentes contextos
- Facilitar auditoria e controle de acesso baseado em recursos específicos
- Suportar isolamento multi-tenant de recursos customizados
- Organizar recursos em categorias lógicas para melhor governança

---

## 3. Estrutura Geral do Resource
Um **Resource** contém:
- `Id`
- `TenantId` (FK para Tenants)
- `CategoryId` (FK para Categories)
- `Code` (código técnico gerado automaticamente pelo sistema)
- `Name` (nome do recurso)
- `Description` (descrição detalhada)
- Estado (`Status`, `IsActive`, `IsDeleted`)
- Auditoria (`CreatedBy`, `CreatedAt`, `UpdatedBy`, `UpdatedAt`)

### 3.1 Regras do campo Code
- O campo **`Code` nunca é informado pelo usuário**
- O campo **`Code` é imutável** e **nunca pode ser alterado** após a criação
- O `Code` é **gerado automaticamente pela aplicação**, utilizando o componente `CodeGenerator`
- O formato do código segue obrigatoriamente o padrão: 

```
<PREFIXO><YYMMDD><HASH>
```

Onde:
- **RESO**:   prefixo fixo que identifica o recurso Resource (conforme 00-code-generation-business-rules.md)
- **YYMMDD**: data UTC de geração do código
- **HASH**: sequência alfanumérica aleatória de 4 caracteres

**Exemplo válido:**
```
RESO251221XTG2
```

- A unicidade do `Code` é garantida pelo sistema
- Qualquer tentativa de envio ou alteração manual do campo `Code` deve ser ignorada ou rejeitada pela API

### 3.2 Escopo Multi-tenant
- Todo Resource pertence exatamente a um Tenant específico
- Resources são isolados por Tenant através de Row-Level Security (RLS)
- Um Tenant não pode acessar Resources de outros Tenants
- Resources podem ser utilizados em diferentes Permissions do mesmo Tenant
- Consultas e operações devem sempre respeitar o contexto do Tenant autenticado

### 3.3 Categorização
- Todo Resource deve estar associado a uma Category válida do mesmo Tenant
- A Category permite organização lógica e facilita governança
- Resources da mesma categoria compartilham características funcionais similares
- Exemplos de Categories:   "User Management", "Financial APIs", "Reporting", "Administration"

### 3.4 Tipos de Resources
**APIs e Endpoints:**
- Recursos que representam endpoints REST específicos
- Exemplos: "User API", "Payment API", "Reports API"

**Funcionalidades:**
- Recursos que representam funcionalidades específicas do sistema
- Exemplos: "Dashboard", "User Profile", "Billing Module"

**Domínios:**
- Recursos que representam domínios ou áreas funcionais completas
- Exemplos: "Financial Management", "User Administration", "Security Center"

**Dados:**
- Recursos que representam conjuntos de dados específicos
- Exemplos: "Customer Data", "Transaction History", "Audit Logs"

---

## 4. Regras de Negócio por Operação

### 4.1 Criar Resource (POST /v1/tenants/{tenantId}/resources)
**Contexto:** Criação de um novo recurso no contexto de um Tenant específico.  

**Regras:**
- O Resource é criado com `IsActive = true` e `IsDeleted = false`
- O campo `Code` é gerado automaticamente
- O campo `Name` é obrigatório e deve ser único dentro do Tenant
- O campo `TenantId` deve corresponder ao Tenant do contexto da requisição
- O campo `CategoryId` deve referenciar uma Category válida e ativa do mesmo Tenant
- O campo `Description` é opcional mas recomendado para documentação
- O `CreatedBy` deve ser preenchido com o ID do usuário autenticado
- O `Status` deve ser inicializado com valor padrão (1 - Ativo)

**Validações:**
- O Tenant deve existir, estar ativo e não deletado
- A Category deve existir, estar ativa, não deletada e pertencer ao mesmo Tenant
- O `Name` deve ser único dentro do escopo do Tenant (constraint de unicidade por Tenant)
- O usuário deve ter permissão para criar Resources no Tenant
- O `Name` deve seguir convenções de nomenclatura (sem caracteres especiais prejudiciais)

**Pós-criação:**
- Registrar evento de auditoria da criação
- O Resource fica disponível para uso em Permissions imediatamente

---



### 4.2 Cadastro Massivo de Recursos via Upload de CSV

**POST** `/resources/bulk-upload`

Permite o cadastro massivo de recursos através do upload de um arquivo CSV.
O sistema carrega todo o conteúdo do arquivo em memória e realiza o processamento de forma síncrona.

A rota aceita **exclusivamente arquivos no formato CSV**.

#### Estrutura do Arquivo CSV

| Coluna       | Tipo   | Obrigatório | Descrição |
|-------------|--------|-------------|-----------|
| categoryId  | GUID   | Sim         | Identificador da categoria |
| name        | string | Sim         | Nome do recurso |
| description | string | Sim         | Descrição do recurso |

#### Regras
- O arquivo é carregado integralmente em memória.
- O sistema tenta processar todas as linhas do arquivo.
- Não é permitido cadastro parcial.
- Apenas arquivos `.csv` são aceitos.

#### Respostas
- **200 OK**: todos os recursos cadastrados com sucesso (sem body).
- **400 Bad Request**: retorna a lista de recursos que não foi possível cadastrar, com o motivo da falha.

### 4.3 Consultar Resources (GET /v1/tenants/{tenantId}/resources)
**Contexto:** Listar todos os Resources de um Tenant específico.

**Regras:**
- Devem ser retornados apenas Resources não deletados (`IsDeleted = false`)
- Aplicar isolamento por Tenant através de RLS ou filtro explícito
- Aplicar filtros opcionais por:  
  - `CategoryId` (Resources de uma categoria específica)
  - `IsActive` (ativos ou inativos)
  - `Name` (busca parcial case-insensitive)
  - `CreatedAt` (filtros de data de criação)
- Ordenação padrão: `CategoryId ASC, Name ASC`
- Suportar paginação obrigatória para melhor performance

**Projeção de dados:**
- Incluir todos os campos do Resource
- Incluir dados básicos da Category associada (Name, Description)
- Incluir contador de quantas Permissions utilizam este Resource (opcional)
- Incluir indicador de última utilização em Permissions (opcional)

**Permissões:**
- Apenas usuários com permissão de leitura de Resources no Tenant podem consultar
- Aplicar RLS automaticamente baseado no TenantId do contexto

---

### 4.4 Consultar Resource por ID (GET /v1/tenants/{tenantId}/resources/{id})
**Contexto:** Obter detalhes de um Resource específico.

**Regras:**
- Retornar apenas se o Resource pertencer ao Tenant especificado
- Não retornar Resources deletados
- Incluir informações detalhadas da Category associada
- Incluir lista de Actions que podem ser executadas sobre este Resource através de Permissions (opcional)
- Incluir estatísticas de uso em Permissions (opcional)

**Validações:**
- O Resource deve existir e pertencer ao Tenant do contexto
- O Resource não pode estar deletado
- Aplicar RLS baseado no TenantId

**Permissões:**
- Mesmo controle de acesso da listagem geral

---

### 4.5 Consultar Resource por Code (GET /v1/tenants/{tenantId}/resources/code/{code})
**Contexto:** Buscar Resource pelo código único gerado automaticamente.

**Regras:**
- Buscar Resource pelo campo `Code` único
- Retornar 404 se não encontrado, deletado ou não pertencer ao Tenant
- Mesmas regras de projeção da consulta por ID

**Validações:**
- O código deve existir e pertencer ao Tenant especificado
- Aplicar mesmo controle de acesso das outras consultas

---

### 4.6 Atualizar Resource (PUT /v1/tenants/{tenantId}/resources/{id})
**Contexto:** Modificar um Resource existente. 

**Regras:**
- O campo `Code` **não pode ser alterado**
- O campo `TenantId` **não pode ser alterado**
- Campos que podem ser alterados:
  - `Name` (deve manter unicidade dentro do Tenant)
  - `Description`
  - `CategoryId` (deve ser Category válida do mesmo Tenant)
  - `IsActive`
- Atualizar `UpdatedBy` com ID do usuário autenticado
- Atualizar `UpdatedAt` com data/hora atual

**Validações:**
- O Resource deve existir, pertencer ao Tenant e não estar deletado
- Se `Name` for alterado, deve manter unicidade dentro do Tenant
- Se `CategoryId` for alterado, a nova Category deve existir, estar ativa e pertencer ao mesmo Tenant
- Não permitir alteração se o Resource estiver sendo utilizado em Permissions críticas (regra configurável)

**Impacto em dependências:**
- Alterações no Resource podem afetar Permissions que o utilizam
- Se `IsActive` for alterado para `false`, verificar impacto em Permissions ativas
- Considerar notificação ou validação prévia se há dependências críticas

**Auditoria:**
- Registrar alteração em `AuditLogs` com valores antigos e novos
- Incluir contexto do usuário que fez a alteração

---

### 4.7 Ativar Resource (PATCH /v1/tenants/{tenantId}/resources/{id}/activate)
**Contexto:** Reativar um Resource previamente desativado.

**Regras:**
- Só é permitido ativar um Resource existente, não deletado e pertencente ao Tenant
- **O Resource deve estar inativo** (`IsActive = false`) para ser ativado
- Atualizar `IsActive = true`
- Atualizar `UpdatedBy` e `UpdatedAt`

**Validações:**
- O Resource deve existir e pertencer ao Tenant
- O Resource não pode estar deletado
- **O Resource não pode estar já ativo** - retorna erro 400 se tentar ativar um Resource que já está ativo
- A operação **não é idempotente** - valida o estado atual e retorna erro se já estiver no estado desejado

**Motivo da validação explícita:**
- Evita chamadas desnecessárias ao banco de dados quando o Resource já está ativo
- Detecta bugs no cliente que fazem chamadas duplicadas
- Melhora a performance ao fazer "early return" sem validar dependências desnecessariamente
- Fornece feedback explícito sobre tentativas de operação inválidas

**Auditoria:**
- Registrar ativação em `AuditLogs`
- Incluir contexto do usuário que ativou

---

### 4.8 Desativar Resource (PATCH /v1/tenants/{tenantId}/resources/{id}/deactivate)
**Contexto:** Desativar um Resource temporariamente.

**Regras:**
- Só é permitido desativar um Resource ativo, não deletado e pertencente ao Tenant
- **O Resource deve estar ativo** (`IsActive = true`) para ser desativado
- Atualizar `IsActive = false`
- Atualizar `UpdatedBy` e `UpdatedAt`

**Validações:**
- O Resource deve existir, pertencer ao Tenant e estar ativo
- **O Resource não pode estar já inativo** - retorna erro 400 se tentar desativar um Resource que já está inativo
- Verificar se existem Permissions ativas que utilizam este Resource
- Opcionalmente, impedir desativação se há dependências críticas
- A operação **não é idempotente** - valida o estado atual e retorna erro se já estiver no estado desejado

**Motivo da validação explícita:**
- Evita chamadas desnecessárias ao banco de dados e verificação de dependências
- Detecta bugs no cliente que fazem chamadas duplicadas
- Melhora a performance ao fazer "early return" sem processar operação desnecessária
- Fornece feedback explícito sobre tentativas de operação inválidas

**Impacto:**
- Resources desativados não devem ser utilizados em novas Permissions
- Permissions existentes podem ser afetadas (dependendo da implementação)
- Considerar notificação de usuários afetados

**Auditoria:**
- Registrar desativação em `AuditLogs` com motivo (se fornecido)

---

### 4.9 Remover Resource (DELETE /v1/tenants/{tenantId}/resources/{id}) — Exclusão lógica
**Contexto:** Excluir logicamente um Resource.  

**Regras:**
- Resources não podem ser removidos se estiverem sendo utilizados em Permissions ativas
- Aplicar soft delete:  
  - `IsDeleted = true`
  - `IsActive = false`
  - `UpdatedBy` = ID do usuário autenticado
  - `UpdatedAt` = data/hora atual

**Validações:**
- O Resource deve existir e pertencer ao Tenant
- O Resource não pode estar já deletado
- Verificar se não há Permissions ativas que utilizam este Resource
- Se houver dependências, retornar erro específico com detalhes

**Auditoria:**
- Registrar exclusão em `AuditLogs` com motivo (se fornecido)
- Incluir informações sobre dependências verificadas

---

## 5. Regras de Integridade e Dependência

### 5.1 Dependências obrigatórias
- Todo Resource deve referenciar um `TenantId` válido e ativo
- Todo Resource deve referenciar uma `CategoryId` válida, ativa e do mesmo Tenant
- A combinação `TenantId` + `Name` deve ser única (constraint de unicidade)

### 5.2 Integridade referencial
- Resources são referenciados por Permissions através de `ResourceId`
- Não permitir exclusão de Resources que estejam sendo utilizados
- Implementar verificação de dependências antes de operações destrutivas

### 5.3 Cascata de operações
**Desativação de Category:**
- Considerar desativação automática de todos os Resources da Category
- Notificar administradores sobre impacto

**Desativação de Tenant:**
- Desativar automaticamente todos os Resources do Tenant
- Não permitir criação de novos Resources

### 5.4 Consistência de dados
- Resources ativos devem sempre ter Category ativa associada
- Manter consistência temporal entre criação/atualização de registros relacionados
- Garantir que References órfãos não sejam criados

---

## 6. Regras de Segurança

### 6.1 Isolamento multi-tenant
- Implementar Row-Level Security (RLS) baseado em TenantId
- Todas as consultas devem automaticamente filtrar pelo Tenant do contexto
- Validar TenantId em todas as operações para prevenir vazamento de dados

### 6.2 Controle de acesso
**Permissões necessárias:**
- **Criar Resource:** Permissão de escrita em Resources no Tenant
- **Consultar Resources:** Permissão de leitura em Resources no Tenant
- **Atualizar Resource:** Permissão de escrita em Resources no Tenant
- **Ativar/Desativar:** Permissão de gerenciamento em Resources no Tenant
- **Remover Resource:** Permissão de exclusão em Resources no Tenant

### 6.3 Auditoria de segurança
- Registrar todas as operações críticas (criação, alteração, remoção)
- Incluir contexto completo do usuário (IP, User Agent, etc.)
- Monitorar tentativas de acesso cross-tenant

### 6.4 Validação de entrada
- Sanitizar campos de texto para prevenir XSS
- Validar tamanhos máximos de campos
- Validar formatos de nomes e códigos

### 6.5 Proteção de recursos críticos
- Resources críticos para funcionamento do sistema devem ter proteção adicional
- Considerar flag `IsCritical` para resources que não podem ser facilmente removidos
- Implementar aprovação multi-step para alterações em resources críticos

---

## 7. Regras de Governança

### 7.1 Naming conventions
**Name:**
- Use PascalCase ou kebab-case consistentemente
- Seja descritivo e específico
- Evite abreviações desnecessárias
- Exemplos: `UserManagementAPI`, `PaymentProcessor`, `ReportingDashboard`

### 7.2 Categorização
- Resources devem ser agrupados em Categories lógicas apropriadas
- Evitar Resources órfãos ou mal categorizados
- Revisar periodicamente a organização de Categories
- Manter hierarquia lógica de recursos

### 7.3 Documentação
- Todo Resource deve ter `Description` preenchida
- Documentar o propósito, escopo e contexto de uso
- Incluir informações sobre APIs ou funcionalidades que representa
- Manter documentação atualizada com mudanças

### 7.4 Versionamento
- Resources são estáveis após criação
- Mudanças breaking devem ser evitadas
- Considerar criação de novo Resource em vez de alteração drástica
- Manter compatibilidade retroativa quando possível

### 7.5 Lifecycle management
- Definir ciclo de vida claro para Resources
- Processos para deprecation de Resources obsoletos
- Migração de dependências antes de remoção
- Comunicação prévia de mudanças impactantes

---

## 8. Exemplos de Resources Padrão

### 8.1 Resources de API
```json
[
  {
    "name": "User Management API",
    "description": "API para gerenciamento de usuários",
    "category": "User Management"
  },
  {
    "name": "Authentication API",
    "description": "API para autenticação e autorização",
    "category": "Security"
  },
  {
    "name": "Payment Processing API",
    "description": "API para processamento de pagamentos",
    "category": "Financial"
  },
  {
    "name": "Reporting API",
    "description": "API para geração de relatórios",
    "category": "Analytics"
  }
]
```

### 8.2 Resources de Funcionalidade
```json
[
  {
    "name":   "Admin Dashboard",
    "description": "Painel administrativo principal",
    "category": "Administration"
  },
  {
    "name":  "User Profile",
    "description": "Funcionalidade de perfil do usuário",
    "category": "User Management"
  },
  {
    "name": "Billing Module",
    "description": "Módulo de faturamento e cobrança",
    "category":  "Financial"
  },
  {
    "name":   "Audit Viewer",
    "description": "Visualizador de logs de auditoria",
    "category": "Security"
  }
]
```

### 8.3 Resources de Dados
```json
[
  {
    "name":   "Customer Database",
    "description": "Base de dados de clientes",
    "category": "Data Management"
  },
  {
    "name":  "Transaction History",
    "description": "Histórico de transações",
    "category":   "Financial"
  },
  {
    "name":  "System Configuration",
    "description": "Configurações do sistema",
    "category":   "Administration"
  }
]
```

---

## 9. Estrutura da API

### 9.1 Endpoints
```
GET    /v1/tenants/{tenantId}/resources
GET    /v1/tenants/{tenantId}/resources/{id}
GET    /v1/tenants/{tenantId}/resources/code/{code}
POST   /v1/tenants/{tenantId}/resources
PUT    /v1/tenants/{tenantId}/resources/{id}
PATCH  /v1/tenants/{tenantId}/resources/{id}/activate
PATCH  /v1/tenants/{tenantId}/resources/{id}/deactivate
DELETE /v1/tenants/{tenantId}/resources/{id}
```

### 9.2 DTOs

#### ResourceCreateDto
```csharp
public class ResourceCreateDto
{
    public Guid CategoryId { get; set; }        // Required
    public string Name { get; set; }            // Required, max 200 chars
    public string Description { get; set; }     // Optional, max 500 chars
}
```

#### ResourceUpdateDto
```csharp
public class ResourceUpdateDto
{
    public Guid CategoryId { get; set; }        // Optional
    public string Name { get; set; }            // Optional, max 200 chars
    public string Description { get; set; }     // Optional, max 500 chars
    public bool IsActive { get; set; }          // Optional
}
```

#### ResourceResponseDto
```csharp
public class ResourceResponseDto
{
    public Guid Id { get; set; }
    public string Code { get; set; }
    public Guid TenantId { get; set; }
    public Guid CategoryId { get; set; }
    public string Name { get; set; }
    public string Description { get; set; }
    public int Status { get; set; }
    public bool IsActive { get; set; }
    public bool IsDeleted { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime?   UpdatedAt { get; set; }
    
    // Dados da Category
    public string CategoryName { get; set; }
    public string CategoryDescription { get; set; }
    
    // Estatísticas (opcional)
    public int PermissionsCount { get; set; }
    public DateTime?   LastUsedAt { get; set; }
}
```

---

## 10. Validações

### 10.1 Validações de criação
- `Name`: Obrigatório, máximo 200 caracteres, único por Tenant
- `CategoryId`: Obrigatório, deve existir e pertencer ao Tenant
- `Description`: Opcional, máximo 500 caracteres
- Validar caracteres especiais em `Name`

### 10.2 Validações de atualização
- Não permitir alterar `Code` ou `TenantId`
- `Name`: Se alterado, deve manter unicidade por Tenant
- `CategoryId`: Deve existir e pertencer ao Tenant
- Validar se alterações não quebram dependências críticas

### 10.3 Validações de remoção
- Não permitir remover se há Permissions ativas dependentes
- Verificar integridade referencial antes da exclusão
- Considerar processo de aprovação para resources críticos

---

## 11. Considerações de Performance

### 11.1 Indexação
**Índices obrigatórios:**
- `(TenantId, Name) UNIQUE` - Unicidade e busca por nome
- `(TenantId, CategoryId, IsActive, IsDeleted)` - Filtros comuns
- `(Code) UNIQUE` - Busca rápida por código
- `(TenantId, IsActive, IsDeleted)` - Consultas principais

### 11.2 Caching
- Cachear Resources ativos por Tenant
- Invalidar cache ao criar/atualizar/remover Resources
- TTL do cache:   15 minutos
- Considerar cache distribuído para alta disponibilidade

### 11.3 Otimização de consultas
- Sempre aplicar filtro `IsDeleted = false` nas consultas
- Usar paginação em listagens
- Evitar joins desnecessários
- Considerar denormalização para consultas frequentes

---

## 12. Cenários de Uso

### 12.1 Setup inicial de Tenant
1. Administrador do Tenant cria Categories básicas
2. Administrador cria Resources fundamentais (APIs principais, dashboards)
3. Resources são organizados por categorias lógicas
4. Resources ficam disponíveis para criação de Permissions

### 12.2 Expansão de funcionalidades
1. Tenant adiciona nova funcionalidade ao sistema
2. Cria Category específica se necessário
3. Cria Resources correspondentes às novas APIs/funcionalidades
4. Configura Permissions apropriadas para controle de acesso

### 12.3 Reorganização de recursos
1. Administrador revisa estrutura de Categories
2. Move Resources para Categories mais apropriadas
3. Consolida Resources similares ou remove obsoletos
4. Atualiza documentação e comunicação para usuários

### 12.4 Integração com sistema de autorização
1. Sistema de autorização consulta Resources ativos
2. Valida Permissions baseado em Resource + Action
3. Permite ou nega acesso baseado nas regras configuradas
4. Registra uso do Resource para auditoria

---

## 13. Testes e Validação

### 13.1 Casos de teste obrigatórios
**Criação:**
- Criar Resource válido
- Rejeitar criação com Name duplicado no Tenant
- Rejeitar criação com CategoryId inválida
- Validar geração automática de Code no padrão RESO-YYMMDD-HASH

**Atualização:**
- Atualizar campos permitidos
- Rejeitar alteração de Code
- Rejeitar alteração de TenantId
- Verificar unicidade de Name após alteração

**Ativação/Desativação:**
- Ativar Resource inativo
- Rejeitar ativação de Resource já ativo (validação explícita)
- Desativar Resource ativo
- Rejeitar desativação de Resource já inativo (validação explícita)
- Verificar validações de estado corretas

**Remoção:**
- Remover Resource sem dependências
- Rejeitar remoção com dependências ativas
- Validar soft delete

**Validações:**
- `Name`: Obrigatório, máximo 200 caracteres, único por Tenant
- `CategoryId`: Obrigatório, deve existir e pertencer ao Tenant
- `Description`: Opcional, máximo 500 caracteres
- Validar caracteres especiais em `Name`

---

### 13.3 Testes de integridade
- Verificar consistência de foreign keys
- Validar cascata de operações
- Testar constraints de unicidade
- Verificar consistência com Categories

### 13.4 Testes de performance
- Consultas com grandes volumes de dados
- Performance de filtros e ordenação
- Eficiência do cache
- Tempo de resposta das APIs

---

## 14. Filosofia de Validação: Explícita vs. Idempotente

### 14.1 Abordagem adotada: Validação Explícita (Não-Idempotente)
O sistema VianaID adota **validação explícita de estado** nas operações de ativação/desativação de todas as entidades, incluindo Resources.

**Comportamento:**
- Operações de ativação **requerem** que a entidade esteja inativa
- Operações de desativação **requerem** que a entidade esteja ativa
- Tentativas de ativar entidade já ativa ou desativar entidade já inativa retornam **erro 400 (Bad Request)**
- A operação **não é idempotente** - o estado atual é validado explicitamente

**Exemplo de validação:**
```csharp
RuleFor(x => x.IsActive)
    .Equal(false)
    .WithMessage("Resource já está ativo");
```

### 14.2 Vantagens da validação explícita

**Performance:**
- ✅ Evita chamadas desnecessárias ao banco de dados quando já está no estado desejado
- ✅ "Early return" sem validar dependências desnecessariamente
- ✅ Reduz carga no banco de dados e infraestrutura
- ✅ Melhora tempo de resposta ao rejeitar operações inválidas imediatamente

**Qualidade e Confiabilidade:**
- ✅ Detecta bugs no cliente que fazem chamadas duplicadas
- ✅ Fornece feedback explícito sobre tentativas de operação inválidas
- ✅ Facilita debugging ao identificar fluxos incorretos
- ✅ Mais previsível para desenvolvedores - estado atual importa

**Segurança e Auditoria:**
- ✅ Evita logs de auditoria desnecessários para operações sem efeito
- ✅ Clareza sobre o que realmente aconteceu no sistema
- ✅ Facilita rastreamento de operações significativas

### 14.3 Implementação nas operações

**Ativação:**
```
1. Validar que Resource existe e pertence ao Tenant
2. Validar que Resource não está deletado
3. ✅ VALIDAR QUE IsActive = false (retorna 400 se já ativo)
4. Validar dependências (Category ativa, etc.)
5. Atualizar IsActive = true
6. Registrar auditoria
```

**Desativação:**
```
1. Validar que Resource existe e pertence ao Tenant
2. ✅ VALIDAR QUE IsActive = true (retorna 400 se já inativo)
3. Validar dependências (Permissions ativas, etc.)
4. Atualizar IsActive = false
5. Registrar auditoria
```

### 14.4 Comparação com abordagem idempotente

**Idempotente (NÃO utilizada):**
```
❌ Ativar entidade já ativa retorna 200 OK (sem alteração)
❌ Desativar entidade já inativa retorna 200 OK (sem alteração)
❌ Sempre consulta banco e valida dependências, mesmo sem necessidade
❌ Pode ocultar bugs do cliente
```

**Explícita (UTILIZADA):**
```
✅ Ativar entidade já ativa retorna 400 Bad Request
✅ Desativar entidade já inativa retorna 400 Bad Request
✅ Early return ao detectar estado incorreto
✅ Expõe bugs do cliente explicitamente
```

### 14.5 Aplicação consistente em todo o sistema
Esta filosofia de validação explícita é aplicada **consistentemente** em todos os módulos:
- ✅ Tenants (TENT-*)
- ✅ Categories (CATE-*)
- ✅ Applications (APPL-*)
- ✅ Resources (RESO-*)
- ✅ Actions (ACTN-*)
- ✅ Permissions (PERM-*)
- ✅ ApplicationRoles (ROLE-*)
- ✅ UserAccounts (USER-*)
- ✅ ServiceAccounts (SVAC-*)
- ✅ Subscriptions (SUBS-*)

**Consistência é fundamental para:**
- Experiência previsível para desenvolvedores
- Facilita compreensão e manutenção do código
- Reduz surpresas e comportamentos inesperados
- Melhora testabilidade e confiabilidade

---

## 15. Métricas e Monitoramento

### 15.1 Métricas operacionais
- **Resources por Tenant:** Distribuição de recursos por cliente
- **Resources por Category:** Organização e uso das categorias
- **Taxa de utilização:** Percentual de resources utilizados em permissions
- **Resources órfãos:** Resources sem permissions associadas

### 15.2 Métricas de segurança
- **Tentativas de acesso cross-tenant:** Violações de isolamento
- **Operações de alta criticidade:** Criação, alteração, remoção
- **Resources críticos modificados:** Alterações em resources importantes
- **Padrões de acesso anômalos:** Detecção de comportamento suspeito

### 15.3 Métricas de performance
- **Tempo de consulta:** Performance das queries principais
- **Hit ratio de cache:** Eficiência do caching
- **Volume de consultas:** Carga no sistema
- **Crescimento de resources:** Tendências de uso

### 15.4 Métricas de governança
- **Resources sem descrição:** Qualidade da documentação
- **Resources inativos há muito tempo:** Candidatos à remoção
- **Distribuição por categoria:** Organização dos recursos
- **Frequência de mudanças:** Estabilidade dos resources

---

## 16. Integração com Outros Módulos

### 16.1 Categories
- Resource depende diretamente de Category
- Alterações em Category podem afetar Resources
- Desativação de Category deve impactar Resources associados
- Validar consistência entre Resource e Category

### 16.2 Permissions
- Resources são utilizados na construção de Permissions
- Não permitir exclusão de Resources com Permissions ativas
- Consultar dependências antes de operações destrutivas
- Notificar sobre impactos em Permissions existentes

### 16.3 Tenants
- Resources estão isolados por Tenant (RLS)
- Desativação de Tenant deve afetar todos seus Resources
- Validar contexto de Tenant em todas as operações
- Manter consistência multi-tenant

### 16.4 Applications
- Resources podem estar relacionados a Applications específicas
- Considerar vinculação opcional Resource-Application
- Validar compatibilidade entre Resource e Application

### 16.5 AuditLogs
- Todas as operações críticas devem gerar logs de auditoria
- Incluir contexto completo para investigação
- Rastrear mudanças em resources críticos

---

## 17. Casos de Uso Avançados

### 17.1 Resources hierárquicos
**Conceito:**
- Permitir que Resources tenham relacionamentos pai-filho
- Facilitar organização de APIs complexas
- Herança de permissões de recursos pais

**Implementação futura:**
- Campo opcional `ParentResourceId`
- Validações de hierarquia
- Consultas recursivas para permissões

### 17.2 Resources temporários
**Conceito:**
- Resources com data de expiração automática
- Útil para funcionalidades temporárias ou testes

**Implementação futura:**
- Campos `ValidFrom` e `ValidUntil`
- Job de limpeza automática
- Notificações de expiração

### 17.3 Resources dinâmicos
**Conceito:**
- Resources criados automaticamente basado em configuração
- Útil para APIs auto-descobertas

**Implementação futura:**
- Integração com discovery de APIs
- Sincronização automática
- Mapeamento de metadados

---

## 18. Conclusão
O módulo **Resources** é um componente fundamental para o sistema de autorização granular do IAM VianaID. 

As regras aqui definidas garantem:
- **Flexibilidade:** Resources customizáveis por Tenant e contexto
- **Segurança:** Isolamento multi-tenant e controle de acesso rigoroso
- **Integridade:** Validação de dependências e consistência de dados
- **Auditoria:** Rastreamento completo de operações críticas
- **Performance:** Estrutura otimizada para consultas frequentes
- **Governança:** Organização clara e documentação adequada
- **Escalabilidade:** Arquitetura preparada para grandes volumes
- **Manutenibilidade:** Estrutura clara para evolução futura

Com esta estrutura detalhada, o sistema garante controle fino sobre recursos protegidos, mantendo simplicidade operacional e segurança empresarial robusta.  O módulo serve como base sólida para construção de um sistema de permissões flexível e escalável.   🚀