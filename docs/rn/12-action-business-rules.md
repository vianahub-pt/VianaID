# Documento de Regras de Negócio — Actions

## 1. Introdução
Este documento descreve de forma detalhada as regras de negócio do módulo **Actions** no sistema IAM (VianaID).

Uma **Action** representa uma operação/verbo específico que pode ser executado sobre um recurso (Resource) no contexto de um Tenant.   As Actions são componentes fundamentais do sistema de permissões, definindo o que pode ser feito com cada recurso.

---

## 2. Objetivos do Módulo de Actions
- Definir operações específicas disponíveis sobre recursos da plataforma
- Servir como componente base para construção de permissões granulares
- Permitir mapeamento direto com verbos HTTP e operações de API
- Garantir consistência e reutilização de ações entre diferentes recursos
- Facilitar auditoria e controle de acesso baseado em operações específicas
- Suportar isolamento multi-tenant de ações customizadas

---

## 3. Estrutura Geral da Action
Uma **Action** contém:
- `Id`
- `TenantId` (FK para Tenants)
- `CategoryId` (FK para Categories)
- `Code` (código técnico gerado automaticamente pelo sistema)
- `Name` (nome da ação)
- `Description` (descrição detalhada)
- `HttpVerb` (verbo HTTP associado - opcional)
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
- **ACTN**: prefixo fixo que identifica o recurso Action (conforme 00-code-generation-business-rules.md)
- **YYMMDD**: data UTC de geração do código
- **HASH**: sequência alfanumérica aleatória de 4 caracteres

**Exemplo válido:**
```
ACTN251221XTG2
```

- A unicidade do `Code` é garantida pelo sistema
- Qualquer tentativa de envio ou alteração manual do campo `Code` deve ser ignorada ou rejeitada pela API

### 3.2 Escopo Multi-tenant
- Toda Action pertence exatamente a um Tenant específico
- Actions são isoladas por Tenant através de Row-Level Security (RLS)
- Um Tenant não pode acessar Actions de outros Tenants
- Actions podem ser reutilizadas em diferentes Resources do mesmo Tenant
- Consultas e operações devem sempre respeitar o contexto do Tenant autenticado

### 3.3 Categorização
- Toda Action deve estar associada a uma Category válida do mesmo Tenant
- A Category permite organização lógica e facilita governança
- Actions da mesma categoria compartilham características operacionais similares

### 3.4 Mapeamento HTTP
- O campo `HttpVerb` é opcional e permite associar a Action a um verbo HTTP específico
- Verbos suportados: `GET`, `POST`, `PUT`, `PATCH`, `DELETE`, `HEAD`, `OPTIONS`
- Uma Action pode não ter verbo HTTP associado (operações conceituais ou compostas)
- Múltiplas Actions podem compartilhar o mesmo verbo HTTP (diferentes contextos/recursos)

---

## 4. Regras de Negócio por Operação

### 4.1 Criar Action (POST /v1/tenants/{tenantId}/actions)
**Contexto:** Criação de uma nova ação no contexto de um Tenant específico.

**Regras:**
- A Action é criada com `IsActive = true` e `IsDeleted = false`
- O campo `Code` é gerado automaticamente
- O campo `Name` é obrigatório e deve ser único dentro do Tenant
- O campo `TenantId` deve corresponder ao Tenant do contexto da requisição
- O campo `CategoryId` deve referenciar uma Category válida e ativa do mesmo Tenant
- O campo `HttpVerb` é opcional e deve ser um verbo HTTP válido se informado
- O campo `Description` é opcional mas recomendado para documentação
- O `CreatedBy` deve ser preenchido com o ID do usuário autenticado
- O `Status` deve ser inicializado com valor padrão (1 - Ativo)

**Validações:**
- O Tenant deve existir, estar ativo e não deletado
- A Category deve existir, estar ativa, não deletada e pertencer ao mesmo Tenant
- O `Name` deve ser único dentro do escopo do Tenant (constraint de unicidade por Tenant)
- Se `HttpVerb` for informado, deve ser um valor válido da lista de verbos HTTP suportados
- O usuário deve ter permissão para criar Actions no Tenant

