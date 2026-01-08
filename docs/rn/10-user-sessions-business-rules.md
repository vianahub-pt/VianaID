# Documento de Regras de Negócio — UserSessions

## 1. Introdução
Este documento descreve de forma detalhada as regras de negócio do módulo **UserSessions** no sistema IAM (VianaID).

Um **UserSession** representa uma sessão de autenticação ativa de um usuário, gerenciando tokens de renovação (refresh tokens), informações de dispositivo, telemetria de acesso e ciclo de vida da sessão. 

---

## 2. Objetivos do Módulo de UserSessions
- Gerenciar sessões de autenticação por usuário e Tenant. 
- Controlar ciclo de vida de tokens de renovação (refresh tokens).
- Registrar telemetria de acesso (dispositivo, IP, user agent).
- Permitir auditoria e rastreamento de atividades por sessão.
- Suportar revogação individual ou em massa de sessões. 
- Detectar e prevenir uso indevido de tokens. 
- Garantir isolamento de sessões por Tenant.

---

## 3. Estrutura Geral do UserSession
Um **UserSession** contém: 
- `Id`
- `TenantId`
- `UserAccountId`
- `RefreshTokenHash` (hash do token de renovação)
- `ExpiresAt` (data/hora de expiração da sessão)
- Telemetria (`DeviceInfo`, `IpAddress`, `UserAgent`)
- Rastreamento de uso (`LastUsedAt`)
- Controle de revogação (`RevokedAt`, `RevokedReason`)
- Estado (`Status`, `IsActive`, `IsDeleted`)
- Auditoria (`CreatedBy`, `CreatedAt`, `UpdatedBy`, `UpdatedAt`)

### 3.1 Regras do campo RefreshTokenHash
- O refresh token **nunca é armazenado em texto plano**.
- Apenas o **hash criptográfico do token** é persistido no banco de dados.
- O algoritmo de hash deve ser resistente a colisões (ex.: SHA256, SHA512).
- A comparação de tokens durante renovação deve ser feita via hash. 
- O hash deve incluir salt único por sessão para maior segurança.

### 3.2 Escopo Multi-tenant
- Toda UserSession pertence exatamente a um Tenant. 
- Toda UserSession está vinculada a exatamente um UserAccount.
- Consultas e operações devem respeitar Row-Level Security (RLS).
- Um usuário pode possuir múltiplas sessões simultâneas (diferentes dispositivos/navegadores).
- O número máximo de sessões simultâneas pode ser limitado por Plano. 

---

## 4. Regras de Negócio por Operação

### 4.1 Criar Sessão (POST /v1/tenants/{tenantId}/users/{userId}/sessions)
**Contexto:** Executado automaticamente após autenticação bem-sucedida (login).

**Regras:**
- A sessão é criada com `IsActive = true` e `IsDeleted = false`.
- O campo `RefreshTokenHash` deve conter o hash do refresh token gerado.
- O campo `ExpiresAt` deve ser calculado com base na política de expiração de tokens do Tenant/Aplicação. 
- Os campos de telemetria (`DeviceInfo`, `IpAddress`, `UserAgent`) devem ser extraídos do contexto da requisição HTTP.
- O campo `LastUsedAt` deve ser inicializado com a data/hora de criação. 
- O `UserAccountId` deve referenciar um usuário ativo e não deletado. 
- O `TenantId` deve corresponder ao Tenant do usuário.
- O `CreatedBy` deve ser preenchido com o `Id` do próprio usuário.
- O `Status` deve ser inicializado com valor padrão (ex.: 1 - Ativo).

**Validações:**
- O usuário deve estar ativo (`IsActive = true`).
- O usuário não pode estar deletado (`IsDeleted = false`).
- O usuário não pode estar em lockout (`LockoutEnd` deve ser nulo ou anterior à data/hora atual).
- O Tenant deve estar ativo. 
- O e-mail do usuário deve estar confirmado (`EmailConfirmed = true`), se a política exigir.

**Limite de sessões simultâneas:**
- Verificar se o usuário já atingiu o limite máximo de sessões simultâneas definido pelo Plano.
- Se o limite for atingido, aplicar política configurável: 
  - Rejeitar nova sessão (retornar erro).
  - Revogar sessão mais antiga (FIFO).
  - Permitir escolha do usuário sobre qual sessão revogar.

