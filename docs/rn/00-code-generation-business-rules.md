# Documento de Regras de Negócio — Geração de Códigos (Code)

## 1. Introdução
Este documento define de forma **única, centralizada e obrigatória** as regras de negócio relacionadas ao campo **`Code`** em todo o sistema IAM **VianaID**.

O campo `Code` é um **identificador técnico imutável de domínio**, utilizado para rastreabilidade, auditoria, integração entre sistemas e referência humana legível.

Este documento é **referência normativa** para todos os módulos do sistema.

---

## 2. Princípios Gerais

As regras abaixo aplicam-se a **todas as entidades** que possuem o campo `Code`.

1. O campo **`Code` nunca é informado pelo usuário**.
2. O campo **`Code` é imutável** após a criação do registro.
3. O campo **`Code` é gerado exclusivamente pela aplicação**.
4. O campo `Code` **não representa dado de negócio editável**, mas sim um identificador técnico.
5. Qualquer tentativa de envio ou alteração manual do campo `Code` deve ser **ignoradas ou rejeitadas pela API**.

---

## 3. Padrão Global de Formato do Code

O formato do campo `Code` segue obrigatoriamente o padrão:

```
<PREFIXO><YYMMDD><HASH>
```

### 3.1 Descrição dos componentes

- **PREFIXO**
  - 4 caracteres alfabéticos em caixa alta.
  - Identifica o tipo do recurso.
  - É fixo por entidade.

- **YYMMDD**
  - Data UTC de geração do código.
  - `YY` → ano (2 dígitos)
  - `MM` → mês (2 dígitos)
  - `DD` → dia (2 dígitos)

- **HASH**
  - Sequência alfanumérica aleatória de 4 caracteres.
  - Gerada de forma segura para garantir unicidade.

---

## 4. Prefixos Oficiais por Entidade

### 4.1 Entidades de Negócio (Core)

| Entidade | Prefixo | Exemplo | Status |
|----------|---------|---------|--------|
| Planos | PLAN | PLAN251230XTG2 | ✅ Ativo |
| Tenants | TENT | TENT251230A9KQ | ✅ Ativo |
| Categorias | CATE | CATE251230ZP3M | ✅ Ativo |
| Aplicações | APPL | APPL2512307FQ2 | ✅ Ativo |
| Subscriptions | SUBS | SUBS251230K9M4 | ✅ Ativo |
| UserAccounts | USER | USER251230B7N3 | ✅ Ativo |
| Recursos | RESO | RESO251230W2P5 | ✅ Ativo |
| Ações | ACTN | ACTN251230R8T1 | ✅ Ativo |
| Permissões | PERM | PERM251230L3Q6 | ✅ Ativo |

### 4.2 Entidades de Segurança e IAM

| Entidade | Prefixo | Exemplo | Status |
|----------|---------|---------|--------|
| ApplicationRoles | ROLE | ROLE251230M4D8 | ✅ Ativo |
| JwtKeys | JKEY | JKEY251230V9H2 | ✅ Ativo |

### 4.3 Entidades de Sistema

| Entidade | Prefixo | Exemplo | Status |
|----------|---------|---------|--------|
| BackgroundJobs | BJOB | BJOB251230X5C7 | ✅ Ativo |

### 4.4 Entidades sem Code (Exceções Justificadas)

As seguintes entidades **NÃO possuem** campo `Code` por motivos arquiteturais válidos:

| Entidade | Tipo | Justificativa |
|----------|------|---------------|
| RolePermission | Relacional | Tabela N:N entre ApplicationRole e Permission (ambos têm Code) |
| UserApplicationRole | Relacional | Tabela N:N entre User/ServiceAccount e ApplicationRole (ambos têm Code) |
| UserSession | Temporal | Entidade efêmera com RefreshTokenHash único |
| SecurityKey | Legado | ⚠️ Em processo de deprecation (migrar para JwtKey) |
| SecurityAuditLog | Log | Registro de auditoria, não entidade de negócio |
| UserExternalProvider | Técnica | Integração técnica com ExternalId próprio |
| UserMfaConfiguration | Configuração | Subordinada a UserAccount (que possui Code) |

