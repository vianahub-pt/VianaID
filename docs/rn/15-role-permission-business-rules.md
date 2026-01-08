# Documento de Regras de Negócio — RolePermissions

## 1. Introdução
Este documento descreve de forma detalhada as regras de negócio do módulo **RolePermissions** no sistema IAM (VianaID).

Um **RolePermission** representa a ligação entre um ApplicationRole e uma Permission no contexto de um Tenant, estabelecendo quais permissões específicas são atribuídas a cada papel/função dentro de uma aplicação.  Os RolePermissions são componentes fundamentais para a operação do sistema RBAC (Role-Based Access Control).

---

## 2. Objetivos do Módulo de RolePermissions
- Estabelecer relações entre ApplicationRoles e Permissions dentro do contexto de um Tenant
- Permitir agrupamento lógico de permissões em papéis funcionais
- Facilitar gestão de autorizações através de atribuição de papéis aos usuários
- Garantir isolamento multi-tenant das associações role-permission
- Suportar auditoria completa de alterações em privilégios
- Integrar com sistema de usuários para controle de acesso baseado em papéis
- Permitir revogação granular de permissões por papel

---

## 3. Estrutura Geral do RolePermission
Um **RolePermission** contém:
- `Id`
- `TenantId` (FK para Tenants)
- `ApplicationRoleId` (FK para ApplicationRoles)
- `PermissionId` (FK para Permissions)
- Estado (`Status`, `IsActive`, `IsDeleted`)
- Auditoria (`CreatedBy`, `CreatedAt`, `UpdatedBy`, `UpdatedAt`)

### 3.1 Escopo Multi-tenant
- Todo RolePermission pertence exatamente a um Tenant específico
- RolePermissions são isolados por Tenant através de Row-Level Security (RLS)
- Um Tenant não pode acessar RolePermissions de outros Tenants
- Consultas e operações devem sempre respeitar o contexto do Tenant autenticado

### 3.2 Composição de RolePermission
- Todo RolePermission é formado pela combinação obrigatória de: 
  - **ApplicationRole**: O papel/função dentro de uma aplicação específica
  - **Permission**: A permissão específica sendo atribuída ao papel
- A combinação (TenantId, ApplicationRoleId, PermissionId) deve ser única
- Tanto o ApplicationRole quanto a Permission devem pertencer ao mesmo Tenant

### 3.3 Relacionamento com outros módulos
- ApplicationRole e Permission devem existir e pertencer ao mesmo Tenant
- ApplicationRole deve referenciar uma Application válida
- Permission deve referenciar Application, Resource e Action válidos
- Todas as entidades relacionadas devem estar ativas para permitir a associação

---

## 4. Regras de Negócio por Operação

### 4.1 Criar RolePermission (POST /v1/tenants/{tenantId}/applications/{applicationId}/roles/{roleId}/permissions)
**Contexto:** Atribuir uma nova Permission a um ApplicationRole específico. 

**Regras:**
- O RolePermission é criado com `IsActive = true` e `IsDeleted = false`
- O campo `TenantId` deve corresponder ao Tenant do contexto da requisição
- O `ApplicationRoleId` deve corresponder ao papel especificado na URL
- A `PermissionId` deve referenciar Permission válida, ativa e do mesmo Tenant
- A combinação (TenantId, ApplicationRoleId, PermissionId) deve ser única
- O `CreatedBy` deve ser preenchido com o ID do usuário autenticado
- O `Status` deve ser inicializado com valor padrão (1 - Ativo)

**Validações:**
- O Tenant deve existir, estar ativo e não deletado
- O ApplicationRole deve existir, estar ativo, não deletado e pertencer ao Tenant
- A Permission deve existir, estar ativa, não deletada e pertencer ao Tenant
- A Application referenciada pelo ApplicationRole deve estar ativa
- Não deve existir associação idêntica já criada
- O usuário deve ter permissão para gerenciar roles na Application

**Pós-criação:**
- Registrar evento de auditoria da atribuição
- Invalidar cache de permissões para usuários que possuem este ApplicationRole
- A Permission fica imediatamente disponível para usuários com este ApplicationRole

---