---

### 4.2 Consultar Sessões (GET /v1/tenants/{tenantId}/users/{userId}/sessions)
**Contexto:** Permite ao usuário ou administrador visualizar sessões ativas.

**Regras:**
- Devem ser retornadas apenas sessões não deletadas (`IsDeleted = false`).
- Aplicar filtros por: 
  - Status (`Status`, `IsActive`)
  - Revogadas ou ativas (`RevokedAt IS NULL` ou `RevokedAt IS NOT NULL`)
  - Expiradas (`ExpiresAt < GETDATE()`)
  - Dispositivo (`DeviceInfo` - busca parcial)
  - Período de criação (`CreatedAt` - range)
- Ordenação padrão: mais recentes primeiro (`CreatedAt DESC`).
- Suportar paginação obrigatória. 

**Projeção de dados:**
- **Nunca retornar** o campo `RefreshTokenHash` nas respostas da API.
- Incluir apenas metadados de sessão: 
  - `Id`
  - `CreatedAt`
  - `LastUsedAt`
  - `ExpiresAt`
  - `DeviceInfo`
  - `IpAddress`
  - `IsActive`
  - `RevokedAt`
  - Indicador se a sessão é a sessão atual (opcional)

**Permissões:**
- Usuário pode consultar apenas suas próprias sessões.
- Administrador pode consultar sessões de qualquer usuário do Tenant. 

---

### 4.3 Consultar Sessão por ID (GET /v1/tenants/{tenantId}/users/{userId}/sessions/{id})
**Regras:**
- Retornar apenas se a sessão pertencer ao Tenant e usuário especificados.
- Não retornar sessões deletadas.
- **Nunca retornar** o campo `RefreshTokenHash`.
- Incluir informações detalhadas de telemetria.

**Validações:**
- Verificar permissões do solicitante (próprio usuário ou administrador).
- Aplicar RLS por TenantId. 

---

### 4.4 Renovar Sessão (POST /v1/tenants/{tenantId}/users/{userId}/sessions/refresh)
**Contexto:** Renovação de access token usando refresh token.

**Regras:**
- O refresh token fornecido na requisição deve ser hasheado e comparado com `RefreshTokenHash`.
- A sessão deve estar ativa (`IsActive = true`).
- A sessão não pode estar revogada (`RevokedAt IS NULL`).
- A sessão não pode estar expirada (`ExpiresAt > GETDATE()`).
- O usuário vinculado deve estar ativo e não deletado.
- O Tenant deve estar ativo.
- Atualizar o campo `LastUsedAt` com a data/hora da renovação. 
- Atualizar `IpAddress` e `UserAgent` com valores atuais (para auditoria).

**Rotação de refresh tokens (recomendado):**
- Gerar um novo refresh token.
- Atualizar o `RefreshTokenHash` com o hash do novo token.
- Retornar o novo refresh token ao cliente. 
- Opcionalmente, manter token anterior válido por período de graça (para evitar problemas de sincronização).

**Validações:**
- Se o token fornecido não corresponder ao hash armazenado, rejeitar a requisição (401 Unauthorized).
- Se a sessão estiver revogada ou expirada, retornar erro apropriado (401 Unauthorized).
- Se houver múltiplas tentativas de renovação com token inválido, registrar evento de segurança.

**Detecção de anomalias:**
- Comparar `IpAddress` atual com anterior. 
- Se houver mudança significativa de localização geográfica, considerar: 
  - Registrar evento de segurança. 
  - Exigir MFA adicional.
  - Notificar usuário. 

**Atualização de auditoria:**
- Registrar evento de renovação de sessão.
- Incrementar contador de renovações (se aplicável).

---

### 4.5 Revogar Sessão (DELETE /v1/tenants/{tenantId}/users/{userId}/sessions/{id})
**Contexto:** Encerramento manual de uma sessão (logout de dispositivo específico).