**Pós-criação:**
- Registrar evento de auditoria da criação
- A Action fica disponível para uso em Permissions imediatamente

---

### 4.2 Cadastro Massivo de Ações via Upload de CSV

**POST** `/actions/bulk-upload`

Permite o cadastro massivo de ações através do upload de um arquivo CSV.
O sistema carrega todo o conteúdo do arquivo em memória e realiza o processamento de forma síncrona.

A rota aceita **exclusivamente arquivos no formato CSV**.

#### Estrutura do Arquivo CSV

| Coluna       | Tipo   | Obrigatório | Descrição |
|-------------|--------|-------------|-----------|
| categoryId  | GUID   | Sim         | Identificador da categoria |
| name        | string | Sim         | Nome da ação |
| description | string | Sim         | Descrição da ação |
| httpVerb    | string | Não         | Verbo HTTP (GET, POST, PUT, DELETE, etc.) |

#### Regras
- O arquivo é carregado integralmente em memória.
- O sistema tenta processar todas as linhas.
- Não é permitido cadastro parcial.
- Apenas arquivos `.csv` são aceitos.

#### Respostas
- **200 OK**: todas as ações cadastradas com sucesso (sem body).
- **400 Bad Request**: retorna a lista de ações não cadastradas com o motivo da falha.

### 4.3 Consultar Actions (GET /v1/tenants/{tenantId}/actions)
**Contexto:** Listar todas as Actions de um Tenant específico.

**Regras:**
- Devem ser retornadas apenas Actions não deletadas (`IsDeleted = false`)
- Aplicar isolamento por Tenant através de RLS ou filtro explícito
- Aplicar filtros opcionais por:  
  - `CategoryId` (Actions de uma categoria específica)
  - `IsActive` (ativas ou inativas)
  - `HttpVerb` (Actions de um verbo específico)
  - `Name` (busca parcial case-insensitive)
- Ordenação padrão:  `CategoryId ASC, Name ASC`
- Suportar paginação obrigatória para melhor performance

**Projeção de dados:**
- Incluir todos os campos da Action
- Incluir dados básicos da Category associada (Name, Description)
- Incluir contador de quantas Permissions utilizam esta Action (opcional)

**Permissões:**
- Apenas usuários com permissão de leitura de Actions no Tenant podem consultar
- Aplicar RLS automaticamente baseado no TenantId do contexto

---

### 4.4 Consultar Action por ID (GET /v1/tenants/{tenantId}/actions/{id})
**Contexto:** Obter detalhes de uma Action específica.

**Regras:**
- Retornar apenas se a Action pertencer ao Tenant especificado
- Não retornar Actions deletadas
- Incluir informações detalhadas da Category associada
- Incluir lista de Resources que utilizam esta Action em suas Permissions (opcional)

**Validações:**
- A Action deve existir e pertencer ao Tenant do contexto
- A Action não pode estar deletada
- Aplicar RLS baseado no TenantId

**Permissões:**
- Mesmo controle de acesso da listagem geral

---

### 4.5 Consultar Action por Code (GET /v1/tenants/{tenantId}/actions/code/{code})
**Contexto:** Buscar Action pelo código único gerado automaticamente. 

**Regras:**
- Buscar Action pelo campo `Code` único
- Retornar 404 se não encontrada, deletada ou não pertencer ao Tenant
- Mesmas regras de projeção da consulta por ID

**Validações:**
- O código deve existir e pertencer ao Tenant especificado
- Aplicar mesmo controle de acesso das outras consultas

---

### 4.6 Atualizar Action (PUT /v1/tenants/{tenantId}/actions/{id})
**Contexto:** Modificar uma Action existente.

**Regras:**
- O campo `Code` **não pode ser alterado**
- O campo `TenantId` **não pode ser alterado**
- Campos que podem ser alterados: 
  - `Name` (deve manter unicidade dentro do Tenant)
  - `Description`
  - `HttpVerb` (pode ser definido, alterado ou removido)
  - `CategoryId` (deve ser Category válida do mesmo Tenant)
  - `IsActive`
