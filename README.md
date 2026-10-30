# Hospital Data Matter — Sessões de SQL no Databricks

Demonstração didática, 100% em **Databricks SQL**, de como Delta Lake, Unity Catalog e a
arquitetura Medallion (Bronze → Silver → Gold) ajudam a responder a uma pergunta real de gestão hospitalar:

> **Por que a receita do hospital sobe enquanto a margem de contribuição cai?**

Todos os dados são **sintéticos**: nomes, e-mails e demais dados de pacientes são gerados pelo código, sem pessoas reais e sem CPFs. O cadastro de pacientes é o único com dados pessoais (veja [Dados pessoais](#dados-pessoais-pacientes)).

```text
BRONZE (dados brutos dos sistemas, incluindo pacientes)
   |  SQL: CAST, WHERE, COALESCE, padronização de textos
   v
SILVER (dados limpos; última camada com dados pessoais)
   |  SQL: GROUP BY antes do JOIN, receita, glosas, custos, margem
   v
GOLD (tabelas de negócio, sem dados pessoais)
   |
   v
ANÁLISES FINANCEIRAS E CLÍNICAS (notebook 04)
   |
   v
METRIC VIEW: métricas oficiais governadas no Unity Catalog (notebook 05)
   |
   v
PAGES: significado de negócio de cada métrica, ligado aos ativos com @ (notebook 06, manual)
   |
   v
CERTIFICAÇÃO E DOMÍNIOS: selo "certified" nas Gold e na Metric View, "deprecated" na view legada, tags de subdomínio (notebook 07)
   |
   v
GENIE AGENT: "Recuperação de Margem" sobre a Metric View certificada (notebook 08, manual na interface)
```

## Como executar

1. Importe a pasta `notebooks/` no workspace (por exemplo, em `/Workspace/Users/<seu-usuario>/hospital_data_matter/`),
   **incluindo a subpasta `Includes/`**. Veja [Padrão visual](#padrão-visual).
2. Conecte cada notebook a um **SQL Warehouse** ou à computação **serverless**.
3. Execute **em ordem**, do início ao fim (*Run all*):

| Ordem | Notebook | O que faz | Tempo aproximado |
|---|---|---|---|
| 1 | `01_bronze_dados_sinteticos` | Cria o catálogo e os schemas e gera as 5 tabelas Bronze (inclui `pacientes`) | ~1 min |
| 2 | `02_silver_limpeza` | Limpa e padroniza os dados, formando as 5 tabelas Silver | ~1 min |
| 3 | `03_gold_analitico` | Calcula a margem por internação e os resumos (3 tabelas Gold) | ~1 min |
| 4 | `04_validacao_perguntas_negocio` | Reconciliação financeira e respostas às 5 perguntas de negócio | ~1 min |
| 5 | `05_metric_view_margem` | Cria a Metric View `gold.mv_margem_hospitalar` (métricas oficiais em YAML) e a consulta com `MEASURE()` | ~1 min |
| 6 | `06_conteudo_pages` | Roteiro manual com o conteúdo de 5 Pages (Catalog Explorer → Discover → Pages) + SQL que confere cada número citado | ~1 min |
| 7 | `07_certificacao_dominios` | Certifica as 3 tabelas Gold e a Metric View, marca a view legada `gold.vw_margem_mensal_legado` como `deprecated` e associa os ativos aos subdomínios (o Passo 1 cria os domínios na interface, ver abaixo) | ~1 min |
| 8 | `08_genie_agent_recuperacao_margem` | Roteiro **manual** (UI-guided): o Agent é criado em **Genie → New**; as células SQL só conferem fontes, joins, expressões e benchmarks (somente leitura) | ~1 min (a configuração na interface leva mais) |

Todos os notebooks podem ser reexecutados: usam `CREATE OR REPLACE TABLE` e geram sempre os mesmos dados.
As tabelas mantêm as tags quando os notebooks 01 a 03 são reexecutados (`CREATE OR REPLACE TABLE` preserva as tags), mas a Metric View **perde** as tags quando o notebook 05 a recria com `CREATE OR REPLACE VIEW`: depois de rodar o 05, rode o 07 de novo (testado em 29/10/2026).

**Volume:** as sessões usam 10.000 internações. Para 100.000, troque `range(1, 10001)` por `range(1, 100001)`
no notebook 01 (testado: todas as validações continuam `OK`). O cadastro de pacientes não muda com o volume: são sempre 8.000.

**Catálogo:** `hospital_margin_demo`. Se você não puder criar catálogos, troque esse nome nos 8 notebooks
(buscar e substituir) por um catálogo onde tenha permissão.

## As três anomalias sintéticas (gabarito)

A partir de **agosto/2026** o gerador do notebook 01 altera os eventos de origem. Os KPIs finais nunca são alterados diretamente:

| # | Anomalia | Regra no notebook 01 | Como aparece na Gold |
|---|---|---|---|
| 1 | Glosas de OPME | Aurora Seguros recusa 60% dos itens de OPME integralmente ("Falta de autorização prévia de OPME") | taxa de glosa da Aurora sobe de ~4% para ~14% |
| 2 | Permanência maior | Unidade Sul + alta complexidade = +6 dias; operadora paga no máximo 10 diárias | permanência Sul/ALTA sobe de ~7 para ~13 dias; custo sem receita |
| 3 | Mix mais caro | fatia de alta complexidade sobe de 15% para 22% das internações | receita sobe, margem % cai |

## Resultados medidos (10.000 internações)

Execução de 29/10/2026 em um workspace Databricks na AWS (us-east-2), com computação serverless:

| Indicador (média mensal) | Base (nov/25–jul/26) | Deterioração (ago–out/26) |
|---|---|---|
| Receita bruta | R$ 14,66 mi | R$ 20,10 mi |
| Receita líquida | R$ 14,04 mi | R$ 18,74 mi |
| Custos | R$ 10,89 mi | R$ 15,56 mi |
| Margem de contribuição | R$ 3,15 mi | R$ 3,17 mi |
| **Margem %** | **22,4%** | **16,9%** |
| Taxa de glosa (rede) | 4,2% | 6,8% |
| Permanência média | 4,1 dias | 4,7 dias |
| % alta complexidade | 14,3% | 23,0% |

Reconciliação: Gold = Silver ao centavo em internações, receita bruta, glosas e custos, com 0 erros de fórmula.

Com 100.000 internações: receita bruta de R$ 150,1 mi → R$ 191,6 mi/mês; margem de 22,4% → 17,6%; glosa da Aurora em 13,6%.

## Dados pessoais (pacientes)

A tabela `pacientes` (8.000 pacientes sintéticos) existe na Bronze e na Silver, com `paciente_id`, `nome`, `email`,
`sexo`, `data_nascimento` e `cidade`. Nomes combinam nomes comuns brasileiros com dois sobrenomes, sorteados por hash.
E-mails seguem o formato `nome.sobrenome<número>@example.com`: `example.com` é um domínio reservado e não pertence a ninguém.

- **Problemas de qualidade propositais na Bronze:** 5% dos nomes em MAIÚSCULAS com espaço no final e 5% dos e-mails em MAIÚSCULAS.
  A Silver corrige com `initcap(trim(nome))` e `lower(trim(email))`.
- **Minimização de dados:** os dados pessoais param na Silver. As tabelas Gold, a Metric View e o Genie não têm nome,
  e-mail, data de nascimento nem cidade. `silver.internacoes` só aceita `paciente_id` que existe em `silver.pacientes`.
- **Parto normal:** só é atribuído a pacientes do sexo feminino nascidas entre 1984 e 2003.
- **Sem mascaramento por enquanto:** `silver.pacientes` ainda não tem tags de governança nem máscara. Isso fica para um notebook futuro.

## Metric View (notebook 05)

`gold.mv_margem_hospitalar` define **uma única vez** as fórmulas de negócio (receita, glosa, custo, margem, margem %,
taxa de glosa, permanência média, % alta complexidade) sobre `gold.fato_margem_hospitalar`. Qualquer consulta,
dashboard ou Genie usa a mesma definição:

```sql
SELECT periodo, MEASURE(margem_pct) AS margem_pct
FROM hospital_margin_demo.gold.mv_margem_hospitalar
GROUP BY ALL;
```

Validação: a Metric View reproduz exatamente `resumo_financeiro_mensal` (12 de 12 meses) e `resumo_operadoras` (10 de 10 linhas).
O notebook também mostra o erro clássico da média de percentuais: 25,95% em vez dos 22,43% corretos no período base.

## Pages (notebook 06)

O notebook 06 não cria objetos: ele traz o texto pronto (Domínio, Nome, Responsável, Sinônimos, Descrição, Corpo e
Ativos relacionados) de 5 Pages para colar em **Catalog Explorer → Discover → Pages**:
Margem de Contribuição, Taxa de Glosa, Taxa de Glosa de OPME (métrica no nível de item, fora da Metric View),
Permanência Média e Guia: Análise de Margem Hospitalar (página de entrada). Cada Page tem uma célula SQL
que confere os números citados antes da publicação.

Em **Domínio**, use `Hospital Data Matter` com o subdomínio `Financeiro` ou `Operações Assistenciais`. Esses domínios
são criados na interface no Passo 1 da Sessão 07: crie-os antes de publicar as Pages.

## Certificação, domínios e obsolescência (notebook 07)

O notebook 07 organiza o catálogo sem alterar dados das tabelas:

- **Domínios:** o domínio pai e os dois subdomínios são criados na interface, em **Catalog Explorer → Discover → Domains**
  (Passo 1). Cada um vira uma tag só com chave, aplicada com `SET TAG ON TABLE|VIEW ... \`<chave>\``:

  | Nível | Nome no Catalog Explorer | Chave da tag |
  |---|---|---|
  | Domínio | Hospital Data Matter | `Hospital Data Matter` |
  | Subdomínio | Financeiro | `Hospital Data Matter/Financeiro` |
  | Subdomínio | Operações Assistenciais | `Hospital Data Matter/Operações Assistenciais` |

- **Certificação:** `ALTER ... SET TAGS ('system.certification_status' = 'certified')` nas 3 tabelas Gold e na
  Metric View (`ALTER VIEW`). Aparece como selo **Certified** no Catalog Explorer.
- **Obsolescência:** a view `gold.vw_margem_mensal_legado` calcula a margem % como média de percentuais (o erro da Sessão 05).
  Em vez de apagá-la, o notebook a marca como `deprecated`, e o comentário aponta para `gold.mv_margem_hospitalar`.
  Aparece como selo **Deprecated**.

A tag de certificação aceita só `certified` e `deprecated`. Outro valor, como `'obsoleto'`, falha com
`UC_TAG_POLICY_VALUE_NOT_ALLOWED`. O ciclo de vida de um ativo é: sem selo → `certified` → `deprecated`.

Regra: a **Bronze** nunca é certificada nem recebe subdomínio; a **Silver** recebe subdomínio, mas não selo; a **Gold** e a
Metric View recebem selo e subdomínio; a view obsoleta recebe `deprecated` e o subdomínio Financeiro.
O mapeamento completo está no [DICIONARIO_DE_DADOS.md](DICIONARIO_DE_DADOS.md#tags-de-governança).

**Validação esperada:** 4 ativos `certified`, 1 `deprecated`, 11 tags de subdomínio e 0 tags na Bronze.
Sem os domínios criados, a tag é gravada, mas o ativo não aparece agrupado no Discover.

## Genie Agent (notebook 08)

O notebook 08 é um **roteiro manual**, como o 06: o Agent é criado na interface (**Genie → New**), e as células SQL
só **conferem** cada fonte, join, expressão, exemplo e resposta esperada antes de você colar (somente leitura).
Ele requer as Sessões 01 a 07.

O Agent **Hospital Data Matter — Recuperação de Margem** responde à controladoria e ao faturamento: *"quanto estamos perdendo, onde, e quanto dá para recuperar?"*.
Ele não substitui o Genie One: é curado para um público e um problema, com instruções, exemplos e benchmarks próprios.

- **Tamanho do problema:** se o período de deterioração mantivesse a margem % da base, a margem perdida seria de cerca de
  R$ 3,1 mi em 3 meses (cerca de R$ 1,03 mi por mês).
- **Fontes:** `gold.mv_margem_hospitalar` (certificada, com as fórmulas oficiais) e, para o que a Metric View não tem
  (glosa por tipo de item e por motivo), `silver.glosas`, `silver.faturamento` e `silver.internacoes`.
  Ficam de fora: a Bronze, `gold.vw_margem_mensal_legado` (obsoleta), `silver.pacientes` (dados pessoais) e
  `gold.fato_margem_hospitalar` (base da Metric View, que faria o Genie refazer a agregação).
- **Configuração:** `paciente_id` escondida; entity matching nas colunas de texto com poucos valores; 3 joins entre as
  tabelas Silver (um para um entre glosas e faturamento); 3 expressões SQL (taxa de glosa de OPME, glosa por falta de
  autorização e filtro do período de deterioração); 3 SQL de exemplo; instruções de texto; 5 perguntas de exemplo.
- **Benchmarks:** B1 a B5, com respostas conferidas em SQL (por exemplo, B1 = 16,9% de margem e B3 = R$ 1.488.000,00 de
  glosa por falta de autorização de OPME).
- **Governança:** compartilhado com a controladoria, marcado como **Certified** e com o domínio
  `Hospital Data Matter › Financeiro`; ligado à Page "Guia: Análise de Margem Hospitalar".

**Achado principal:** recuperar só a glosa por falta de autorização de OPME (R$ 1,49 mi) levaria a margem de 16,9% para
19,1%, cerca de metade da margem perdida.

Os valores de B1 a B5 valem para 10.000 internações (volume padrão deste README).

## Padrão visual

Os notebooks seguem o padrão visual das sessões da Databricks Academy:

- logo `db-academy.png` na primeira célula de cada notebook;
- callouts: vermelho (*Selecione a computação*), âmbar (*Pré-requisito* e *Atenção*), verde (*O que observar* e *Resposta*) e azul (*Observação*);
- tabelas com cabeçalho escuro (`#1B3139`);
- diagrama de arquitetura em Mermaid no notebook 01 (carrega a biblioteca pela internet).

As imagens são referenciadas por caminho relativo (`./Includes/images/db-academy.png`). Por isso a pasta
**`notebooks/Includes/`** precisa estar no workspace ao lado dos notebooks (`Includes/images/db-academy.png` e
`Includes/images/icons/warning-triangle.png`). Ao importar manualmente, **importe também a pasta `Includes`**;
sem ela, o logo não aparece, mas os notebooks executam normalmente.

## Estrutura do repositório

```text
hospital-data-matter/
├── README.md
├── DICIONARIO_DE_DADOS.md
└── notebooks/
    ├── 01_bronze_dados_sinteticos.sql
    ├── 02_silver_limpeza.sql
    ├── 03_gold_analitico.sql
    ├── 04_validacao_perguntas_negocio.sql
    ├── 05_metric_view_margem.sql
    ├── 06_conteudo_pages.sql
    ├── 07_certificacao_dominios.sql
    ├── 08_genie_agent_recuperacao_margem.sql
    └── Includes/
        └── images/
            ├── db-academy.png
            └── icons/
                └── warning-triangle.png
```

Os arquivos `.sql` estão no formato de notebook do Databricks (`-- Databricks notebook source`) e podem ser
importados diretamente ou versionados em um Git folder.
