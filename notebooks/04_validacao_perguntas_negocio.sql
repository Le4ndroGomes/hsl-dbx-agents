-- Databricks notebook source
-- MAGIC %md
-- MAGIC ![DB Academy](./Includes/images/db-academy.png)

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC # Hospital Data Matter — Sessão 04: Validação e perguntas de negócio
-- MAGIC
-- MAGIC ## A. Objetivo
-- MAGIC Ao final desta sessão você saberá:
-- MAGIC - conferir se os números da Gold **batem** com a Silver (reconciliação financeira);
-- MAGIC - responder perguntas de negócio com consultas SQL simples;
-- MAGIC - ir do indicador geral até a causa (operadora, unidade, procedimento).
-- MAGIC
-- MAGIC ## B. Contexto de negócio
-- MAGIC A diretoria do Hospital Data Matter pergunta: **"Por que a receita sobe e a margem cai?"**
-- MAGIC Antes de responder, precisamos confiar nos números. Por isso a sessão começa pela reconciliação.
-- MAGIC
-- MAGIC <div style="border-left: 4px solid #1976d2; background: #f0f7ff; padding: 14px 18px; border-radius: 4px; margin: 16px 0;">
-- MAGIC   <strong style="display:block; color:#0d47a1; margin-bottom:6px; font-size: 1.1em;">Observação</strong>
-- MAGIC   <div style="color:#333;">
-- MAGIC     <p style="margin: 6px 0;">Lembre-se: as três anomalias foram <strong>colocadas de propósito</strong> na Sessão 01 (é o gabarito). Aqui fazemos o papel do analista, que não conhece o gabarito e precisa encontrá-las nos dados.</p>
-- MAGIC   </div>
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
-- MAGIC     Execute antes os notebooks <code>01</code> a <code>03</code>.
-- MAGIC   </div>
-- MAGIC </div>

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## C. Implementação em SQL
-- MAGIC ### Passo 1 — Reconciliação financeira
-- MAGIC Cada linha compara um total da Gold com a sua origem na Silver. Todas devem mostrar `OK`.

-- COMMAND ----------

WITH gold AS (
    SELECT
        count(*)             AS internacoes,
        sum(receita_bruta)   AS receita_bruta,
        sum(glosas)          AS glosas,
        sum(custos)          AS custos
    FROM hospital_margin_demo.gold.fato_margem_hospitalar
),
comparacao AS (
    SELECT 'Internações'   AS verificacao, gold.internacoes   AS gold, (SELECT count(*)         FROM hospital_margin_demo.silver.internacoes) AS silver FROM gold
    UNION ALL
    SELECT 'Receita bruta',              gold.receita_bruta,          (SELECT sum(valor_item)  FROM hospital_margin_demo.silver.faturamento)          FROM gold
    UNION ALL
    SELECT 'Glosas',                     gold.glosas,                 (SELECT sum(valor_glosa) FROM hospital_margin_demo.silver.glosas)               FROM gold
    UNION ALL
    SELECT 'Custos',                     gold.custos,                 (SELECT sum(valor_custo) FROM hospital_margin_demo.silver.custos)               FROM gold
)
SELECT
    verificacao,
    gold,
    silver,
    CASE WHEN gold = silver THEN 'OK' ELSE 'ERRO' END AS resultado   -- comparação exata, ao centavo
FROM comparacao;

-- COMMAND ----------

-- As fórmulas estão corretas em TODAS as linhas? Esperado: 0 linhas com erro em cada regra.
SELECT
    count_if(receita_liquida <> receita_bruta - glosas)  AS erros_receita_liquida,
    count_if(margem          <> receita_liquida - custos) AS erros_margem,
    count_if(glosas > receita_bruta)                      AS glosa_maior_que_receita,
    count_if(data_alta < data_admissao)                   AS alta_antes_da_admissao
FROM hospital_margin_demo.gold.fato_margem_hospitalar;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Pergunta 1 — Qual é a receita mensal do hospital?

-- COMMAND ----------

SELECT
    mes_competencia,
    internacoes,
    receita_bruta,
    receita_liquida
FROM hospital_margin_demo.gold.resumo_financeiro_mensal
ORDER BY mes_competencia;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Pergunta 2 — Qual é a margem de contribuição?
-- MAGIC Comparamos a média mensal de cada período. A margem % é sempre **soma / soma**.

-- COMMAND ----------

SELECT
    periodo,
    count(*)                                                     AS meses,
    round(sum(receita_bruta)   / count(*), 2)                    AS receita_bruta_media_mes,
    round(sum(receita_liquida) / count(*), 2)                    AS receita_liquida_media_mes,
    round(sum(custos)          / count(*), 2)                    AS custos_media_mes,
    round(sum(margem)          / count(*), 2)                    AS margem_media_mes,
    round(try_divide(sum(margem), sum(receita_liquida)) * 100, 1) AS margem_pct