**Regras:**
- A sessão deve ser marcada como revogada: 
  - `RevokedAt = GETDATE()`
  - `IsActive = false`
  - `RevokedReason` deve ser preenchido com motivo apropriado.
- A sessão **não deve ser deletada fisicamente** (manter para auditoria).
- O `UpdatedBy` deve ser preenchido com o `Id` do usuário ou administrador que revogou.
- O `UpdatedAt` deve ser atualizado com a data/hora da revogação.

**Motivos de revogação possíveis:**
- `"User logout"` - Logout iniciado pelo usuário.
- `"Admin revocation"` - Revogação administrativa.
- `"Security event"` - Revogação por evento de segurança.
- `"Password changed"` - Revogação por alteração de senha.
- `"Account deactivated"` - Revogação por desativação de conta.
- `"Inactivity timeout"` - Revogação por inatividade. 

**Validações:**
- A sessão deve pertencer ao Tenant e usuário especificados.
- Apenas o próprio usuário ou um administrador com permissões adequadas pode revogar sessões.
- Não permitir revogação de sessão já revogada (operação idempotente).

**Após revogação:**
- Qualquer tentativa de uso do refresh token deve falhar com erro apropriado.
- Registrar evento de auditoria.
- Opcionalmente, notificar usuário sobre revogação.

---

### 4.6 Revogar Todas as Sessões do Usuário (DELETE /v1/tenants/{tenantId}/users/{userId}/sessions)
**Contexto:** Logout global (encerrar todas as sessões ativas do usuário).

**Regras:**
- Revogar todas as sessões ativas do usuário: 
  - `RevokedAt = GETDATE()`
  - `IsActive = false`
  - `RevokedReason` deve indicar motivo da revogação em massa.
- Aplicar apenas em sessões não revogadas e não expiradas.
- Permitir opção de excluir sessão atual (sessão que está fazendo a requisição).
- Registrar auditoria da operação. 
- O `UpdatedBy` deve ser preenchido apropriadamente. 

**Casos de uso:**
- Logout global iniciado pelo usuário.
- Revogação de emergência por suspeita de comprometimento.
- Alteração de senha (deve revogar todas exceto a sessão atual, opcionalmente).
- Alteração de SecurityStamp. 
- Desativação de conta.

**Validações:**
- Apenas o próprio usuário ou administrador pode executar logout global.
- Confirmar ação antes de executar (recomendado).

**Processamento:**
- Executar operação em transação para garantir atomicidade.
- Se falhar revogação de qualquer sessão, fazer rollback completo. 

---

### 4.7 Limpeza Automática de Sessões Expiradas (Job)
**Contexto:** Processo automatizado de limpeza de sessões. 

**Regras:**
- Executar periodicamente via job agendado (ex.: diariamente às 03:00 UTC).
- Identificar sessões elegíveis para limpeza: 
  - `ExpiresAt < GETDATE()`
  - `IsDeleted = false`
  - Opcionalmente, `RevokedAt IS NOT NULL` e período de retenção expirado. 

**Estratégia de limpeza:**
- **Fase 1 - Soft delete de sessões expiradas:**
  - Marcar como deletadas (`IsDeleted = true`).
  - Manter para auditoria por período configurável (ex.: 90 dias).
- **Fase 2 - Hard delete após período de retenção:**
  - Remover fisicamente registros com `IsDeleted = true` e `UpdatedAt` mais antigo que período de retenção.

**Política de retenção sugerida:**
- Sessões ativas: até expiração natural.
- Sessões revogadas: 90 dias após revogação. 
- Sessões expiradas: 90 dias após expiração. 
- Sessões deletadas logicamente:  365 dias para conformidade.

**Logging:**
- Registrar quantidade de sessões limpas por execução.
- Alertar se volume de limpeza for anormal.

---

## 5. Regras de Integridade e Dependência

### 5.1 Dependências obrigatórias
- Toda UserSession deve referenciar um `UserAccountId` válido e existente.
- Toda UserSession deve referenciar um `TenantId` válido e existente.
- A combinação `TenantId` + `UserAccountId` deve ser consistente (UserAccount pertence ao Tenant).

### 5.2 Cascata de operações
**Desativação de usuário:**
- Revogar automaticamente todas as sessões ativas do usuário.
- Definir `RevokedReason = "Account deactivated"`.