### 4.2 Consultar RolePermissions (GET /v1/tenants/{tenantId}/applications/{applicationId}/roles/{roleId}/permissions)
**Contexto:** Listar todas as Permissions atribuídas a um ApplicationRole específico.

**Regras:**
- Devem ser retornados apenas RolePermissions não deletados (`IsDeleted = false`)
- Aplicar isolamento por Tenant através de RLS ou filtro explícito
- Filtrar apenas RolePermissions do ApplicationRole especificado
- Aplicar filtros opcionais por: 
  - `IsActive` (ativos ou inativos)
  - `PermissionId` (permission específica)
  - Propriedades da Permission (Category, RiskLevel, etc.)
- Ordenação padrão: `Permission.CategoryId ASC, Permission.RiskLevel DESC, Permission.Name ASC`
- Suportar paginação obrigatória para melhor performance

**Projeção de dados:**
- Incluir todos os campos do RolePermission
- Incluir dados detalhados da Permission associada: 
  - Permission (Name, Description, RiskLevel)
  - Application (Name)
  - Resource (Name)
  - Action (Name, HttpVerb)
  - Category (Name)
- Incluir data de atribuição e usuário responsável

**Permissões:**
- Apenas usuários com permissão de leitura de ApplicationRoles podem consultar
- Aplicar RLS automaticamente baseado no TenantId do contexto

---

### 4.3 Consultar RolePermission por ID (GET /v1/tenants/{tenantId}/role-permissions/{id})
**Contexto:** Obter detalhes de um RolePermission específico. 

**Regras:**
- Retornar apenas se o RolePermission pertencer ao Tenant especificado
- Não retornar RolePermissions deletados
- Incluir informações detalhadas do ApplicationRole e Permission associados
- Incluir metadados de auditoria (criação, última modificação)

**Validações:**
- O RolePermission deve existir e pertencer ao Tenant do contexto
- O RolePermission não pode estar deletado
- Aplicar RLS baseado no TenantId

**Permissões:**
- Mesmo controle de acesso da listagem geral

---

### 4.4 Listar Permissions por Usuário (GET /v1/tenants/{tenantId}/users/{userId}/permissions)
**Contexto:** Obter todas as Permissions efetivas de um usuário através de seus ApplicationRoles.

**Regras:**
- Buscar todos os ApplicationRoles ativos atribuídos ao usuário
- Para cada ApplicationRole, buscar todas as Permissions ativas associadas
- Consolidar lista eliminando duplicatas
- Aplicar filtros por Application, Category ou RiskLevel
- Incluir informação de qual ApplicationRole concedeu cada Permission

**Validações:**
- O usuário deve existir e pertencer ao Tenant
- Aplicar RLS baseado no TenantId
- Considerar apenas entidades ativas (usuário, roles, permissions)

---

### 4.5 Ativar RolePermission (PATCH /v1/tenants/{tenantId}/role-permissions/{id}/activate)
**Contexto:** Reativar um RolePermission previamente desativado.

**Regras:**
- Só é permitido ativar um RolePermission existente, não deletado e pertencente ao Tenant
- **O RolePermission deve estar inativo** (`IsActive = false`) para ser ativado
- Validar se o ApplicationRole e Permission relacionados ainda estão ativos
- Atualizar `IsActive = true`
- Atualizar `UpdatedBy` e `UpdatedAt`

**Validações:**
- O RolePermission deve existir e pertencer ao Tenant
- O RolePermission não pode estar deletado
- **O RolePermission não pode estar já ativo** - retorna erro 400 se tentar ativar um RolePermission que já está ativo
- O ApplicationRole associado deve estar ativo
- A Permission associada deve estar ativa
- A operação **não é idempotente** - valida o estado atual e retorna erro se já estiver no estado desejado

**Motivo da validação explícita:**
- Evita chamadas desnecessárias ao banco de dados quando o RolePermission já está ativo
- Detecta bugs no cliente que fazem chamadas duplicadas
- Melhora a performance ao fazer "early return" sem validar dependências desnecessariamente
- Fornece feedback explícito sobre tentativas de operação inválidas

**Auditoria:**
- Registrar ativação em `AuditLogs`
- Incluir contexto do usuário que ativou
- Invalidar cache de permissions para usuários afetados

---

