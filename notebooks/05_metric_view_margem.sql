-- Databricks notebook source
-- MAGIC %md
-- MAGIC ![DB Academy](./Includes/images/db-academy.png)

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC # Hospital Data Matter — Sessão 05: Metric View (métricas de negócio governadas)
-- MAGIC
-- MAGIC ## A. Objetivo
-- MAGIC Ao final desta sessão você saberá:
-- MAGIC - o que é uma **Metric View** do Unity Catalog e por que ela existe;
-- MAGIC - a diferença entre **dimensões** (por onde eu corto) e **medidas** (o que eu calculo);
-- MAGIC - criar uma Metric View com `CREATE VIEW ... WITH METRICS LANGUAGE YAML`;
-- MAGIC - consultar métricas com `MEASURE()` e `GROUP BY ALL`.
-- MAGIC
-- MAGIC ## B. Contexto de negócio
-- MAGIC Na Sessão 03, a margem % foi calculada como `soma das margens / soma das receitas líquidas`.
-- MAGIC Agora imagine três analistas escrevendo essa conta cada um do seu jeito:
-- MAGIC
-- MAGIC <div style="max-width: 1000px; margin: 0 auto;">
-- MAGIC <table style="width: 100%; border-collapse: collapse; line-height: 1.6;">
-- MAGIC   <tr style="background: #1B3139; color: #fff;"><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Analista</th><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Fórmula usada</th><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Resultado</th></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">A</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>sum(margem) / sum(receita_liquida)</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">correto</td></tr>
-- MAGIC   <tr style="background: #fff;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">B</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>avg(margem_pct)</code> (média de percentuais)</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">errado</td></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">C</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>sum(margem) / sum(receita_bruta)</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">outra métrica com o mesmo nome</td></tr>
-- MAGIC </table>
-- MAGIC </div>
-- MAGIC
-- MAGIC No fim, a diretoria recebe três "margens" diferentes. A **Metric View** resolve isso: a fórmula
-- MAGIC é definida **uma única vez**, no Unity Catalog, e todos (SQL, dashboards e Genie) passam a usar a mesma definição.

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC ## OBRIGATÓRIO - SELECIONE A COMPUTAÇÃO
-- MAGIC
-- MAGIC <div style="border-left: 4px solid #f44336; background: #ffebee; padding: 14px 18px; border-radius: 4px; margin: 16px 0;">
-- MAGIC   <strong style="display:block; color:#c62828; margin-bottom:6px; font-size: 1.1em;">Selecione um SQL Warehouse Serverless ou a computação Serverless</strong>
-- MAGIC   <div style="color:#333;">
-- MAGIC     Antes de executar este notebook, clique em <strong>Connect</strong> (canto superior direito) e escolha um <strong>SQL Warehouse Serverless</strong> ou a computação <strong>Serverless</strong>.<br/><br/>
-- MAGIC     <strong>OBSERVAÇÃO:</strong> este notebook foi <strong>desenvolvido e testado em computação Serverless</strong>. Outras opções de computação podem funcionar, mas não há garantia de que se comportem da mesma forma.
-- MAGIC   </div>
-- MAGIC </div>
-- MAGIC
-- MAGIC <div style="border-left: 4px solid #d97706; background: #fffbeb; padding: 14px 18px; border-radius: 4px; margin: 16px 0;">
-- MAGIC   <strong style="display:block; color:#92400e; margin-bottom:6px; font-size: 1.1em;">Pré-requisito</strong>
-- MAGIC   <div style="color:#333;">
-- MAGIC     Execute antes os notebooks <code>01</code> a <code>03</code> (tabela <code>gold.fato_margem_hospitalar</code>).
-- MAGIC   </div>
-- MAGIC </div>

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## C. Implementação em SQL
-- MAGIC ### Passo 1 — O problema: duas margens diferentes para a mesma pergunta

-- COMMAND ----------

-- Mesma pergunta ("qual a margem % por período?"), duas fórmulas, dois resultados.
SELECT
    periodo,
    round(sum(margem) / sum(receita_liquida) * 100, 2)  AS margem_pct_correta,      -- soma / soma
    round(avg(margem_pct) * 100, 2)                      AS margem_pct_media_errada  -- média de percentuais