**Alteração de senha:**
- Revogar todas as sessões ativas (exceto a sessão atual, opcionalmente).
- Renovar `SecurityStamp` no UserAccount. 
- Definir `RevokedReason = "Password changed"`.

**Desativação de Tenant:**
- Revogar todas as sessões de todos os usuários do Tenant. 
- Definir `RevokedReason = "Tenant deactivated"`.

**Deleção lógica de usuário:**
- Revogar todas as sessões. 
- Definir `RevokedReason = "Account deleted"`.

### 5.3 Consistência de dados
- O `RefreshTokenHash` deve ser único entre sessões ativas não revogadas.
- Não permitir duplicação de refresh tokens ativos.
- Garantir atomicidade em operações de criação e revogação.

### 5.4 Integridade referencial
- Implementar foreign keys apropriadas. 
- Não permitir orfandade de sessões.
- Considerar deleção em cascata para operações administrativas específicas.

---

## 6. Regras de Segurança

### 6.1 Proteção de tokens
- **Nunca expor** refresh tokens ou seus hashes em: 
  - Logs de aplicação.
  - Respostas de API.
  - Interfaces de usuário.
  - Mensagens de erro.
- Utilizar algoritmos de hash resistentes (SHA256, SHA512, Argon2).
- Implementar salt único por sessão.
- Considerar uso de pepper armazenado em configuração segura.

### 6.2 Detecção de anomalias
**Monitorar:**
- Mudanças de IP entre renovações.
- Mudanças de user agent.
- Mudanças de dispositivo.
- Múltiplas tentativas de renovação com token inválido. 
- Renovações de localizações geográficas distantes em curto período.

**Ações em caso de anomalia:**
- Registrar evento em `SecurityEvents`.
- Exigir MFA adicional.
- Revogar sessão suspeita.
- Notificar usuário por e-mail. 
- Bloquear temporariamente renovações até confirmação.

### 6.3 Limites operacionais
**Por usuário:**
- Limitar número máximo de sessões simultâneas (configurável por Plano).
- Valores sugeridos: 
  - Plano Free: 2 sessões. 
  - Plano Pro: 5 sessões. 
  - Plano Enterprise: 10+ sessões. 

**Por requisição:**
- Implementar rate limiting em endpoints de renovação.
- Limite sugerido: 10 renovações por minuto por sessão. 

**Tentativas de renovação:**
- Limitar tentativas com token inválido (ex.: 5 tentativas).
- Após limite, revogar sessão automaticamente.
- Registrar evento de segurança.

### 6.4 Rotação de tokens
**Estratégia recomendada:**
- Rotação automática a cada renovação (refresh token rotation).
- Invalidar token anterior imediatamente após uso bem-sucedido.
- Implementar período de graça para evitar condições de corrida (ex.: 30 segundos).

**Detecção de replay attack:**
- Se token já utilizado for apresentado novamente, revogar sessão imediatamente.
- Registrar evento de segurança crítico. 
- Notificar usuário. 

### 6.5 Proteção contra CSRF
- Refresh tokens devem ser armazenados em httpOnly cookies.
- Implementar SameSite=Strict ou Lax. 
- Validar origem das requisições.

### 6.6 Proteção contra XSS
- Nunca expor tokens em JavaScript acessível.
- Utilizar Content Security Policy adequada. 

---

## 7. Regras de Auditoria e Observabilidade

### 7.1 Registro de eventos
**Eventos obrigatórios:**
- **Criação de sessão:** Registrar login bem-sucedido com telemetria completa.
- **Renovação de sessão:** Registrar cada uso de refresh token.
- **Revogação de sessão:** Registrar logout ou revogação administrativa com motivo.
- **Falha de renovação:** Registrar tentativas com token inválido ou expirado.
- **Detecção de anomalia:** Registrar eventos suspeitos. 
- **Limite de sessões atingido:** Registrar quando usuário atinge limite. 

**Campos obrigatórios no log:**
- `SessionId`
- `TenantId`
- `UserAccountId`
- `EventType`
- `Timestamp`
- `IpAddress`
- `UserAgent`
- `Success` (booleano)
- `ErrorMessage` (se aplicável)