FROM hospital_margin_demo.gold.resumo_financeiro_mensal
GROUP BY periodo
ORDER BY periodo;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Pergunta 3 — Qual operadora tem a maior taxa de glosa?

-- COMMAND ----------

SELECT
    operadora,
    periodo,
    round(taxa_glosa * 100, 1)  AS taxa_glosa_pct,
    glosas
FROM hospital_margin_demo.gold.resumo_operadoras
ORDER BY periodo DESC, taxa_glosa DESC;

-- COMMAND ----------

-- Detalhando a operadora com maior glosa: QUAL tipo de item e QUAL motivo?
-- Juntamos glosa → item (tipo do item) → internação (operadora e período).
SELECT
    f.tipo_item,
    g.motivo_glosa,
    count(*)            AS glosas,
    sum(g.valor_glosa)  AS valor_glosado
FROM hospital_margin_demo.silver.glosas      AS g
JOIN hospital_margin_demo.silver.faturamento AS f ON f.item_id = g.item_id
JOIN hospital_margin_demo.silver.internacoes AS i ON i.internacao_id = g.internacao_id
WHERE i.operadora = 'Aurora Seguros'          -- troque a operadora para comparar
  AND i.mes_competencia >= DATE'2026-08-01'
GROUP BY f.tipo_item, g.motivo_glosa
ORDER BY valor_glosado DESC;

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC <div style="border-left: 4px solid #2e7d32; background: #f7fdf4; padding: 14px 18px; border-radius: 4px; margin: 16px 0;">
-- MAGIC   <strong style="display:block; color:#1b5e20; margin-bottom:6px; font-size: 1.1em;">O que observar</strong>
-- MAGIC   <div style="color:#333;">
-- MAGIC     <p style="margin: 6px 0;">A Aurora Seguros salta para 14,5% de glosa no período de deterioração, enquanto as outras operadoras ficam entre 4% e 5%. Cerca de três quartos (74%) do valor glosado vêm de itens de <strong>OPME</strong> com o motivo <strong>"Falta de autorização prévia de OPME"</strong>.</p>
-- MAGIC   </div>
-- MAGIC </div>

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Pergunta 4 — Qual unidade tem a maior permanência média? (por unidade, complexidade e período)

-- COMMAND ----------

SELECT
    unidade,
    complexidade,
    round(avg(CASE WHEN periodo LIKE 'Base%'         THEN permanencia_dias END), 1) AS permanencia_base,
    round(avg(CASE WHEN periodo LIKE 'Deterioração%' THEN permanencia_dias END), 1) AS permanencia_deterioracao
FROM hospital_margin_demo.gold.fato_margem_hospitalar
GROUP BY unidade, complexidade
ORDER BY unidade, complexidade;

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC <div style="border-left: 4px solid #2e7d32; background: #f7fdf4; padding: 14px 18px; border-radius: 4px; margin: 16px 0;">
-- MAGIC   <strong style="display:block; color:#1b5e20; margin-bottom:6px; font-size: 1.1em;">O que observar</strong>
-- MAGIC   <div style="color:#333;">
-- MAGIC     <p style="margin: 6px 0;">Só uma combinação muda de forma relevante: <strong>Unidade Sul + alta complexidade</strong>, cuja permanência passa de cerca de 7 para 13 dias. Como a operadora paga no máximo 10 diárias, os dias extras geram <strong>custo sem receita</strong>.</p>
-- MAGIC   </div>
-- MAGIC </div>

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Pergunta 5 — Por que a receita sobe enquanto a margem cai?
-- MAGIC Vamos olhar o **mix** por complexidade: quanto cada grupo representa e qual margem ele gera.

-- COMMAND ----------

SELECT
    periodo,
    complexidade,
    count(*)                                                        AS internacoes,
    -- OVER (PARTITION BY periodo) soma o total de internações de cada período sem agrupar as linhas:
    -- assim obtemos o % de cada complexidade dentro do seu período.
    round(count(*) * 100.0 / sum(count(*)) OVER (PARTITION BY periodo), 1) AS pct_internacoes,
    round(sum(receita_bruta) / 1e6, 2)                              AS receita_bruta_milhoes,
    round(try_divide(sum(margem), sum(receita_liquida)) * 100, 1)   AS margem_pct
FROM hospital_margin_demo.gold.fato_margem_hospitalar
GROUP BY periodo, complexidade
ORDER BY periodo, complexidade;

-- COMMAND ----------

