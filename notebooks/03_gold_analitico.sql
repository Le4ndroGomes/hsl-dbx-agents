-- Databricks notebook source
-- MAGIC %md
-- MAGIC ![DB Academy](./Includes/images/db-academy.png)

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC # Hospital Data Matter — Sessão 03: Camada Gold (margem por internação)
-- MAGIC
-- MAGIC ## A. Objetivo
-- MAGIC Ao final desta sessão você saberá:
-- MAGIC - consolidar dados com `GROUP BY` e `SUM`;
-- MAGIC - organizar uma consulta em etapas com **CTEs** (`WITH ...`);
-- MAGIC - juntar tabelas de negócio **sem duplicar valores**;
-- MAGIC - calcular receita líquida e **margem de contribuição**.
-- MAGIC
-- MAGIC ## B. Contexto de negócio
-- MAGIC A diretoria quer saber, para cada internação, quanto o hospital faturou, quanto perdeu em glosas
-- MAGIC e quanto gastou. As fórmulas são:
-- MAGIC
-- MAGIC ```
-- MAGIC receita_liquida = receita_bruta - glosas
-- MAGIC margem          = receita_liquida - custos
-- MAGIC margem_pct      = margem / receita_liquida
-- MAGIC ```
-- MAGIC
-- MAGIC Vamos criar três tabelas Gold:
-- MAGIC
-- MAGIC <div style="max-width: 1000px; margin: 0 auto;">
-- MAGIC <table style="width: 100%; border-collapse: collapse; line-height: 1.6;">
-- MAGIC   <tr style="background: #1B3139; color: #fff;"><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Tabela</th><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Grão (1 linha = ...)</th><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Para que serve</th></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>fato_margem_hospitalar</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">uma internação</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">análises detalhadas (unidade, operadora, procedimento)</td></tr>
-- MAGIC   <tr style="background: #fff;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>resumo_financeiro_mensal</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">um mês</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">painel da diretoria</td></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>resumo_operadoras</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">uma operadora em um período</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">negociação com operadoras</td></tr>
-- MAGIC </table>
-- MAGIC </div>

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
-- MAGIC     Execute antes os notebooks <code>01</code> e <code>02</code>.
-- MAGIC   </div>
-- MAGIC </div>

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## C. Implementação em SQL
-- MAGIC ### Passo 1 — Por que agregar ANTES de juntar?
-- MAGIC Uma internação tem **vários** itens de faturamento e **vários** componentes de custo.
-- MAGIC Se juntarmos as duas tabelas linha a linha, cada item se repete para cada custo (efeito *fanout*)
-- MAGIC e a receita fica multiplicada. Veja com a internação 1:

-- COMMAND ----------

-- ERRADO (só para demonstração): juntar itens e custos diretamente multiplica a receita.
SELECT
    'ERRADO: join antes de agregar' AS abordagem,
    sum(f.valor_item)                AS receita_bruta
FROM hospital_margin_demo.silver.faturamento AS f
JOIN hospital_margin_demo.silver.custos      AS c
  ON c.internacao_id = f.internacao_id
WHERE f.internacao_id = 1

UNION ALL

-- CERTO: somar o faturamento sozinho.
SELECT
    'CERTO: agregar antes de juntar',
    sum(valor_item)
FROM hospital_margin_demo.silver.faturamento
WHERE internacao_id = 1;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Passo 2 — Tabela `fato_margem_hospitalar`
-- MAGIC Cada CTE soma uma tabela **separadamente**, chegando a 1 linha por internação.
-- MAGIC Só depois juntamos tudo à tabela de internações. `COALESCE(..., 0)` cobre as internações sem glosa.
-- MAGIC
-- MAGIC Repare também no que **não** entra: nome e e-mail do paciente ficam na Silver (`silver.pacientes`). A Gold não precisa de dados pessoais para calcular margem, glosa e permanência.

-- COMMAND ----------