### 7.2 Telemetria
**Métricas a coletar:**
- Número de sessões ativas por Tenant.
- Número de sessões ativas por usuário.
- Taxa de renovação de tokens.
- Taxa de revogação de sessões. 
- Duração média de sessões.
- Distribuição geográfica de sessões (opcional).
- Tipos de dispositivos mais utilizados.

**Alertas:**
- Pico anormal de criação de sessões.
- Pico anormal de falhas de renovação.
- Usuário com número excessivo de sessões. 
- Múltiplas sessões do mesmo usuário de localizações distantes.

### 7.3 Conformidade
**LGPD / GDPR:**
- Manter histórico de sessões para fins de auditoria.
- Permitir que usuários visualizem histórico de suas sessões.
- Permitir que usuários revoguem sessões ativas. 
- Implementar direito ao esquecimento (hard delete após período de retenção).
- Anonimizar dados após período de retenção, se aplicável.

**SOC 2 / ISO 27001:**
- Registro completo de acesso. 
- Rastreabilidade de tokens.
- Política de retenção documentada.
- Controle de acesso baseado em sessões. 

---

## 8. Regras de Governança

### 8.1 Políticas de expiração
**Tempo de vida de refresh tokens (configurável por Tenant/Aplicação):**

**Por tipo de aplicação:**
- **Web SPA:** 7 a 30 dias.
- **Mobile nativo:** 30 a 90 dias.
- **Desktop:** 30 a 90 dias. 
- **Longa duração (remember me):** até 180 dias.

**Por contexto de segurança:**
- **Sem MFA:** Menor tempo de vida (7-14 dias).
- **Com MFA:** Maior tempo de vida (30-90 dias).
- **Dispositivo confiável:** Tempo de vida estendido. 

**Renovação contínua:**
- Permitir renovação contínua até limite máximo (ex.: 180 dias de inatividade).
- Após limite de inatividade, exigir re-autenticação completa. 

### 8.2 Revogação em massa
**Capacidades administrativas:**
- Revogar sessões de usuário específico.
- Revogar todas as sessões de um Tenant.
- Revogar sessões por critérios: 
  - Inativas há X dias.
  - De dispositivos específicos.
  - De localizações específicas.
  - Criadas antes de data específica.

**Casos de uso:**
- Resposta a incidente de segurança.
- Migração de sistema.
- Manutenção programada. 
- Comprometimento de infraestrutura.

### 8.3 Notificações
**Eventos que devem gerar notificação:**
- Nova sessão criada (opcional, configurável por usuário).
- Sessão revogada por motivos de segurança.
- Múltiplas tentativas de acesso com token inválido. 
- Acesso de nova localização geográfica. 
- Acesso de novo dispositivo.

**Canais de notificação:**
- E-mail.
- Push notification (mobile).
- In-app notification. 

**Conteúdo da notificação:**
- Tipo de evento.
- Data/hora.
- Dispositivo.
- Localização aproximada.
- Ação recomendada (se aplicável).

---

## 9. Cenários de Uso

### 9.1 Login bem-sucedido
**Fluxo:**
1. Usuário fornece credenciais válidas.
2. Sistema valida credenciais.
3. Sistema verifica se MFA está habilitado: 
   - Se sim, solicitar segundo fator.
   - Se não, prosseguir.
4. Sistema verifica limite de sessões simultâneas. 
5. Sistema gera access token (JWT) e refresh token (UUID).
6. Sistema calcula hash do refresh token.
7. Sistema cria registro em `UserSessions`:
   - `TenantId` do usuário.
   - `UserAccountId`.
   - `RefreshTokenHash` (hash do token).
   - `ExpiresAt` (data/hora atual + tempo de vida configurado).
   - `DeviceInfo`, `IpAddress`, `UserAgent` da requisição.
   - `IsActive = true`.
   - `Status = 1`.
8. Sistema registra evento de auditoria (login bem-sucedido).
9. Access token e refresh token são retornados ao cliente via resposta segura. 
10. Cliente armazena tokens de forma segura (httpOnly cookie ou storage).