-- Quanto cada efeito pesou no período de deterioração?
SELECT
    -- Efeito 1: glosas de OPME por falta de autorização (perda direta de receita)
    (SELECT sum(g.valor_glosa)
       FROM hospital_margin_demo.silver.glosas AS g
      WHERE g.motivo_glosa = 'Falta de autorização prévia de OPME')                AS glosas_autorizacao_opme,
    -- Efeito 2: diárias acima do limite contratual de 10 (custo que a operadora não paga)
    (SELECT sum(greatest(permanencia_dias - 10, 0))
       FROM hospital_margin_demo.gold.fato_margem_hospitalar
      WHERE unidade = 'Unidade Sul' AND complexidade = 'ALTA'
        AND periodo LIKE 'Deterioração%')                                           AS diarias_nao_pagas_sul_alta,
    -- Efeito 3: participação da alta complexidade na receita bruta
    (SELECT round(sum(CASE WHEN complexidade = 'ALTA' THEN receita_bruta END) * 100.0 / sum(receita_bruta), 1)
       FROM hospital_margin_demo.gold.fato_margem_hospitalar
      WHERE periodo LIKE 'Base%')                                                   AS pct_receita_alta_base,
    (SELECT round(sum(CASE WHEN complexidade = 'ALTA' THEN receita_bruta END) * 100.0 / sum(receita_bruta), 1)
       FROM hospital_margin_demo.gold.fato_margem_hospitalar
      WHERE periodo LIKE 'Deterioração%')                                           AS pct_receita_alta_deterioracao;

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC <div style="border-left: 4px solid #16a34a; background: #f7fdf4; padding: 14px 18px; border-radius: 4px; margin: 16px 0;">
-- MAGIC   <strong style="display:block; color:#14532d; margin-bottom:6px; font-size: 1.1em;">Resposta</strong>
-- MAGIC   <div style="color:#333;">
-- MAGIC     <p style="margin: 6px 0;">A receita sobe principalmente porque o hospital passou a fazer <strong>mais procedimentos de alta complexidade</strong>, que têm ticket médio alto e <strong>margem menor</strong>. Ao mesmo tempo, duas perdas atingem justamente esse grupo:</p>
-- MAGIC     <ol style="margin: 6px 0; line-height: 1.7;"><li>a Aurora Seguros passou a <strong>glosar OPME</strong> por falta de autorização prévia;</li><li>a Unidade Sul passou a manter esses pacientes <strong>6 dias a mais</strong>, com custo de diárias que a operadora não paga.</li></ol>
-- MAGIC     <p style="margin: 6px 0;">Mais volume com margem menor + perdas concentradas no grupo que mais cresceu = <strong>receita maior e margem % menor</strong>.</p>
-- MAGIC   </div>
-- MAGIC </div>

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## D. Validação
-- MAGIC Confira, usando o gabarito da Sessão 01:
-- MAGIC 1. a operadora com maior glosa na deterioração é a **Aurora Seguros**, e o maior valor vem de OPME;
-- MAGIC 2. a maior alta de permanência é da **Unidade Sul, complexidade ALTA**;
-- MAGIC 3. a participação de alta complexidade nas internações sobe de cerca de 14% para cerca de 23% (a regra do gerador é 15% → 22%; a diferença é a variação natural do sorteio).

-- COMMAND ----------

-- Validação automática do gabarito: as três linhas devem mostrar resultado = 'OK'.
WITH glosa_deterioracao AS (
    SELECT operadora, taxa_glosa
    FROM hospital_margin_demo.gold.resumo_operadoras
    WHERE periodo LIKE 'Deterioração%'
    ORDER BY taxa_glosa DESC
    LIMIT 1
),
permanencia AS (
    SELECT unidade, complexidade,
           avg(CASE WHEN periodo LIKE 'Deterioração%' THEN permanencia_dias END)
         - avg(CASE WHEN periodo LIKE 'Base%'         THEN permanencia_dias END) AS aumento_dias
    FROM hospital_margin_demo.gold.fato_margem_hospitalar
    GROUP BY unidade, complexidade
    ORDER BY aumento_dias DESC
    LIMIT 1
),
mix AS (
    SELECT
        -- avg de 1 e 0 = proporção de internações ALTA; o CASE externo considera só as linhas do período
        avg(CASE WHEN periodo LIKE 'Base%'         THEN CASE WHEN complexidade = 'ALTA' THEN 1.0 ELSE 0 END END) AS pct_alta_base,
        avg(CASE WHEN periodo LIKE 'Deterioração%' THEN CASE WHEN complexidade = 'ALTA' THEN 1.0 ELSE 0 END END) AS pct_alta_deterioracao
    FROM hospital_margin_demo.gold.fato_margem_hospitalar
)
SELECT 'Anomalia 1: maior glosa' AS verificacao, operadora AS encontrado,
       CASE WHEN operadora = 'Aurora Seguros' THEN 'OK' ELSE 'ERRO' END AS resultado
FROM glosa_deterioracao
UNION ALL
SELECT 'Anomalia 2: maior aumento de permanência', concat(unidade, ' / ', complexidade),
       CASE WHEN unidade = 'Unidade Sul' AND complexidade = 'ALTA' THEN 'OK' ELSE 'ERRO' END
FROM permanencia
UNION ALL
SELECT 'Anomalia 3: mix de alta complexidade',
       concat(round(pct_alta_base * 100, 1), '% → ', round(pct_alta_deterioracao * 100, 1), '%'),
       CASE WHEN pct_alta_deterioracao > pct_alta_base THEN 'OK' ELSE 'ERRO' END
FROM mix;