CREATE OR REPLACE TABLE hospital_margin_demo.gold.fato_margem_hospitalar
COMMENT 'Gold | 1 linha por internação com receita, glosas, custos e margem de contribuição (BRL).'
AS
WITH faturamento_por_internacao AS (
    SELECT internacao_id, sum(valor_item) AS receita_bruta
    FROM hospital_margin_demo.silver.faturamento
    GROUP BY internacao_id
),
glosas_por_internacao AS (
    SELECT internacao_id, sum(valor_glosa) AS glosas
    FROM hospital_margin_demo.silver.glosas
    GROUP BY internacao_id
),
custos_por_internacao AS (
    SELECT internacao_id, sum(valor_custo) AS custos
    FROM hospital_margin_demo.silver.custos
    GROUP BY internacao_id
),
consolidado AS (
    -- Agora cada CTE tem no máximo 1 linha por internação: o join não duplica nada.
    SELECT
        i.internacao_id,
        i.mes_competencia,
        CASE WHEN i.mes_competencia >= DATE'2026-08-01' THEN 'Deterioração (ago-out/26)'
             ELSE 'Base (nov/25-jul/26)'
        END                                AS periodo,
        i.unidade,
        i.operadora,
        i.procedimento,
        i.complexidade,
        i.data_admissao,
        i.data_alta,
        i.permanencia_dias,
        COALESCE(f.receita_bruta, 0)       AS receita_bruta,
        COALESCE(g.glosas, 0)              AS glosas,
        COALESCE(c.custos, 0)              AS custos
    FROM hospital_margin_demo.silver.internacoes AS i
    LEFT JOIN faturamento_por_internacao AS f ON f.internacao_id = i.internacao_id
    LEFT JOIN glosas_por_internacao      AS g ON g.internacao_id = i.internacao_id
    LEFT JOIN custos_por_internacao      AS c ON c.internacao_id = i.internacao_id
)
SELECT
    *,
    receita_bruta - glosas                                    AS receita_liquida,
    receita_bruta - glosas - custos                           AS margem,
    -- try_divide devolve NULL em vez de erro se a receita líquida for zero
    round(try_divide(receita_bruta - glosas - custos, receita_bruta - glosas), 4) AS margem_pct
FROM consolidado;

-- COMMAND ----------

SELECT internacao_id, unidade, operadora, procedimento, permanencia_dias,
       receita_bruta, glosas, receita_liquida, custos, margem, margem_pct
FROM hospital_margin_demo.gold.fato_margem_hospitalar
ORDER BY internacao_id
LIMIT 10;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Passo 3 — Tabela `resumo_financeiro_mensal`
-- MAGIC **Atenção a percentuais:** a margem do mês é `soma das margens / soma das receitas líquidas`.
-- MAGIC Fazer a **média** de `margem_pct` das internações daria o mesmo peso a uma internação de R$ 3 mil
-- MAGIC e a uma de R$ 80 mil, um erro comum.

-- COMMAND ----------

CREATE OR REPLACE TABLE hospital_margin_demo.gold.resumo_financeiro_mensal
COMMENT 'Gold | 1 linha por mês de competência (mês da admissão).'
AS
SELECT
    mes_competencia,
    periodo,
    count(*)                                                  AS internacoes,
    sum(receita_bruta)                                        AS receita_bruta,
    sum(glosas)                                               AS glosas,
    sum(receita_liquida)                                      AS receita_liquida,
    sum(custos)                                               AS custos,
    sum(margem)                                               AS margem,
    round(try_divide(sum(margem), sum(receita_liquida)), 4)   AS margem_pct,
    round(try_divide(sum(glosas), sum(receita_bruta)), 4)     AS taxa_glosa,
    round(avg(permanencia_dias), 2)                           AS permanencia_media,
    round(avg(CASE WHEN complexidade = 'ALTA' THEN 1 ELSE 0 END), 4) AS pct_alta_complexidade
FROM hospital_margin_demo.gold.fato_margem_hospitalar
GROUP BY mes_competencia, periodo;

-- COMMAND ----------

SELECT *
FROM hospital_margin_demo.gold.resumo_financeiro_mensal
ORDER BY mes_competencia;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Passo 4 — Tabela `resumo_operadoras`
-- MAGIC Comparamos cada operadora antes e depois de agosto/2026.

-- COMMAND ----------

CREATE OR REPLACE TABLE hospital_margin_demo.gold.resumo_operadoras
COMMENT 'Gold | 1 linha por operadora e período (Base x Deterioração).'
AS
SELECT
    operadora,
    periodo,
    count(*)                                                  AS internacoes,
    sum(receita_bruta)                                        AS receita_bruta,
    sum(glosas)                                               AS glosas,
    sum(receita_liquida)                                      AS receita_liquida,
    sum(margem)                                               AS margem,
    round(try_divide(sum(glosas), sum(receita_bruta)), 4)     AS taxa_glosa,
    round(try_divide(sum(margem), sum(receita_liquida)), 4)   AS margem_pct
FROM hospital_margin_demo.gold.fato_margem_hospitalar
GROUP BY operadora, periodo;

-- COMMAND ----------

SELECT *
FROM hospital_margin_demo.gold.resumo_operadoras
ORDER BY operadora, periodo;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## D. Validação

-- COMMAND ----------