---

### 9.2 Renovação de access token
**Fluxo:**
1. Cliente detecta que access token está próximo da expiração ou expirado.
2. Cliente envia refresh token ao endpoint de renovação.
3. Sistema extrai refresh token da requisição.
4. Sistema calcula hash do token recebido.
5. Sistema busca sessão ativa com `RefreshTokenHash` correspondente.
6. Sistema valida sessão: 
   - Sessão existe.
   - `IsActive = true`.
   - `RevokedAt IS NULL`.
   - `ExpiresAt > GETDATE()`.
   - Usuário está ativo.
   - Tenant está ativo.
7. Sistema verifica anomalias (IP, user agent, geolocalização).
8. Sistema gera novo access token (JWT).
9. Se rotação de refresh tokens estiver habilitada:
   - Sistema gera novo refresh token.
   - Sistema calcula hash do novo token.
   - Sistema atualiza `RefreshTokenHash` na sessão.
10. Sistema atualiza campos da sessão: 
    - `LastUsedAt = GETDATE()`.
    - `IpAddress` (atual).
    - `UserAgent` (atual).
    - `UpdatedAt = GETDATE()`.
11. Sistema registra evento de auditoria (renovação bem-sucedida).
12. Novos tokens são retornados ao cliente. 
13. Cliente substitui tokens antigos pelos novos.

---

### 9.3 Logout de dispositivo específico
**Fluxo:**
1. Usuário acessa interface de gerenciamento de sessões.
2. Sistema lista todas as sessões ativas do usuário.
3. Usuário seleciona sessão específica para revogar.
4. Usuário confirma ação.
5. Sistema valida permissões. 
6. Sistema atualiza sessão:
   - `RevokedAt = GETDATE()`.
   - `IsActive = false`.
   - `RevokedReason = "User logout"`.
   - `UpdatedBy` = ID do usuário.
   - `UpdatedAt = GETDATE()`.
7. Sistema registra evento de auditoria (revogação de sessão).
8. Sistema opcionalmente notifica usuário. 
9. Sistema retorna confirmação ao cliente. 
10. Dispositivo revogado perde acesso em próxima tentativa de renovação.

---

### 9.4 Logout global
**Fluxo:**
1. Usuário solicita logout de todos os dispositivos.
2. Sistema confirma ação (diálogo de confirmação).
3. Sistema busca todas as sessões ativas do usuário: 
   - `UserAccountId = {userId}`.
   - `IsActive = true`.
   - `RevokedAt IS NULL`.
4. Sistema permite opção de manter sessão atual ativa (opcional).
5. Sistema revoga todas as sessões encontradas em transação: 
   - `RevokedAt = GETDATE()`.
   - `IsActive = false`.
   - `RevokedReason = "Global logout"`.
   - `UpdatedBy` = ID do usuário.
   - `UpdatedAt = GETDATE()`.
6. Sistema registra evento de auditoria (logout global).
7. Sistema opcionalmente notifica usuário.
8. Sistema retorna confirmação ao cliente. 
9. Todos os dispositivos perdem acesso em próxima tentativa de renovação.

---

### 9.5 Alteração de senha
**Fluxo:**
1. Usuário solicita alteração de senha.
2. Sistema valida senha atual.
3. Sistema valida nova senha (complexidade, histórico).
4. Sistema atualiza `UserAccounts`:
   - `PasswordHash` (novo hash).
   - `SecurityStamp` (novo GUID).
   - `PasswordChangedAt = GETDATE()`.
   - `UpdatedAt = GETDATE()`.
5. Sistema busca todas as sessões ativas do usuário (exceto sessão atual, opcionalmente).
6. Sistema revoga sessões encontradas: 
   - `RevokedAt = GETDATE()`.
   - `IsActive = false`.
   - `RevokedReason = "Password changed"`.
7. Sistema registra evento de auditoria (alteração de senha).
8. Sistema envia notificação por e-mail ao usuário.
9. Sistema retorna confirmação ao cliente.
10. Outros dispositivos perdem acesso e devem autenticar com nova senha.

---