### 4.6 Desativar RolePermission (PATCH /v1/tenants/{tenantId}/role-permissions/{id}/deactivate)
**Contexto:** Desativar um RolePermission temporariamente.

**Regras:**
- Só é permitido desativar um RolePermission ativo, não deletado e pertencente ao Tenant
- **O RolePermission deve estar ativo** (`IsActive = true`) para ser desativado
- Atualizar `IsActive = false`
- Atualizar `UpdatedBy` e `UpdatedAt`

**Validações:**
- O RolePermission deve existir, pertencer ao Tenant e estar ativo
- **O RolePermission não pode estar já inativo** - retorna erro 400 se tentar desativar um RolePermission que já está inativo
- A operação **não é idempotente** - valida o estado atual e retorna erro se já estiver no estado desejado

**Motivo da validação explícita:**
- Evita chamadas desnecessárias ao banco de dados
- Detecta bugs no cliente que fazem chamadas duplicadas
- Melhora a performance ao fazer "early return" sem processar operação desnecessária
- Fornece feedback explícito sobre tentativas de operação inválidas

**Impacto:**
- RolePermissions desativados removem temporariamente a Permission do ApplicationRole
- Usuários com este ApplicationRole perdem acesso à Permission desativada
- Considerar notificação de usuários afetados

**Auditoria:**
- Registrar desativação em `AuditLogs` com motivo (se fornecido)
- Invalidar cache de permissions para usuários afetados

---

### 4.7 Remover RolePermission (DELETE /v1/tenants/{tenantId}/role-permissions/{id}) — Exclusão lógica
**Contexto:** Excluir logicamente um RolePermission. 

**Regras:**
- Aplicar soft delete: 
  - `IsDeleted = true`
  - `IsActive = false`
  - `UpdatedBy` = ID do usuário autenticado
  - `UpdatedAt` = data/hora atual

**Validações:**
- O RolePermission deve existir e pertencer ao Tenant
- O RolePermission não pode estar já deletado
- Verificar se a remoção não viola políticas de segurança (ex: remover última Permission administrativa)

**Impacto:**
- Remove permanentemente a Permission do ApplicationRole
- Usuários com este ApplicationRole perdem acesso à Permission removida
- Considerar confirmação adicional para Permissions críticas

**Auditoria:**
- Registrar exclusão em `AuditLogs` com motivo (se fornecido)
- Incluir informações detalhadas da Permission removida
- Invalidar cache de permissions para usuários afetados

---

### 4.8 Avaliar Permissions de ApplicationRole (POST /v1/tenants/{tenantId}/roles/{roleId}/evaluate-permissions)
**Contexto:** Verificar se um ApplicationRole possui Permission específica.

**Regras:**
- Verificar se existe RolePermission ativo entre o ApplicationRole e Permission solicitados
- Considerar apenas RolePermissions, ApplicationRoles e Permissions ativos
- Retornar resultado booleano com detalhes da associação

**Payload de entrada:**
```json
{
  "applicationId": "guid",
  "resourceId": "guid", 
  "actionId": "guid"
}
```

**Resposta:**
```json
{
  "hasPermission": true,
  "permissionId": "guid",
  "permissionCode": "PERM-251221-XTG2",
  "rolePermissionId": "guid",
  "grantedAt": "2025-01-01T00:00:00Z",
  "grantedBy": "user-guid",
  "riskLevel": 5
}
```

---

## 5. Regras de Integridade e Dependência

### 5.1 Dependências obrigatórias
- Todo RolePermission deve referenciar um `TenantId` válido e ativo
- Todo RolePermission deve referenciar: 
  - `ApplicationRoleId` válido, ativo e do mesmo Tenant
  - `PermissionId` válida, ativa e do mesmo Tenant
- A combinação (TenantId, ApplicationRoleId, PermissionId) deve ser única

### 5.2 Integridade referencial
- RolePermissions são utilizados indiretamente através de UserApplicationRoles
- Não permitir exclusão de ApplicationRoles ou Permissions que tenham RolePermissions ativos
- Implementar verificação de dependências antes de operações destrutivas

### 5.3 Cascata de operações
**Desativação de ApplicationRole:**
- Desativar automaticamente todos os RolePermissions associados
- Notificar usuários afetados sobre perda de privilégios