- Atualizar `UpdatedBy` com ID do usuário autenticado
- Atualizar `UpdatedAt` com data/hora atual

**Validações:**
- A Action deve existir, pertencer ao Tenant e não estar deletada
- Se `Name` for alterado, deve manter unicidade dentro do Tenant
- Se `CategoryId` for alterado, a nova Category deve existir, estar ativa e pertencer ao mesmo Tenant
- Se `HttpVerb` for alterado, deve ser um verbo HTTP válido ou NULL
- Não permitir alteração se a Action estiver sendo utilizada em Permissions ativas (regra configurável)

**Impacto em dependências:**
- Alterações na Action podem afetar Permissions que a utilizam
- Se `IsActive` for alterado para `false`, verificar impacto em Permissions ativas
- Considerar notificação ou validação prévia se há dependências críticas

**Auditoria:**
- Registrar alteração em `AuditLogs` com valores antigos e novos
- Incluir contexto do usuário que fez a alteração

---

### 4.7 Ativar Action (PATCH /v1/tenants/{tenantId}/actions/{id}/activate)
**Contexto:** Reativar uma Action previamente desativada.

**Regras:**
- Só é permitido ativar uma Action existente, não deletada e pertencente ao Tenant
- **A Action deve estar inativa** (`IsActive = false`) para ser ativada
- Atualizar `IsActive = true`
- Atualizar `UpdatedBy` e `UpdatedAt`

**Validações:**
- A Action deve existir e pertencer ao Tenant
- A Action não pode estar deletada
- **A Action não pode estar já ativa** - retorna erro 400 se tentar ativar uma Action que já está ativa
- A operação **não é idempotente** - valida o estado atual e retorna erro se já estiver no estado desejado

**Motivo da validação explícita:**
- Evita chamadas desnecessárias ao banco de dados quando a Action já está ativa
- Detecta bugs no cliente que fazem chamadas duplicadas
- Melhora a performance ao fazer "early return" sem validar dependências desnecessariamente
- Fornece feedback explícito sobre tentativas de operação inválidas

**Auditoria:**
- Registrar ativação em `AuditLogs`
- Incluir contexto do usuário que ativou

---

### 4.8 Desativar Action (PATCH /v1/tenants/{tenantId}/actions/{id}/deactivate)
**Contexto:** Desativar uma Action temporariamente.

**Regras:**
- Só é permitido desativar uma Action ativa, não deletada e pertencente ao Tenant
- **A Action deve estar ativa** (`IsActive = true`) para ser desativada
- Atualizar `IsActive = false`
- Atualizar `UpdatedBy` e `UpdatedAt`

**Validações:**
- A Action deve existir, pertencer ao Tenant e estar ativa
- **A Action não pode estar já inativa** - retorna erro 400 se tentar desativar uma Action que já está inativa
- Verificar se existem Permissions ativas que utilizam esta Action
- Opcionalmente, impedir desativação se há dependências críticas
- A operação **não é idempotente** - valida o estado atual e retorna erro se já estiver no estado desejado

**Motivo da validação explícita:**
- Evita chamadas desnecessárias ao banco de dados e verificação de dependências
- Detecta bugs no cliente que fazem chamadas duplicadas
- Melhora a performance ao fazer "early return" sem processar operação desnecessária
- Fornece feedback explícito sobre tentativas de operação inválidas

**Impacto:**
- Actions desativadas não devem ser utilizadas em novas Permissions
- Permissions existentes podem ser afetadas (dependendo da implementação)

**Auditoria:**
- Registrar desativação em `AuditLogs` com motivo (se fornecido)

---

### 4.9 Remover Action (DELETE /v1/tenants/{tenantId}/actions/{id}) — Exclusão lógica
**Contexto:** Excluir logicamente uma Action.  

**Regras:**
- Actions não podem ser removidas se estiverem sendo utilizadas em Permissions ativas
- Aplicar soft delete:  
  - `IsDeleted = true`
  - `IsActive = false`
  - `UpdatedBy` = ID do usuário autenticado
  - `UpdatedAt` = data/hora atual