### 9.6 Detecção de uso suspeito
**Fluxo:**
1. Cliente tenta renovar token de localização geograficamente distante da última renovação.
2. Sistema detecta anomalia (ex.: última renovação em São Paulo, nova renovação em Tóquio, intervalo de 10 minutos).
3. Sistema registra evento em `SecurityEvents`:
   - `EventType = "Suspicious session activity"`.
   - `Severity = "WARNING"`.
   - Metadados com detalhes da anomalia.
4. Sistema decide ação baseado em política: 
   - **Opção 1:** Bloquear renovação e exigir MFA adicional.
   - **Opção 2:** Revogar sessão automaticamente.
   - **Opção 3:** Permitir renovação mas notificar usuário.
5. Sistema envia notificação ao usuário por e-mail: 
   - "Detectamos acesso à sua conta de nova localização."
   - Detalhes do acesso.
   - Link para revisão de sessões e revogação.
6. Usuário revisa notificação e toma ação apropriada.

---

## 10. Regras Complementares

### 10.1 Compatibilidade com OAuth/OIDC
- Se o sistema suportar provedores externos (OAuth/OIDC), sessões devem vincular tokens externos.
- Armazenar referência a tokens do provedor externo (opcional).
- Revogação de sessão local pode exigir revogação junto ao provedor externo (se suportado).
- Implementar token introspection para validação de tokens externos.

### 10.2 Suporte a múltiplos dispositivos
- Permitir que usuários gerenciem sessões por dispositivo/navegador.
- Interface para listar sessões com informações descritivas: 
  - Tipo de dispositivo (mobile, desktop, tablet).
  - Sistema operacional.
  - Navegador.
  - Localização aproximada.
  - Data de último acesso.
  - Indicador de sessão atual. 
- Permitir revogação individual de sessões. 
- Permitir renomear sessões (opcional, para identificação mais fácil).

### 10.3 Integração com MFA
- Sessões criadas após autenticação com MFA podem ter tempo de vida estendido.
- Armazenar indicador de MFA utilizado na criação da sessão (opcional).
- Sessões sem MFA podem ter restrições adicionais: 
  - Tempo de vida reduzido. 
  - Acesso limitado a recursos sensíveis.
  - Exigência de re-autenticação para operações críticas.

### 10.4 Dispositivos confiáveis
- Permitir marcar dispositivos como "confiáveis". 
- Sessões de dispositivos confiáveis podem ter: 
  - Tempo de vida estendido.
  - Menor rigor em detecção de anomalias. 
  - MFA menos frequente.
- Armazenar fingerprint do dispositivo (opcional).
- Permitir usuário gerenciar lista de dispositivos confiáveis.

### 10.5 Remember Me
- Suportar funcionalidade "Manter-me conectado".
- Sessões "remember me" têm tempo de vida significativamente maior.
- Armazenar indicador na sessão (`RememberMe` boolean).
- Aplicar políticas de segurança adicionais:
  - Exigir MFA periódico.
  - Detectar anomalias mais rigorosamente. 

---

## 11. Integração com Outros Módulos

### 11.1 UserAccounts
- UserSession depende diretamente de UserAccount.
- Alterações em UserAccount podem afetar sessões: 
  - Desativação → Revogar sessões.
  - Alteração de senha → Revogar sessões.
  - Deleção → Revogar sessões.
- Consultar sessões deve validar se usuário ainda existe e está ativo.

### 11.2 Tenants
- UserSession está isolada por Tenant (RLS).
- Desativação de Tenant deve revogar todas as sessões de seus usuários.
- Políticas de sessão podem ser configuradas por Tenant.

### 11.3 Applications
- Sessões podem estar vinculadas a aplicações específicas (opcional).
- Diferentes aplicações podem ter políticas de sessão diferentes.
- Revogação de aplicação pode revogar sessões associadas.

### 11.4 AuditLogs
- Todas as operações críticas em sessões devem gerar registros de auditoria.
- Logs devem incluir contexto completo para investigação. 

### 11.5 SecurityEvents
- Eventos de segurança relacionados a sessões devem ser registrados.
- Integração com sistema de detecção de ameaças.