-- 1) A Gold tem exatamente uma linha por internação da Silver? Esperado: os três números iguais.
SELECT
    (SELECT count(*) FROM hospital_margin_demo.silver.internacoes)                         AS internacoes_silver,
    (SELECT count(*) FROM hospital_margin_demo.gold.fato_margem_hospitalar)                AS linhas_gold,
    (SELECT count(DISTINCT internacao_id) FROM hospital_margin_demo.gold.fato_margem_hospitalar) AS internacoes_gold;

-- COMMAND ----------

-- 2) A receita bruta da Gold bate com a soma dos itens da Silver? Esperado: diferença = 0.00.
SELECT
    (SELECT sum(receita_bruta) FROM hospital_margin_demo.gold.fato_margem_hospitalar) AS receita_gold,
    (SELECT sum(valor_item)    FROM hospital_margin_demo.silver.faturamento)          AS receita_silver,
    (SELECT sum(receita_bruta) FROM hospital_margin_demo.gold.fato_margem_hospitalar)
  - (SELECT sum(valor_item)    FROM hospital_margin_demo.silver.faturamento)          AS diferenca;

-- COMMAND ----------

-- 3) O resumo mensal soma o mesmo que a tabela por internação? Esperado: diferença = 0.00.
SELECT
    (SELECT sum(margem) FROM hospital_margin_demo.gold.resumo_financeiro_mensal)
  - (SELECT sum(margem) FROM hospital_margin_demo.gold.fato_margem_hospitalar) AS diferenca_margem;

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC ## E. Exercício para o aluno
-- MAGIC
-- MAGIC <div style="border-left: 4px solid #d97706; background: #fffbeb; padding: 14px 18px; border-radius: 4px; margin: 16px 0;">
-- MAGIC   <strong style="display:block; color:#92400e; margin-bottom:6px; font-size: 1.1em;">Sua tarefa</strong>
-- MAGIC   <div style="color:#333;">
-- MAGIC     <p style="margin: 6px 0;">Crie um resumo por <strong>unidade</strong> e período, copiando o padrão do Passo 4: troque <code>operadora</code> por <code>unidade</code> e acrescente <code>round(avg(permanencia_dias), 2) AS permanencia_media</code>. <strong>Qual unidade teve a maior queda de margem?</strong></p>
-- MAGIC   </div>
-- MAGIC </div>
-- MAGIC
-- MAGIC <details>
-- MAGIC   <summary style="cursor: pointer; list-style: none; user-select: none;">
-- MAGIC     <div style="border-left: 4px solid #009688; background: #f0faf9; padding: 16px 20px; border-radius: 4px; margin: 16px 0">
-- MAGIC       <div style="display: flex; align-items: center; gap: 12px">
-- MAGIC         <span style="font-size: 20px;">&#x25B6;</span>
-- MAGIC         <strong style="color: #00695c; font-size: 1.1em;">Expandir para ver a resposta</strong>
-- MAGIC       </div>
-- MAGIC     </div>
-- MAGIC   </summary>
-- MAGIC   <div style="border-left: 4px solid #009688; background: #f0faf9; padding: 0 20px 16px 20px; border-radius: 0 0 4px 4px; margin: -16px 0 16px 0">
-- MAGIC     <div style="color: #333; line-height: 1.7;">
-- MAGIC <pre style="background: #1B3139; color: #fff; padding: 12px 16px; border-radius: 4px; font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, 'Liberation Mono', 'Courier New', monospace;">SELECT
-- MAGIC     unidade,
-- MAGIC     periodo,
-- MAGIC     count(*)                                                AS internacoes,
-- MAGIC     round(avg(permanencia_dias), 2)                         AS permanencia_media,
-- MAGIC     round(try_divide(sum(margem), sum(receita_liquida)), 4) AS margem_pct
-- MAGIC FROM hospital_margin_demo.gold.fato_margem_hospitalar
-- MAGIC GROUP BY unidade, periodo
-- MAGIC ORDER BY 1, 2;</pre><p>A <strong>Unidade Sul</strong> tem a maior queda: margem de 22,2% (Base) para 12,4% (Deterioração), quase 10 pontos. As demais caem de 2,4 a 4,7 pontos, efeito do mix e das glosas, que atingem toda a rede.</p>
-- MAGIC     </div>
-- MAGIC   </div>
-- MAGIC </details>

-- COMMAND ----------

SELECT
    operadora,                                                -- troque por unidade
    periodo,
    count(*)                                                  AS internacoes,
    round(try_divide(sum(margem), sum(receita_liquida)), 4)   AS margem_pct
FROM hospital_margin_demo.gold.fato_margem_hospitalar
GROUP BY operadora, periodo                                   -- e aqui também
ORDER BY 1, 2;
