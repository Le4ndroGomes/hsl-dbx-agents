# Dicionário de dados — Hospital Data Matter

Catálogo: `hospital_margin_demo`. Todas as tabelas são Delta gerenciadas pelo Unity Catalog.
Valores monetários em BRL; na Silver e na Gold, em `DECIMAL(18,2)`.

## Bronze — dados brutos

| Tabela | Grão | Colunas |
|---|---|---|
| `bronze.pacientes` | 1 paciente (cadastro) | `paciente_id`, `nome`, `email`, `sexo` (F/M), `data_nascimento`, `cidade`. São 8.000 pacientes **sintéticos** com dados pessoais. 5% dos nomes vêm em MAIÚSCULAS com espaço no final; 5% dos e-mails vêm em MAIÚSCULAS. |
| `bronze.internacoes` | 1 internação | `internacao_id`, `paciente_id` (liga ao cadastro `bronze.pacientes`; 'Parto normal' só para pacientes do sexo feminino nascidas entre 1984 e 2003), `unidade`, `operadora` (com grafias inconsistentes), `procedimento`, `complexidade` (BAIXA/MEDIA/ALTA), `data_admissao`, `data_alta`. Inclui 10 registros de teste inválidos (id ≥ 900001). |
| `bronze.faturamento` | 1 item cobrado | `item_id`, `internacao_id`, `tipo_item` (minúsculas), `quantidade`, `valor_item` (DOUBLE), `data_faturamento`. Inclui 20 lançamentos de teste com valor zero. |
| `bronze.glosas` | 1 item glosado | `glosa_id`, `item_id`, `internacao_id`, `motivo_glosa` (pode ser nulo), `valor_glosa`, `data_glosa` |
| `bronze.custos` | 1 componente de custo | `custo_id`, `internacao_id`, `componente`, `valor_custo` (DOUBLE), `data_custo` |

## Silver — dados limpos

| Tabela | Grão | Diferença em relação à Bronze |
|---|---|---|
| `silver.pacientes` | 1 paciente | `nome` com `initcap(trim())` e `email` com `lower(trim())`, corrigindo os problemas da Bronze; demais colunas sem mudança. **Contém dados pessoais.** |
| `silver.internacoes` | 1 internação válida | operadora padronizada; sem registros de teste; só internações cujo `paciente_id` existe em `silver.pacientes`; novas colunas `permanencia_dias` e `mes_competencia` (mês da admissão) |
| `silver.faturamento` | 1 item válido | `tipo_item` em maiúsculas (DIARIA, PROCEDIMENTO, MATMED, OPME); `valor_item` DECIMAL(18,2); só itens com valor > 0 e internação existente |
| `silver.glosas` | 1 glosa válida | `motivo_glosa` nulo → 'Não informado'; só glosas de itens existentes e com valor ≤ valor do item |
| `silver.custos` | 1 componente válido | `componente` em maiúsculas; `valor_custo` DECIMAL(18,2); só custos de internações existentes |

## Gold — tabelas de negócio

A Gold não tem dados pessoais: nenhuma tabela dela tem nome, e-mail, data de nascimento ou cidade.

### `gold.fato_margem_hospitalar` — 1 linha por internação

| Coluna | Descrição |
|---|---|
| `internacao_id` | Identificador da internação |
| `mes_competencia` | Mês da admissão |
| `periodo` | 'Base (nov/25-jul/26)' ou 'Deterioração (ago-out/26)' |
| `unidade`, `operadora`, `procedimento`, `complexidade` | Atributos da internação |
| `data_admissao`, `data_alta`, `permanencia_dias` | Datas e dias internados |
| `receita_bruta` | Soma dos itens faturados |
| `glosas` | Soma dos valores glosados |
| `receita_liquida` | `receita_bruta - glosas` |
| `custos` | Soma dos componentes de custo |
| `margem` | `receita_liquida - custos` |
| `margem_pct` | `margem / receita_liquida` (`try_divide`) |

### `gold.resumo_financeiro_mensal` — 1 linha por mês

`mes_competencia`, `periodo`, `internacoes`, `receita_bruta`, `glosas`, `receita_liquida`, `custos`, `margem`,
`margem_pct` (soma/soma), `taxa_glosa` (glosas / receita bruta), `permanencia_media`, `pct_alta_complexidade`.

### `gold.resumo_operadoras` — 1 linha por operadora e período

`operadora`, `periodo`, `internacoes`, `receita_bruta`, `glosas`, `receita_liquida`, `margem`, `taxa_glosa`, `margem_pct`.

### `gold.vw_margem_mensal_legado` — 1 linha por mês (OBSOLETA)