**Validações:**
- A Action deve existir e pertencer ao Tenant
- A Action não pode estar já deletada
- Verificar se não há Permissions ativas que utilizam esta Action
- Se houver dependências, retornar erro específico com detalhes

**Auditoria:**
- Registrar exclusão em `AuditLogs` com motivo (se fornecido)
- Incluir informações sobre dependências verificadas

---

## 5. Regras de Integridade e Dependência

### 5.1 Dependências obrigatórias
- Toda Action deve referenciar um `TenantId` válido e ativo
- Toda Action deve referenciar uma `CategoryId` válida, ativa e do mesmo Tenant
- A combinação `TenantId` + `Name` deve ser única (constraint de unicidade)

### 5.2 Integridade referencial
- Actions são referenciadas por Permissions através de `ActionId`
- Não permitir exclusão de Actions que estejam sendo utilizadas
- Implementar verificação de dependências antes de operações destrutivas

### 5.3 Cascata de operações
**Desativação de Category:**
- Considerar desativação automática de todas as Actions da Category
- Notificar administradores sobre impacto

**Desativação de Tenant:**
- Desativar automaticamente todas as Actions do Tenant
- Não permitir criação de novas Actions

### 5.4 Consistência de dados
- O campo `HttpVerb` deve sempre conter valores válidos ou NULL
- Actions ativas devem sempre ter Category ativa associada
- Manter consistência temporal entre criação/atualização de registros relacionados

---

## 6. Regras de Segurança

### 6.1 Isolamento multi-tenant
- Implementar Row-Level Security (RLS) baseado em TenantId
- Todas as consultas devem automaticamente filtrar pelo Tenant do contexto
- Validar TenantId em todas as operações para prevenir vazamento de dados

### 6.2 Controle de acesso
**Permissões necessárias:**
- **Criar Action:** Permissão de escrita em Actions no Tenant
- **Consultar Actions:** Permissão de leitura em Actions no Tenant
- **Atualizar Action:** Permissão de escrita em Actions no Tenant
- **Ativar/Desativar:** Permissão de gerenciamento em Actions no Tenant
- **Remover Action:** Permissão de exclusão em Actions no Tenant

### 6.3 Auditoria de segurança
- Registrar todas as operações críticas (criação, alteração, remoção)
- Incluir contexto completo do usuário (IP, User Agent, etc.)
- Monitorar tentativas de acesso cross-tenant

### 6.4 Validação de entrada
- Sanitizar campos de texto para prevenir XSS
- Validar tamanhos máximos de campos
- Validar formatos de dados (HttpVerb, etc.)

---

## 7. Regras de Governança

### 7.1 Naming conventions
**Name:**
- Use PascalCase ou snake_case consistentemente
- Seja descritivo e específico
- Exemplos: `Create`, `Read`, `Update`, `Delete`, `List`, `Execute`, `Approve`

**HttpVerb:**
- Use apenas verbos HTTP padrão
- Mantenha consistência com operações REST

### 7.2 Categorização
- Actions devem ser agrupadas em Categories lógicas
- Evitar Actions órfãs ou mal categorizadas
- Revisar periodicamente a organização de Categories

### 7.3 Documentação
- Toda Action deve ter `Description` preenchida
- Documentar o propósito e contexto de uso
- Manter documentação atualizada com mudanças

### 7.4 Versionamento
- Actions são estáveis após criação
- Mudanças breaking devem ser evitadas
- Considerar criação de nova Action em vez de alteração drástica

---

## 8. Exemplos de Actions Padrão

### 8.1 Actions CRUD Básicas
```json
[
  {
    "name": "Create",
    "description": "Criar novos registros",
    "httpVerb": "POST",
    "category": "Data Management"
  },
  {
    "name": "Read",
    "description": "Ler registros existentes",
    "httpVerb": "GET",
    "category": "Data Management"
  },
  {
    "name": "Update",
    "description": "Atualizar registros existentes",
    "httpVerb": "PUT",
    "category": "Data Management"
  },
  {
    "name": "Delete",
    "description": "Remover registros",
    "httpVerb": "DELETE",
    "category": "Data Management"
  }
]
```

