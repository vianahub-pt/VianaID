# Documento de Regras de Negócio — Categorias

## 1. Introdução
Este documento descreve de forma detalhada as regras de negócio do módulo **Categorias** no sistema IAM (VianaID).

Uma **Categoria** representa um domínio lógico de organização utilizado para agrupar aplicações, recursos, ações e permissões dentro de um Tenant.

---

## 2. Objetivos do Módulo de Categorias
- Organizar domínios funcionais por Tenant.
- Servir como eixo central de classificação para permissões.
- Facilitar auditoria, segurança e rastreabilidade.
- Garantir coerência entre Aplicações, Recursos, Ações e Permissões.

---

## 3. Estrutura Geral da Categoria
Uma **Categoria** contém:
- `Id`
- `TenantId`
- `Code` (código técnico gerado automaticamente pelo sistema)
- `Name`
- `Description`
- Indicadores de estado (`Status`, `IsActive`, `IsDeleted`)
- Dados de auditoria (`CreatedBy`, `CreatedAt`, `UpdatedBy`, `UpdatedAt`)

### 3.1 Regras do campo Code
- O campo **`Code` nunca é informado pelo usuário**.
- O campo **`Code` é imutável** e **nunca pode ser alterado** após a criação da Categoria.
- O `Code` é **gerado automaticamente pela aplicação**, utilizando o componente `CodeGenerator`.
- O formato do código segue obrigatoriamente o padrão:

```
<PREFIXO><YYMMDD><HASH>
```

Onde:
- **CATE**: prefixo fixo que identifica o recurso Categoria.
- **YYMMDD**: data UTC de geração do código.
- **HASH**: sequência alfanumérica aleatória de 4 caracteres.

**Exemplo válido:**
```
CATE251214XTG2
```

- A unicidade do `Code` é garantida pelo sistema.
- Qualquer tentativa de envio ou alteração manual do campo `Code` deve ser ignorada ou rejeitada pela API.

### 3.2 Escopo Multi-tenant
- Toda Categoria pertence obrigatoriamente a um Tenant.
- Não existem Categorias globais neste modelo.
- Todas as operações devem respeitar o contexto do Tenant (TenantContext / RLS).

---

## 4. Regras de Negócio por Operação

### 4.1 Criar Categoria (POST /v1/categories)
- O Tenant deve existir e estar ativo.
- O `Code` é gerado automaticamente.
- A Categoria é criada ativa por padrão.



### 4.2 Cadastro Massivo de Categorias via Upload de CSV

**POST** `/categories/bulk-upload`

Permite o cadastro massivo de categorias através do upload de um arquivo CSV.
O sistema carrega todo o conteúdo do arquivo em memória e realiza o processamento de forma síncrona.

A rota aceita **exclusivamente arquivos no formato CSV**.

#### Estrutura do Arquivo CSV

| Coluna       | Tipo   | Obrigatório | Descrição |
|-------------|--------|-------------|-----------|
| name        | string | Sim         | Nome da categoria |
| description | string | Sim         | Descrição da categoria |

#### Regras
- O arquivo é carregado integralmente em memória.
- O sistema tenta processar todas as linhas.
- Não é permitido cadastro parcial.
- Apenas arquivos `.csv` são aceitos.

#### Respostas
- **200 OK**: todas as categorias cadastradas com sucesso (sem body).
- **400 Bad Request**: retorna a lista de categorias não cadastradas com o motivo da falha.

### 4.3 Consultar Categorias (GET /v1/categories)
- Devem ser retornadas apenas Categorias não deletadas.
- Consultas devem respeitar isolamento por Tenant.

### 4.4 Atualizar Categoria (PUT /v1/categories/{id})
- O `Code` e o `TenantId` não podem ser alterados.
- Alterações devem registrar auditoria.

### 4.5 Ativar Categoria (PATCH /v1/categories/{id}/activate)
**Contexto:** Reativar uma Categoria previamente desativada.

**Regras:**
- Só é permitido ativar uma Categoria existente e não deletada.
- **A Categoria deve estar inativa** (`IsActive = false`) para ser ativada.
- Atualizar `IsActive = true`.
- Atualizar `UpdatedBy` e `UpdatedAt`.

**Validações:**
- A Categoria deve existir e pertencer ao Tenant.
- A Categoria não pode estar deletada.
- **A Categoria não pode estar já ativa** - retorna erro 400 se tentar ativar uma Categoria que já está ativa.
- A operação **não é idempotente** - valida o estado atual e retorna erro se já estiver no estado desejado.

**Motivo da validação explícita:**
- Evita chamadas desnecessárias ao banco de dados quando a Categoria já está ativa.
- Detecta bugs no cliente que fazem chamadas duplicadas.
- Melhora a performance ao fazer "early return" sem validar dependências desnecessariamente.
- Fornece feedback explícito sobre tentativas de operação inválidas.

**Auditoria:**
- Registrar ativação em `AuditLogs`.
- Incluir contexto do usuário que ativou.

---

### 4.6 Desativar Categoria (PATCH /v1/categories/{id}/deactivate)
**Contexto:** Desativar uma Categoria temporariamente.

**Regras:**
- **A Categoria deve estar ativa** (`IsActive = true`) para ser desativada.
- A desativação impede a criação de novas entidades associadas.
- Atualizar `IsActive = false`.
- Atualizar `UpdatedBy` e `UpdatedAt`.

**Validações:**
- A Categoria deve existir, pertencer ao Tenant e estar ativa.
- **A Categoria não pode estar já inativa** - retorna erro 400 se tentar desativar uma Categoria que já está inativa.
- Verificar se existem entidades ativas associadas (Applications, Resources, Actions, Permissions).
- Opcionalmente, impedir desativação se há dependências críticas.
- A operação **não é idempotente** - valida o estado atual e retorna erro se já estiver no estado desejado.

**Motivo da validação explícita:**
- Evita chamadas desnecessárias ao banco de dados e verificação de dependências.
- Detecta bugs no cliente que fazem chamadas duplicadas.
- Melhora a performance ao fazer "early return" sem processar operação desnecessária.
- Fornece feedback explícito sobre tentativas de operação inválidas.

**Impacto:**
- Categorias desativadas impedem a criação de novas entidades associadas.
- Considerar notificação de administradores sobre o impacto.

**Auditoria:**
- Registrar desativação em `AuditLogs` com motivo (se fornecido).

---


### 5.1 Dependência obrigatória
- Aplicações, Recursos, Ações e Permissões devem referenciar uma Categoria válida.

### 5.2 Consistência da Categoria
- Todos os elementos associados devem pertencer à mesma Categoria.

---

## 6. Regras de Governança e Segurança

### 6.1 Auditoria
- Todas as operações devem ser auditadas.

### 6.2 Segurança
- Categorias definem domínios funcionais e de segurança.

---

## 7. Regras Complementares
- Categorias devem ser estáveis ao longo do tempo.
- Mudanças estruturais devem ser tratadas com cautela.

---

## 8. Conclusão
O módulo **Categorias** é um pilar estrutural do IAM VianaID.

As regras aqui definidas garantem organização, governança, segurança e consistência entre os domínios do sistema.