> **Nota**: Para detalhes sobre SecurityKey vs JwtKey, consulte `docs/ANALYSIS_SECURITYKEY_DEPRECATION.md`

> Novos prefixos só podem ser adicionados mediante validação arquitetural e atualização deste documento.

---

## 5. Exemplos de Códigos Válidos

### 5.1 Entidades de Negócio
```
PLAN251214XTG2  ← Plano criado em 14/12/2025
TENT251214A9KQ  ← Tenant criado em 14/12/2025
CATE251214ZP3M  ← Categoria criada em 14/12/2025
APPL2512147FQ2  ← Aplicação criada em 14/12/2025
SUBS251230K9M4  ← Subscription criada em 30/12/2025
USER251230B7N3  ← Usuário criado em 30/12/2025
```

### 5.2 Entidades de Segurança
```
ROLE251230M4D8  ← ApplicationRole criada em 30/12/2025
JKEY251230V9H2  ← Chave JWT criada em 30/12/2025
PERM251230L3Q6  ← Permissão criada em 30/12/2025
```

### 5.3 Entidades de Sistema
```
BJOB251230X5C7  ← Background Job definido em 30/12/2025
```

---

## 6. Implementação Técnica de Referência

A geração do `Code` deve utilizar **exclusivamente** o componente abaixo:

```csharp
public static class CodeGenerator
{
    private static readonly char[] chars =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".ToCharArray();

    public static string Generate(string prefix)
    {
        var date = DateTime.UtcNow.ToString("yyMMdd");
        var random = RandomString(4);
        return $"{prefix.ToUpperInvariant()}{date}{random.ToUpperInvariant()}";
    }

    private static string RandomString(int length)
    {
        var data = new byte[length];
        Random.Shared.NextBytes(data);

        return new string(data.Select(b => chars[b % chars.Length]).ToArray());
    }
}
```

**Localização**: `src/VianaHub.VianaID.Domain/Helpers/CodeGenerator.cs`

---

## 7. Regras de Governança e Auditoria

1. O campo `Code` deve ser:
   - único;
   - indexado;
   - auditável.

2. O `Code` deve ser utilizado em:
   - logs;
   - auditoria;
   - eventos;
   - integrações externas.

3. O `Code` **não deve ser reutilizado**, mesmo em casos de exclusão lógica.

---

## 8. Relação com Outros Documentos

Este documento é referenciado explicitamente por:
- `01-plan-business-rules.md`
- `02-tenant-business-rules.md`
- `03-subscription-business-rules.md`
- `04-category-business-rules.md`
- `05-application-business-rules.md`
- `08-user-accounts-business-rules.md`
- `11-resource-business-rules.md`
- `12-action-business-rules.md`
- `13-permission-business-rules.md`
- `14-application-role-business-rules.md`
- `26-background-job-definition-business-rules.md`
- `27-jwt-key-management-business-rules.md`

**Documentos de Análise:**
- `docs/ANALYSIS_CODE_FIELD_COMPLIANCE.md` - Análise completa de conformidade
- `docs/REFACTORING_SUBSCRIPTION_CODE.md` - Refatoração de Subscription
- `docs/ANALYSIS_SECURITYKEY_DEPRECATION.md` - Análise SecurityKey vs JwtKey

Em caso de conflito, **este documento prevalece**.

---

## 9. Histórico de Alterações

| Data | Versão | Alteração | Autor |
|------|--------|-----------|-------|
| 30/12/2025 | 1.1 | Adição de prefixos ROLE, BJOB, JKEY | Especialista Sênior IAM |
| 30/12/2025 | 1.1 | Documentação de entidades sem Code | Especialista Sênior IAM |
| 30/12/2025 | 1.1 | Reorganização em categorias | Especialista Sênior IAM |
| - | 1.0 | Versão inicial | - |

---

## 10. Conclusão

A padronização do campo **`Code`** garante:
- consistência sistêmica;
- rastreabilidade;
- segurança;
- clareza arquitetural;
- facilidade de integração.

Este documento estabelece o **contrato definitivo** para geração e uso de códigos no IAM VianaID.

**Todas as novas entidades de negócio devem implementar o campo `Code` seguindo este padrão, exceto se houver justificativa arquitetural explícita documentada.**

---

**Status**: ✅ Atualizado em 30/12/2025