### 8.2 Actions de Administração
```json
[
  {
    "name": "Activate",
    "description": "Ativar entidades",
    "httpVerb": "PATCH",
    "category": "Administration"
  },
  {
    "name": "Deactivate",
    "description": "Desativar entidades",
    "httpVerb": "PATCH",
    "category": "Administration"
  },
  {
    "name": "Approve",
    "description": "Aprovar solicitações",
    "httpVerb": "PATCH",
    "category": "Workflow"
  }
]
```

### 8.3 Actions de Relatórios
```json
[
  {
    "name": "Export",
    "description": "Exportar dados para arquivo",
    "httpVerb": "POST",
    "category": "Reporting"
  },
  {
    "name": "Generate",
    "description": "Gerar relatórios",
    "httpVerb": "POST",
    "category": "Reporting"
  }
]
```

---

## 9. Estrutura da API

### 9.1 Endpoints
```
GET    /v1/tenants/{tenantId}/actions
GET    /v1/tenants/{tenantId}/actions/{id}
GET    /v1/tenants/{tenantId}/actions/code/{code}
POST   /v1/tenants/{tenantId}/actions
PUT    /v1/tenants/{tenantId}/actions/{id}
PATCH  /v1/tenants/{tenantId}/actions/{id}/activate
PATCH  /v1/tenants/{tenantId}/actions/{id}/deactivate
DELETE /v1/tenants/{tenantId}/actions/{id}
```

### 9.2 DTOs

#### ActionCreateDto
```csharp
public class ActionCreateDto
{
    public Guid CategoryId { get; set; }        // Required
    public string Name { get; set; }            // Required, max 200 chars
    public string Description { get; set; }     // Optional, max 500 chars
    public string HttpVerb { get; set; }        // Optional, valid HTTP verb
}
```

#### ActionUpdateDto
```csharp
public class ActionUpdateDto
{
    public Guid CategoryId { get; set; }        // Optional
    public string Name { get; set; }            // Optional, max 200 chars
    public string Description { get; set; }     // Optional, max 500 chars
    public string HttpVerb { get; set; }        // Optional, valid HTTP verb
    public bool IsActive { get; set; }          // Optional
}
```

#### ActionResponseDto
```csharp
public class ActionResponseDto
{
    public Guid Id { get; set; }
    public string Code { get; set; }
    public Guid TenantId { get; set; }
    public Guid CategoryId { get; set; }
    public string Name { get; set; }
    public string Description { get; set; }
    public string HttpVerb { get; set; }
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
}
```

---

## 10. Validações

### 10.1 Validações de criação
- `Name`: Obrigatório, máximo 200 caracteres, único por Tenant
- `CategoryId`: Obrigatório, deve existir e pertencer ao Tenant
- `Description`: Opcional, máximo 500 caracteres
- `HttpVerb`: Opcional, deve ser verbo HTTP válido se informado

### 10.2 Validações de atualização
- Não permitir alterar `Code` ou `TenantId`
- `Name`: Se alterado, deve manter unicidade por Tenant
- `CategoryId`: Deve existir e pertencer ao Tenant
- `HttpVerb`: Deve ser verbo HTTP válido ou NULL

### 10.3 Validações de remoção
- Não permitir remover se há Permissions ativas dependentes
- Verificar integridade referencial antes da exclusão

---

## 11. Considerações de Performance

### 11.1 Indexação
**Índices obrigatórios:**
- `(TenantId, Name) UNIQUE` - Unicidade e busca por nome
- `(TenantId, CategoryId, IsActive, IsDeleted)` - Filtros comuns
- `(TenantId, HttpVerb, IsActive, IsDeleted)` - Busca por verbo HTTP
- `(Code) UNIQUE` - Busca rápida por código

### 11.2 Caching
- Cachear Actions ativas por Tenant
- Invalidar cache ao criar/atualizar/remover Actions
- TTL do cache:  15 minutos

### 11.3 Otimização de consultas
- Sempre aplicar filtro `IsDeleted = false` nas consultas
- Usar paginação em listagens
- Evitar joins desnecessários