### 11.6 Subscriptions / Plans
- Limites de sessões simultâneas podem ser definidos por Plano.
- Verificar limite antes de criar nova sessão. 

---

## 12. Métricas e KPIs

### 12.1 Métricas operacionais
- **Sessões ativas:** Número total de sessões ativas na plataforma.
- **Sessões por Tenant:** Distribuição de sessões por cliente.
- **Sessões por usuário:** Distribuição de sessões por usuário.
- **Taxa de renovação:** Renovações bem-sucedidas vs. falhas.
- **Duração média de sessão:** Tempo entre criação e revogação/expiração. 

### 12.2 Métricas de segurança
- **Taxa de detecção de anomalias:** Percentual de renovações com anomalias detectadas.
- **Taxa de revogação:** Sessões revogadas vs. sessões criadas.
- **Tentativas de renovação inválidas:** Número de tentativas com token inválido.
- **Sessões de múltiplas localizações:** Usuários com sessões em localizações distantes. 

### 12.3 Métricas de negócio
- **Engajamento:** Frequência de renovação como proxy de uso ativo.
- **Retenção:** Duração de sessões como indicador de satisfação. 
- **Distribuição de dispositivos:** Insights sobre preferências de usuários.

---

## 13. Testes e Validação

### 13.1 Casos de teste obrigatórios
**Criação de sessão:**
- Criar sessão para usuário ativo.
- Rejeitar criação para usuário inativo.
- Rejeitar criação para usuário em lockout.
- Verificar limite de sessões simultâneas. 

**Renovação de sessão:**
- Renovar com token válido.
- Rejeitar renovação com token inválido.
- Rejeitar renovação de sessão revogada.
- Rejeitar renovação de sessão expirada. 
- Verificar rotação de tokens.

**Revogação de sessão:**
- Revogar sessão própria.
- Revogar sessão como administrador.
- Rejeitar revogação sem permissões.
- Verificar logout global.

**Segurança:**
- Detectar anomalia de IP.
- Detectar replay attack.
- Aplicar limite de tentativas de renovação. 

### 13.2 Testes de carga
- Simular milhares de sessões simultâneas.
- Simular alta taxa de renovação.
- Verificar performance de consultas com RLS. 

### 13.3 Testes de segurança
- Penetration testing em endpoints de renovação.
- Validar proteção contra CSRF.
- Validar proteção contra XSS. 
- Validar proteção contra replay attacks.

---

## 14. Considerações de Performance

### 14.1 Indexação
**Índices obrigatórios:**
- `(TenantId, UserAccountId, IsActive, IsDeleted)` - Consultas de sessões ativas.
- `(RefreshTokenHash)` - Lookup rápido durante renovação.
- `(ExpiresAt, IsDeleted)` - Limpeza de sessões expiradas. 
- `(TenantId, IsActive, IsDeleted)` - Estatísticas por Tenant.

### 14.2 Caching
- Cachear sessões ativas em Redis/Memcached.
- Invalidar cache ao revogar sessão.
- TTL do cache deve ser menor que tempo de expiração de sessão.

### 14.3 Sharding
- Considerar sharding por TenantId para escala horizontal.
- Particionar tabela por data de criação (opcional, para arquivamento).

---

## 15. Conclusão
O módulo **UserSessions** é fundamental para garantir segurança, rastreabilidade e controle de acesso contínuo no IAM VianaID. 

As regras aqui definidas asseguram:
- **Segurança robusta:** Proteção de tokens, detecção de anomalias, prevenção de ataques.
- **Auditoria completa:** Rastreamento de todas as atividades por sessão.
- **Governança consistente:** Políticas de expiração, revogação e notificação.
- **Experiência do usuário:** Suporte a múltiplos dispositivos, logout seletivo, gerenciamento de sessões. 
- **Conformidade:** Atendimento a requisitos regulatórios (LGPD, GDPR, SOC 2).
- **Escalabilidade:** Arquitetura preparada para crescimento. 
- **Observabilidade:** Métricas e logs para monitoramento e troubleshooting.

Com esta estrutura detalhada e abrangente, o sistema garante gestão robusta, segura e escalável de sessões de autenticação, atendendo aos mais altos padrões de segurança e governança da indústria. 