**Desativação de Permission:**
- Desativar automaticamente todos os RolePermissions que a utilizam
- Registrar impacto em ApplicationRoles afetados

**Desativação de Tenant:**
- Desativar automaticamente todos os RolePermissions do Tenant
- Não permitir criação de novos RolePermissions

### 5.4 Consistência de dados
- RolePermissions ativos devem sempre ter ApplicationRole e Permission ativos
- Manter consistência temporal entre criação/atualização de registros relacionados
- Garantir que associações órfãs não sejam criadas

---

## 6. Regras de Segurança

### 6.1 Isolamento multi-tenant
- Implementar Row-Level Security (RLS) baseado em TenantId
- Todas as consultas devem automaticamente filtrar pelo Tenant do contexto
- Validar TenantId em todas as operações para prevenir vazamento de dados
- Validar que ApplicationRole e Permission pertencem ao mesmo Tenant

### 6.2 Controle de acesso
**Permissões necessárias:**
- **Criar RolePermission:** Permissão de gerenciamento de ApplicationRoles no Tenant
- **Consultar RolePermissions:** Permissão de leitura de ApplicationRoles no Tenant
- **Ativar/Desativar:** Permissão de gerenciamento de ApplicationRoles no Tenant
- **Remover RolePermission:** Permissão de gerenciamento de ApplicationRoles no Tenant
- **Avaliar Permissions:** Permissão específica ou contextual baseada no usuário

### 6.3 Políticas de segurança
- Permissions de alto risco (`RiskLevel >= 8`) podem exigir aprovação adicional
- Remoção de Permissions administrativas pode exigir confirmação dupla
- Auditoria especial para alterações em RolePermissions críticos
- Monitoramento de uso de Permissions de alto risco

### 6.4 Auditoria de segurança
- Registrar todas as operações críticas (criação, alteração, remoção)
- Incluir contexto completo do usuário (IP, User Agent, etc.)
- Monitorar tentativas de acesso cross-tenant
- Log especial para avaliações de Permission

### 6.5 Validação de entrada
- Sanitizar campos de entrada
- Validar GUIDs de referência
- Verificar existência de entidades referenciadas

---

## 7. Regras de Governança

### 7.1 Gestão de privilégios
- Revisar periodicamente RolePermissions para detectar privilégios excessivos
- Implementar processo de aprovação para Permissions críticas
- Documentar justificativa para associações de alto risco
- Manter princípio do menor privilégio necessário

### 7.2 Lifecycle management
- Definir ciclo de vida claro para RolePermissions
- Processos para revisão periódica de associações
- Remoção automática de RolePermissions obsoletos
- Comunicação prévia de mudanças impactantes

### 7.3 Documentação
- Manter documentação atualizada dos ApplicationRoles e suas Permissions
- Documentar propósito de cada associação
- Incluir informações sobre riscos e controles

---

## 8. Estrutura da API

### 8.1 Endpoints
```
GET    /v1/tenants/{tenantId}/applications/{applicationId}/roles/{roleId}/permissions
GET    /v1/tenants/{tenantId}/role-permissions/{id}
POST   /v1/tenants/{tenantId}/applications/{applicationId}/roles/{roleId}/permissions
PATCH  /v1/tenants/{tenantId}/role-permissions/{id}/activate
PATCH  /v1/tenants/{tenantId}/role-permissions/{id}/deactivate
DELETE /v1/tenants/{tenantId}/role-permissions/{id}
GET    /v1/tenants/{tenantId}/users/{userId}/permissions
POST   /v1/tenants/{tenantId}/roles/{roleId}/evaluate-permissions
```

### 8.2 DTOs

#### RolePermissionCreateDto
```csharp
public class RolePermissionCreateDto
{
    public Guid PermissionId { get; set; }          // Required
}
```

#### RolePermissionResponseDto
```csharp
public class RolePermissionResponseDto
{
    public Guid Id { get; set; }
    public Guid TenantId { get; set; }
    public Guid ApplicationRoleId { get; set; }
    public Guid PermissionId { get; set; }
    public int Status { get; set; }
    public bool IsActive { get; set; }
    public bool IsDeleted { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime?  UpdatedAt { get; set; }
    
    // Dados do ApplicationRole
    public string RoleName { get; set; }
    public string RoleDescription { get; set; }
    
    // Dados da Permission
    public string PermissionName { get; set; }
    public string PermissionCode { get; set; }
    public string PermissionDescription { get; set; }
    public int PermissionRiskLevel { get; set; }
    
    // Dados dos componentes da Permission
    public string ApplicationName { get; set; }
    public string ResourceName { get; set; }
    public string ActionName { get; set; }
    public string CategoryName { get; set; }
}
```