---

## 12. Cenários de Uso

### 12.1 Criação de sistema de permissões básico
1. Administrador cria Categories para organização
2. Administrador cria Actions padrão (Create, Read, Update, Delete)
3. Actions são associadas a Resources através de Permissions
4. Users recebem Roles que contêm as Permissions necessárias

### 12.2 Customização por Tenant
1. Tenant cria Categories específicas de seu negócio
2. Tenant cria Actions customizadas para operações específicas
3. Actions customizadas são utilizadas em Permissions específicas
4. Sistema mantém isolamento entre Tenants

### 12.3 Mapeamento com APIs REST
1. Actions são criadas com HttpVerb correspondente
2. Sistema de autorização valida permissões baseado na Action
3. Middleware de segurança intercepta requests e valida permissions
4. Logs de auditoria registram uso de cada Action

---

## 13. Testes e Validação

### 13.1 Casos de teste obrigatórios
**Criação:**
- Criar Action válida
- Rejeitar criação com Name duplicado no Tenant
- Rejeitar criação com CategoryId inválida
- Rejeitar criação com HttpVerb inválido
- Validar geração automática de Code no padrão ACTN-YYMMDD-HASH

**Atualização:**
- Atualizar campos permitidos
- Rejeitar alteração de Code
- Rejeitar alteração de TenantId
- Verificar unicidade de Name após alteração

**Ativação/Desativação:**
- Ativar Action inativa
- Desativar Action ativa
- Verificar idempotência das operações

**Remoção:**
- Remover Action sem dependências
- Rejeitar remoção com dependências ativas

### 13.2 Testes de segurança
- Verificar isolamento multi-tenant
- Validar controle de acesso por permissões
- Testar tentativas de acesso cross-tenant

### 13.3 Testes de integridade
- Verificar consistência de foreign keys
- Validar cascata de operações
- Testar constraints de unicidade

---

## 14. Métricas e Monitoramento

### 14.1 Métricas operacionais
- **Actions por Tenant:** Distribuição de actions por cliente
- **Actions por Category:** Organização e uso das categorias
- **Actions por HttpVerb:** Distribuição de operações por tipo
- **Taxa de utilização:** Percentual de actions utilizadas em permissions

### 14.2 Métricas de segurança
- **Tentativas de acesso cross-tenant:** Violações de isolamento
- **Operações de alta criticidade:** Criação, alteração, remoção
- **Actions órfãs:** Actions sem permissions associadas

### 14.3 Métricas de performance
- **Tempo de consulta:** Performance das queries principais
- **Hit ratio de cache:** Eficiência do caching
- **Volume de consultas:** Carga no sistema

---

## 15. Integração com Outros Módulos

### 15.1 Categories
- Action depende diretamente de Category
- Alterações em Category podem afetar Actions
- Desativação de Category deve impactar Actions associadas

### 15.2 Permissions
- Actions são utilizadas na construção de Permissions
- Não permitir exclusão de Actions com Permissions ativas
- Consultar dependências antes de operações destrutivas

### 15.3 Tenants
- Actions estão isoladas por Tenant (RLS)
- Desativação de Tenant deve afetar todas suas Actions
- Validar contexto de Tenant em todas as operações

### 15.4 AuditLogs
- Todas as operações críticas devem gerar logs de auditoria
- Incluir contexto completo para investigação

---

## 16. Conclusão
O módulo **Actions** é um componente fundamental para o sistema de autorização granular do IAM VianaID. 

As regras aqui definidas garantem:
- **Flexibilidade:** Actions customizáveis por Tenant e contexto
- **Segurança:** Isolamento multi-tenant e controle de acesso rigoroso
- **Integridade:** Validação de dependências e consistência de dados
- **Auditoria:** Rastreamento completo de operações críticas
- **Performance:** Estrutura otimizada para consultas frequentes
- **Governança:** Organização clara e documentação adequada
- **Escalabilidade:** Arquitetura preparada para grandes volumes

Com esta estrutura detalhada, o sistema garante controle fino de permissões, mantendo simplicidade operacional e segurança empresarial robusta.  🚀