`mes_competencia`, `margem_pct_media` (`avg(margem_pct)` sobre `gold.fato_margem_hospitalar`).

**OBSOLETA: não use.** Calcula a margem % como **média de percentuais**, o erro da Sessão 05. Fonte oficial: `gold.mv_margem_hospitalar` (medida `margem_pct`).
Criada pelo notebook 07 para demonstrar o erro, marcada como `deprecated` e mantida para não quebrar quem ainda depende dela.

## Regras importantes

- **Agregar antes de juntar:** faturamento, glosas e custos são somados por `internacao_id` separadamente antes do JOIN, para evitar duplicação (*fanout*).
- **Percentuais = soma / soma**, nunca média de percentuais (única exceção: a view obsoleta `vw_margem_mensal_legado`, mantida como exemplo do erro).
- **Limite contratual:** a operadora paga no máximo 10 diárias por internação; o custo da diária é contado em todos os dias.
- **Datas:** admissões de 01/11/2025 a 31/10/2026; altas podem cair depois de 31/10/2026; competência = mês da admissão.

## Metric View — `gold.mv_margem_hospitalar`

Origem: `gold.fato_margem_hospitalar` (1 linha por internação, sem risco de fanout). Consultar com `MEASURE(<medida>)` + `GROUP BY ALL`.

| Tipo | Nome | Definição |
|---|---|---|
| Dimensão | `mes_competencia`, `periodo`, `unidade`, `operadora`, `procedimento`, `complexidade` | colunas da tabela de origem |
| Medida | `internacoes` | `COUNT(1)` |
| Medida | `receita_bruta`, `glosas`, `receita_liquida`, `custos`, `margem` | `SUM` da coluna de mesmo nome |
| Medida | `dias_internados` | `SUM(permanencia_dias)` |
| Medida | `margem_pct` | `MEASURE(margem) / MEASURE(receita_liquida)` |
| Medida | `taxa_glosa` | `MEASURE(glosas) / MEASURE(receita_bruta)` |
| Medida | `permanencia_media` | `MEASURE(dias_internados) / MEASURE(internacoes)` |
| Medida | `pct_alta_complexidade` | `COUNT(1) FILTER (WHERE complexidade = 'ALTA') / COUNT(1)` |

As divisões usam `try_divide` (resultado NULL em vez de erro quando o denominador é zero).

## Tags de governança

Aplicadas pelo notebook 07.

- **Certificação:** tag de sistema `system.certification_status`, com valores `certified` ou `deprecated` (outro valor é recusado).
- **Domínios:** hierárquicos. O domínio `Hospital Data Matter` tem os subdomínios `Financeiro` e `Operações Assistenciais`.
  Cada subdomínio é uma tag só com chave (valor vazio), no formato `Hospital Data Matter/<subdomínio>`. Os domínios são criados
  na interface em **Catalog Explorer → Discover → Domains** antes de rodar os comandos `SET TAG`.

| Ativo | Tipo | Certificação (`system.certification_status`) | Tags de subdomínio |
|---|---|---|---|
| `bronze.pacientes`, `bronze.internacoes`, `bronze.faturamento`, `bronze.glosas`, `bronze.custos` | Tabela | nenhuma | nenhuma |
| `silver.pacientes` | Tabela | nenhuma | nenhuma (sem tags de governança ainda) |
| `silver.internacoes` | Tabela | nenhuma | `Hospital Data Matter/Operações Assistenciais` |
| `silver.faturamento`, `silver.glosas`, `silver.custos` | Tabela | nenhuma | `Hospital Data Matter/Financeiro` |
| `gold.fato_margem_hospitalar` | Tabela | `certified` | `Hospital Data Matter/Financeiro`, `Hospital Data Matter/Operações Assistenciais` |
| `gold.resumo_financeiro_mensal`, `gold.resumo_operadoras` | Tabela | `certified` | `Hospital Data Matter/Financeiro` |
| `gold.mv_margem_hospitalar` | Metric View (VIEW) | `certified` | `Hospital Data Matter/Financeiro`, `Hospital Data Matter/Operações Assistenciais` |
| `gold.vw_margem_mensal_legado` | View (OBSOLETA) | `deprecated` | `Hospital Data Matter/Financeiro` |

A Bronze nunca é certificada nem recebe subdomínio. Certificação e subdomínio são independentes: um ativo pode ter um sem o outro.
Validação esperada: 4 `certified`, 1 `deprecated`, 11 tags de subdomínio, 0 tags na Bronze.

`silver.pacientes` ainda não tem nenhuma tag de governança nem mascaramento de dados pessoais. Isso será tratado em um notebook futuro.