FROM hospital_margin_demo.gold.fato_margem_hospitalar
GROUP BY periodo
ORDER BY periodo;

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC ### Passo 2 — Criando a Metric View
-- MAGIC Uma Metric View tem três partes, escritas em **YAML** (um formato de texto com indentação):
-- MAGIC
-- MAGIC <div style="max-width: 1000px; margin: 0 auto;">
-- MAGIC <table style="width: 100%; border-collapse: collapse; line-height: 1.6;">
-- MAGIC   <tr style="background: #1B3139; color: #fff;"><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Parte</th><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">O que é</th><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Exemplo</th></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>source</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">a tabela de origem</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>gold.fato_margem_hospitalar</code></td></tr>
-- MAGIC   <tr style="background: #fff;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>dimensions</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">colunas usadas para <strong>agrupar e filtrar</strong></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">mês, unidade, operadora</td></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>measures</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><strong>fórmulas de agregação</strong></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>SUM(receita_bruta)</code>, margem %</td></tr>
-- MAGIC </table>
-- MAGIC </div>
-- MAGIC
-- MAGIC Por que usar a tabela `fato_margem_hospitalar` como origem? Porque ela já tem **uma linha por internação**:
-- MAGIC não há risco de duplicação (fanout) ao somar.
-- MAGIC
-- MAGIC Repare nas medidas de percentual: elas são escritas como `MEASURE(margem) / MEASURE(receita_liquida)`, ou seja,
-- MAGIC reutilizam outras medidas. Assim a margem % é **sempre soma / soma**, em qualquer agrupamento.
-- MAGIC
-- MAGIC <div style="border-left: 4px solid #1976d2; background: #f0f7ff; padding: 14px 18px; border-radius: 4px; margin: 16px 0;">
-- MAGIC   <strong style="display:block; color:#0d47a1; margin-bottom:6px; font-size: 1.1em;">Observação</strong>
-- MAGIC   <div style="color:#333;">
-- MAGIC     <p style="margin: 6px 0;">Atenção ao YAML: a indentação (espaços) importa, e expressões com <code>:</code> ou <code>'</code> ficam entre aspas duplas.</p>
-- MAGIC   </div>
-- MAGIC </div>

-- COMMAND ----------

CREATE OR REPLACE VIEW hospital_margin_demo.gold.mv_margem_hospitalar
WITH METRICS
LANGUAGE YAML
AS $$
version: 1.1
comment: "Métricas oficiais de receita, glosa, custo e margem do Hospital Data Matter (1 linha de origem = 1 internação)."
source: hospital_margin_demo.gold.fato_margem_hospitalar

# DIMENSÕES: por onde o usuário pode agrupar e filtrar
dimensions:
  - name: mes_competencia
    expr: mes_competencia
    comment: "Mês da admissão do paciente"
  - name: periodo
    expr: periodo
    comment: "Base (nov/25-jul/26) ou Deterioração (ago-out/26)"
  - name: unidade
    expr: unidade
    comment: "Unidade hospitalar"
  - name: operadora
    expr: operadora
    comment: "Operadora de saúde (convênio)"
    synonyms: ["convênio", "plano de saúde", "pagador"]
  - name: procedimento
    expr: procedimento
  - name: complexidade
    expr: complexidade
    comment: "BAIXA, MEDIA ou ALTA"

# MEDIDAS: fórmulas definidas uma única vez
measures:
  # Medidas básicas (somas e contagens)
  - name: internacoes
    expr: COUNT(1)
    comment: "Quantidade de internações"
  - name: receita_bruta
    expr: SUM(receita_bruta)
    comment: "Soma dos itens faturados (R$)"
    synonyms: ["faturamento", "receita"]
  - name: glosas
    expr: SUM(glosas)
    comment: "Valor recusado pelas operadoras (R$)"
  - name: receita_liquida
    expr: SUM(receita_liquida)
    comment: "Receita bruta - glosas (R$)"
  - name: custos
    expr: SUM(custos)
    comment: "Custo assistencial (R$)"
  - name: margem
    expr: SUM(margem)
    comment: "Margem de contribuição = receita líquida - custos (R$)"
  - name: dias_internados
    expr: SUM(permanencia_dias)
    comment: "Total de pacientes-dia"

  # Medidas compostas: reutilizam as medidas básicas com MEASURE()
  - name: margem_pct
    expr: try_divide(MEASURE(margem), MEASURE(receita_liquida))
    comment: "Margem % = margem / receita líquida (sempre soma / soma)"
    synonyms: ["margem percentual", "rentabilidade"]
  - name: taxa_glosa
    expr: try_divide(MEASURE(glosas), MEASURE(receita_bruta))
    comment: "Taxa de glosa = glosas / receita bruta"
  - name: permanencia_media
    expr: try_divide(MEASURE(dias_internados), MEASURE(internacoes))
    comment: "Permanência média em dias"
  - name: pct_alta_complexidade
    expr: try_divide(COUNT(1) FILTER (WHERE complexidade = 'ALTA'), COUNT(1))
    comment: "Participação das internações de alta complexidade"
$$;

-- COMMAND ----------