#### UserPermissionResponseDto
```csharp
public class UserPermissionResponseDto
{
    public Guid PermissionId { get; set; }
    public string PermissionName { get; set; }
    public string PermissionCode { get; set; }
    public int RiskLevel { get; set; }
    public List<RoleGrantInfoDto> GrantedThrough { get; set; }
    public string ApplicationName { get; set; }
    public string ResourceName { get; set; }
    public string ActionName { get; set; }
    public string CategoryName { get; set; }
}
```

---

## 9. Validações

### 9.1 Validações de criação
- `PermissionId`: Obrigatório, deve existir e pertencer ao Tenant
- ApplicationRole deve estar ativo e pertencer ao Tenant
- Permission deve estar ativa e pertencer ao Tenant
- Combinação (ApplicationRoleId, PermissionId) deve ser única no Tenant
- ApplicationRole e Permission devem ser compatíveis (mesmo Tenant)

### 9.2 Validações de ativação
- RolePermission deve existir e não estar deletado
- ApplicationRole deve estar ativo
- Permission deve estar ativa
- RolePermission não pode estar já ativo

### 9.3 Validações de remoção
- RolePermission deve existir e pertencer ao Tenant
- Verificar políticas de segurança antes da remoção
- Confirmar se não é a última Permission administrativa crítica

---

## 10. Considerações de Performance

### 10.1 Indexação
**Índices obrigatórios:**
- `(TenantId, ApplicationRoleId, PermissionId) UNIQUE` - Unicidade e consultas principais
- `(TenantId, ApplicationRoleId, IsActive, IsDeleted)` - Consultas por ApplicationRole
- `(TenantId, PermissionId, IsActive, IsDeleted)` - Consultas por Permission
- `(TenantId, IsActive, IsDeleted)` - Consultas gerais

### 10.2 Caching
- Cachear RolePermissions ativos por ApplicationRole
- Cachear Permissions efetivas por usuário (TTL curto)
- Invalidar cache ao criar/atualizar/remover RolePermissions
- TTL do cache: 5 minutos para dados gerais, 2 minutos para avaliações de usuário

### 10.3 Otimização de consultas
- Sempre aplicar filtro `IsDeleted = false` nas consultas
- Usar paginação em listagens
- Considerar views materializadas para consultas frequentes de permissions por usuário
- Denormalizar dados básicos para reduzir joins

---

## 11. Cenários de Uso

### 11.1 Setup inicial de ApplicationRole
1. Administrador cria ApplicationRole na Application
2. Identifica Permissions necessárias para o papel
3. Cria RolePermissions associando Permission ao ApplicationRole
4. Testa funcionalidade atribuindo ApplicationRole a usuário de teste
5. Valida que usuário possui acesso adequado

### 11.2 Gestão de privilégios de usuário
1. Usuário recebe novo ApplicationRole através de UserApplicationRoles
2. Sistema automaticamente concede todas as Permissions do ApplicationRole
3. Usuário pode acessar recursos baseado nas Permissions efetivas
4. Administrador pode remover Permissions específicas via RolePermissions
5. Usuário perde acesso imediatamente após alteração

### 11.3 Auditoria de privilégios
1. Administrador de segurança lista Permissions de ApplicationRole específico
2. Identifica Permissions de alto risco ou desnecessárias
3. Remove RolePermissions excessivos
4. Monitora impacto em usuários que possuem o ApplicationRole
5. Documenta alterações para conformidade

### 11.4 Resposta a incidente de segurança
1. Detectado uso indevido de Permission específica
2. Administrador identifica ApplicationRoles que possuem a Permission
3. Desativa RolePermissions temporariamente
4. Investiga usuários afetados e analisa logs de auditoria
5. Reativa RolePermissions após implementar controles adicionais

---

## 12. Testes e Validação

### 12.1 Casos de teste obrigatórios
**Criação:**
- Criar RolePermission válido
- Rejeitar criação com PermissionId inválida
- Rejeitar criação de associação duplicada
- Rejeitar criação com ApplicationRole inativo
- Rejeitar criação com Permission inativa

**Consulta:**
- Listar RolePermissions por ApplicationRole
- Filtrar por status ativo/inativo
- Consultar Permissions efetivas por usuário
- Performance com grandes volumes de dados

**Ativação/Desativação:**
- Ativar RolePermission inativo
- Rejeitar ativação de RolePermission já ativo (validação explícita)
- Desativar RolePermission ativo  
- Rejeitar desativação de RolePermission já inativo (validação explícita)
- Verificar invalidação de cache

**Remoção:**
- Remover RolePermission válido
- Verificar soft delete
- Confirmar impacto em usuários

### 12.2 Testes de segurança
- Verificar isolamento multi-tenant rigoroso
- Validar controle de acesso por permissões
- Testar tentativas de acesso cross-tenant
- Validar sanitização de entrada

### 12.3 Testes de integridade
- Verificar consistência de foreign keys
- Validar cascata de operações
- Testar constraints de unicidade
- Verificar invalidação adequada de cache

### 12.4 Testes de performance
- Performance de consultas de permissions por usuário
- Eficiência do cache
- Tempo de resposta das APIs principais
- Impacto de operações em grande escala

---

## 13. Métricas e Monitoramento

### 13.1 Métricas operacionais
- **RolePermissions por Tenant:** Distribuição por cliente
- **RolePermissions por ApplicationRole:** Complexidade de papéis
- **Permissions mais atribuídas:** Identificar padrões de uso
- **Taxa de remoção:** Frequência de alterações em privilégios

### 13.2 Métricas de segurança
- **Permissions críticas por ApplicationRole:** Monitoramento de riscos
- **Alterações em RolePermissions:** Frequência e padrões
- **ApplicationRoles com muitas Permissions:** Identificar excessos
- **Usuários com Permissions críticas:** Monitoramento de privilégios

### 13.3 Métricas de performance
- **Tempo de consulta de permissions:** Performance crítica
- **Hit ratio de cache:** Eficiência do caching
- **Volume de avaliações:** Carga no sistema

---

## 14. Integração com Outros Módulos

### 14.1 ApplicationRoles
- RolePermission depende diretamente de ApplicationRole
- Desativação de ApplicationRole desativa todos RolePermissions associados
- Validar consistência ApplicationRole-RolePermission

### 14.2 Permissions
- RolePermission depende diretamente de Permission
- Desativação de Permission desativa RolePermissions associados
- Não permitir exclusão de Permission com RolePermissions ativos

### 14.3 UserApplicationRoles
- RolePermissions definem quais Permissions um usuário possui através de seus ApplicationRoles
- Alterações em RolePermissions afetam imediatamente usuários
- Cache de permissions por usuário deve ser invalidado

### 14.4 Tenants
- RolePermissions estão isolados por Tenant (RLS)
- Desativação de Tenant afeta todos seus RolePermissions
- Validar contexto de Tenant em todas as operações

### 14.5 AuditLogs
- Todas as operações críticas geram logs de auditoria
- Incluir contexto completo para investigação
- Rastrear mudanças em RolePermissions críticos

---

## 15. Conclusão
O módulo **RolePermissions** é um componente fundamental para o funcionamento do sistema RBAC do IAM VianaID. 

As regras aqui definidas garantem:
- **Flexibilidade:** Associação granular entre papéis e permissões
- **Segurança:** Isolamento multi-tenant rigoroso e controle de acesso
- **Integridade:** Validação rigorosa de dependências e consistência
- **Auditoria:** Rastreamento completo de alterações em privilégios
- **Performance:** Estrutura otimizada para consultas frequentes
- **Governança:** Gestão adequada de privilégios e riscos
- **Escalabilidade:** Arquitetura preparada para grandes volumes

Com esta estrutura detalhada, o sistema garante gestão eficiente de privilégios através de papéis, mantendo simplicidade operacional e segurança empresarial robusta.  O módulo serve como ponte essencial entre ApplicationRoles e Permissions, permitindo controle de acesso flexível e auditável.  🚀