-- A Metric View aparece no Catalog Explorer como uma view. Veja a definição registrada:
DESCRIBE TABLE EXTENDED hospital_margin_demo.gold.mv_margem_hospitalar;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Passo 3 — Consultando a Metric View
-- MAGIC Regras de consulta:
-- MAGIC - medidas são lidas com `MEASURE(nome_da_medida)`;
-- MAGIC - use `GROUP BY ALL` (agrupa por todas as dimensões do `SELECT`);
-- MAGIC - filtre **dimensões** no `WHERE` normalmente.
-- MAGIC
-- MAGIC Repare: **nenhuma fórmula é reescrita**. Só escolhemos as dimensões.

-- COMMAND ----------

-- Margem por período: o resultado é igual ao "correto" do Passo 1
SELECT
    periodo,
    MEASURE(receita_bruta)                    AS receita_bruta,
    MEASURE(margem)                           AS margem,
    round(MEASURE(margem_pct) * 100, 2)       AS margem_pct
FROM hospital_margin_demo.gold.mv_margem_hospitalar
GROUP BY ALL
ORDER BY periodo;

-- COMMAND ----------

-- As MESMAS medidas, agora por operadora e período (Anomalia 1: glosas)
SELECT
    operadora,
    periodo,
    round(MEASURE(taxa_glosa) * 100, 1)   AS taxa_glosa_pct,
    round(MEASURE(margem_pct) * 100, 1)   AS margem_pct
FROM hospital_margin_demo.gold.mv_margem_hospitalar
GROUP BY ALL
ORDER BY periodo DESC, taxa_glosa_pct DESC;

-- COMMAND ----------

-- Agora por unidade e complexidade, com filtro de período (Anomalia 2: permanência)
SELECT
    unidade,
    complexidade,
    round(MEASURE(permanencia_media), 1)  AS permanencia_media,
    round(MEASURE(margem_pct) * 100, 1)   AS margem_pct
FROM hospital_margin_demo.gold.mv_margem_hospitalar
WHERE periodo LIKE 'Deterioração%'          -- filtro em dimensão: permitido no WHERE
GROUP BY ALL
ORDER BY permanencia_media DESC;

-- COMMAND ----------

-- Tendência mensal (Anomalia 3: mix): receita sobe, margem % cai, alta complexidade cresce
SELECT
    mes_competencia,
    MEASURE(receita_bruta)                         AS receita_bruta,
    round(MEASURE(margem_pct) * 100, 1)            AS margem_pct,
    round(MEASURE(pct_alta_complexidade) * 100, 1) AS pct_alta_complexidade
FROM hospital_margin_demo.gold.mv_margem_hospitalar
GROUP BY ALL
ORDER BY mes_competencia;

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC <div style="border-left: 4px solid #2e7d32; background: #f7fdf4; padding: 14px 18px; border-radius: 4px; margin: 16px 0;">
-- MAGIC   <strong style="display:block; color:#1b5e20; margin-bottom:6px; font-size: 1.1em;">O que observar</strong>
-- MAGIC   <div style="color:#333;">
-- MAGIC     <p style="margin: 6px 0;">Com uma única definição de margem, cortamos os dados por período, operadora, unidade e mês sem reescrever a fórmula. Essa mesma Metric View pode ser usada por um <strong>dashboard AI/BI</strong> ou por um <strong>Genie</strong>: os <code>comment</code> e <code>synonyms</code> do YAML ajudam o Genie a entender perguntas como <em>"qual convênio tem mais glosa?"</em>.</p>
-- MAGIC   </div>
-- MAGIC </div>

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## D. Validação
-- MAGIC A Metric View precisa dar **exatamente** os mesmos números das tabelas Gold da Sessão 03.

-- COMMAND ----------

-- 1) Mês a mês: Metric View x resumo_financeiro_mensal. Esperado: 0 meses com diferença.
WITH metric_view AS (
    SELECT
        mes_competencia,
        MEASURE(receita_bruta) AS receita_bruta,
        MEASURE(margem)        AS margem
    FROM hospital_margin_demo.gold.mv_margem_hospitalar
    GROUP BY ALL
)
SELECT count(*) AS meses_com_diferenca
FROM metric_view AS mv
JOIN hospital_margin_demo.gold.resumo_financeiro_mensal AS r
  ON r.mes_competencia = mv.mes_competencia
WHERE mv.receita_bruta <> r.receita_bruta
   OR mv.margem        <> r.margem;

-- COMMAND ----------

-- 2) Por operadora: taxa de glosa da Metric View x resumo_operadoras. Esperado: 0 linhas com diferença.
WITH metric_view AS (
    SELECT
        operadora,
        periodo,
        round(MEASURE(taxa_glosa), 4) AS taxa_glosa
    FROM hospital_margin_demo.gold.mv_margem_hospitalar
    GROUP BY ALL
)
SELECT count(*) AS linhas_com_diferenca
FROM metric_view AS mv
JOIN hospital_margin_demo.gold.resumo_operadoras AS r
  ON r.operadora = mv.operadora AND r.periodo = mv.periodo
WHERE mv.taxa_glosa <> r.taxa_glosa;
