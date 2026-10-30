-- Databricks notebook source
-- MAGIC %md
-- MAGIC ![DB Academy](./Includes/images/db-academy.png)

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC # Hospital Data Matter — Sessão 08: Genie Agent para recuperação de margem
-- MAGIC
-- MAGIC ## A. Objetivo
-- MAGIC Ao final desta sessão você saberá:
-- MAGIC - desenhar um **Genie Agent** focado em um problema financeiro concreto;
-- MAGIC - escolher as **fontes certas** (Metric View certificada + tabelas de detalhe) e deixar de fora o que não deve entrar;
-- MAGIC - configurar **joins**, **expressões SQL**, **SQL de exemplo**, **instruções** e **perguntas de exemplo**;
-- MAGIC - criar **benchmarks** com respostas conferidas em SQL para avaliar o Agent.
-- MAGIC
-- MAGIC ## B. Contexto de negócio
-- MAGIC A margem de contribuição do Hospital Data Matter caiu de **22,4%** para **16,9%** a partir de agosto/2026.
-- MAGIC A diretoria financeira pediu uma ferramenta para a controladoria e o faturamento responderem, sem depender de TI:
-- MAGIC **"Quanto dinheiro estamos perdendo, onde, e quanto dá para recuperar?"**
-- MAGIC
-- MAGIC Vamos montar um Genie Agent chamado **Hospital Data Matter — Recuperação de Margem**. Ele não substitui o Genie One:
-- MAGIC o Genie One explora tudo o que você pode ver; o Agent é **curado** para um público e um problema, com instruções,
-- MAGIC exemplos e benchmarks próprios.
-- MAGIC
-- MAGIC <div style="max-width: 1000px; margin: 0 auto;">
-- MAGIC <table style="width: 100%; border-collapse: collapse; line-height: 1.6;">
-- MAGIC   <tr style="background: #1B3139; color: #fff;"><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Componente do Agent</th><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">O que vamos usar</th></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Fonte principal</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>gold.mv_margem_hospitalar</code> (Metric View certificada: receita, glosa, custo, margem)</td></tr>
-- MAGIC   <tr style="background: #fff;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Fontes de detalhe</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>silver.glosas</code>, <code>silver.faturamento</code>, <code>silver.internacoes</code> (glosa por tipo de item e motivo)</td></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Fica de fora</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Bronze, <code>gold.vw_margem_mensal_legado</code> (obsoleta) e <code>silver.pacientes</code> (dados pessoais)</td></tr>
-- MAGIC   <tr style="background: #fff;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Público</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">controladoria e faturamento: conhecem glosa e margem, não escrevem SQL</td></tr>
-- MAGIC </table>
-- MAGIC </div>
-- MAGIC
-- MAGIC <div style="border-left: 4px solid #1976d2; background: #f0f7ff; padding: 14px 18px; border-radius: 4px; margin: 16px 0;">
-- MAGIC   <strong style="display:block; color:#0d47a1; margin-bottom:6px; font-size: 1.1em;">Observação</strong>
-- MAGIC   <div style="color:#333;">
-- MAGIC     <p style="margin: 6px 0;"><strong>Este notebook não cria o Agent automaticamente.</strong> O Agent é criado na interface (<strong>Genie → New</strong>). Copie os blocos abaixo para cada campo. As células SQL <strong>conferem</strong> cada consulta e cada resposta esperada antes de você colar (só leitura).</p>
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
-- MAGIC     Execute antes as Sessões <code>01</code> a <code>07</code> (Metric View certificada e subdomínios criados). O Agent é criado na interface do Genie.
-- MAGIC   </div>
-- MAGIC </div>

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## C. Implementação
-- MAGIC ### Passo 1 — O tamanho do problema
-- MAGIC Antes de montar o Agent, medimos o que ele precisa ajudar a resolver. Se o período de deterioração tivesse a mesma margem % da base,
-- MAGIC quanto de margem o hospital teria? A diferença é a **margem perdida**.

-- COMMAND ----------

-- Margem perdida = (receita líquida da deterioração × margem % da base) − margem real da deterioração
WITH por_periodo AS (
    SELECT
        periodo,
        MEASURE(receita_liquida) AS receita_liquida,
        MEASURE(margem)          AS margem,
        MEASURE(margem_pct)      AS margem_pct
    FROM hospital_margin_demo.gold.mv_margem_hospitalar
    GROUP BY ALL
)
SELECT
    round(deterioracao.receita_liquida * base.margem_pct, 2)                         AS margem_esperada,
    deterioracao.margem                                                              AS margem_real,
    round(deterioracao.receita_liquida * base.margem_pct - deterioracao.margem, 2)     AS margem_perdida_3_meses,
    round((deterioracao.receita_liquida * base.margem_pct - deterioracao.margem) / 3, 2) AS margem_perdida_por_mes
FROM por_periodo AS deterioracao
JOIN por_periodo AS base
  ON base.periodo LIKE 'Base%'
WHERE deterioracao.periodo LIKE 'Deterioração%';

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC <div style="border-left: 4px solid #2e7d32; background: #f7fdf4; padding: 14px 18px; border-radius: 4px; margin: 16px 0;">
-- MAGIC   <strong style="display:block; color:#1b5e20; margin-bottom:6px; font-size: 1.1em;">O que observar</strong>
-- MAGIC   <div style="color:#333;">
-- MAGIC     <p style="margin: 6px 0;">a margem perdida é de cerca de <strong>R$ 3,1 milhões em 3 meses</strong> (cerca de R$ 1,03 milhão por mês). É esse número que a diretoria quer explicar e reduzir.</p>
-- MAGIC   </div>
-- MAGIC </div>

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC ### Passo 2 — Criar o Agent e escolher as fontes
-- MAGIC Na barra lateral, abra **Genie → New** e preencha:
-- MAGIC
-- MAGIC <div style="max-width: 1000px; margin: 0 auto;">
-- MAGIC <table style="width: 100%; border-collapse: collapse; line-height: 1.6;">
-- MAGIC   <tr style="background: #1B3139; color: #fff;"><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Campo</th><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Valor</th></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Nome</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Hospital Data Matter — Recuperação de Margem</td></tr>
-- MAGIC   <tr style="background: #fff;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">SQL Warehouse</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">um SQL Warehouse Serverless (neste workspace: Serverless Starter Warehouse)</td></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Dados</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>gold.mv_margem_hospitalar</code>, <code>silver.glosas</code>, <code>silver.faturamento</code>, <code>silver.internacoes</code></td></tr>
-- MAGIC </table>
-- MAGIC </div>
-- MAGIC
-- MAGIC **Descrição** (aparece para os usuários e é usada quando outros agentes escolhem a quem delegar a pergunta):
-- MAGIC ```
-- MAGIC Responde perguntas da controladoria e do faturamento do Hospital Data Matter
-- MAGIC sobre receita, glosas, custos e margem de contribuição (nov/2025 a out/2026,
-- MAGIC dados sintéticos). Foco: explicar a queda de margem a partir de agosto/2026 e
-- MAGIC quantificar o que é recuperável, como glosas de OPME por falta de autorização
-- MAGIC prévia. Fonte oficial: Metric View certificada mv_margem_hospitalar.
-- MAGIC ```
-- MAGIC
-- MAGIC **Por que estas fontes?** A Metric View já tem as fórmulas oficiais (margem %, taxa de glosa), então o Agent não precisa recalcular nada.
-- MAGIC As três tabelas Silver entram só porque a glosa **por tipo de item** (OPME) e **por motivo** não existe na Metric View.
-- MAGIC A `fato_margem_hospitalar` fica de fora: ela é a base da Metric View, e ter as duas faria o Genie refazer a agregação por conta própria.

-- COMMAND ----------

-- Conferência do Passo 2: as 4 fontes existem? A Metric View está certificada? A view legada está obsoleta?
-- Esperado: 4 fontes encontradas; mv_margem_hospitalar = certified; vw_margem_mensal_legado = deprecated (e fora do Agent).
SELECT
    t.table_schema,
    t.table_name,
    t.table_type,
    tg.tag_value AS certificacao
FROM hospital_margin_demo.information_schema.tables AS t
LEFT JOIN hospital_margin_demo.information_schema.table_tags AS tg
  ON  tg.schema_name = t.table_schema
  AND tg.table_name  = t.table_name
  AND tg.tag_name    = 'system.certification_status'
WHERE (t.table_schema = 'gold'   AND t.table_name IN ('mv_margem_hospitalar', 'vw_margem_mensal_legado'))
   OR (t.table_schema = 'silver' AND t.table_name IN ('glosas', 'faturamento', 'internacoes'))
ORDER BY t.table_schema, t.table_name;

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC ### Passo 3 — Configurar as colunas
-- MAGIC Em **Configure → Data**, abra cada fonte e ajuste as colunas. Duas regras:
-- MAGIC - **Esconder** colunas que não ajudam o negócio ou que identificam pessoas: `silver.internacoes.paciente_id`.
-- MAGIC - Ligar **entity matching** (correspondência de valores) só nas colunas de texto com poucos valores que o usuário escreve na pergunta.
-- MAGIC   Assim, "aurora" ou "glosa de prótese" encontram o valor certo.
-- MAGIC
-- MAGIC <div style="max-width: 1000px; margin: 0 auto;">
-- MAGIC <table style="width: 100%; border-collapse: collapse; line-height: 1.6;">
-- MAGIC   <tr style="background: #1B3139; color: #fff;"><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Fonte</th><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Colunas com entity matching</th><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Colunas escondidas</th></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>mv_margem_hospitalar</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>operadora</code>, <code>unidade</code>, <code>procedimento</code>, <code>complexidade</code>, <code>periodo</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">nenhuma</td></tr>
-- MAGIC   <tr style="background: #fff;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>silver.internacoes</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>operadora</code>, <code>unidade</code>, <code>procedimento</code>, <code>complexidade</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>paciente_id</code></td></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>silver.faturamento</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>tipo_item</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">nenhuma</td></tr>
-- MAGIC   <tr style="background: #fff;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>silver.glosas</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>motivo_glosa</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">nenhuma</td></tr>
-- MAGIC </table>
-- MAGIC </div>

-- COMMAND ----------

-- Conferência do Passo 3: quantos valores distintos têm as colunas de entity matching? (devem ser poucos)
-- Esperado: 5 operadoras, 4 unidades, 8 procedimentos, 3 complexidades, 4 tipos de item, 5 motivos de glosa.
SELECT 'operadora'    AS coluna, count(DISTINCT operadora)    AS valores_distintos FROM hospital_margin_demo.silver.internacoes
UNION ALL SELECT 'unidade',      count(DISTINCT unidade)      FROM hospital_margin_demo.silver.internacoes
UNION ALL SELECT 'procedimento', count(DISTINCT procedimento) FROM hospital_margin_demo.silver.internacoes
UNION ALL SELECT 'complexidade', count(DISTINCT complexidade) FROM hospital_margin_demo.silver.internacoes
UNION ALL SELECT 'tipo_item',    count(DISTINCT tipo_item)    FROM hospital_margin_demo.silver.faturamento
UNION ALL SELECT 'motivo_glosa', count(DISTINCT motivo_glosa) FROM hospital_margin_demo.silver.glosas;

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC ### Passo 4 — Joins entre as tabelas de detalhe
-- MAGIC Em **Configure → Joins**, declare como as tabelas Silver se relacionam (a Metric View não precisa de join):
-- MAGIC
-- MAGIC <div style="max-width: 1000px; margin: 0 auto;">
-- MAGIC <table style="width: 100%; border-collapse: collapse; line-height: 1.6;">
-- MAGIC   <tr style="background: #1B3139; color: #fff;"><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Tabela da esquerda</th><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Tabela da direita</th><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Condição</th><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Relação</th></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>faturamento</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>internacoes</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>faturamento.internacao_id = internacoes.internacao_id</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">muitos para um</td></tr>
-- MAGIC   <tr style="background: #fff;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>glosas</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>faturamento</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>glosas.item_id = faturamento.item_id</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">um para um (no máximo 1 glosa por item)</td></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>glosas</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>internacoes</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>glosas.internacao_id = internacoes.internacao_id</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">muitos para um</td></tr>
-- MAGIC </table>
-- MAGIC </div>
-- MAGIC
-- MAGIC Declarar a relação certa evita o erro de **fanout** que vimos na Sessão 03.

-- COMMAND ----------

-- Conferência do Passo 4: cada item tem no máximo 1 glosa? Esperado: 1 (por isso o join glosas → faturamento é um para um).
SELECT max(glosas_por_item) AS maximo_glosas_por_item
FROM (
    SELECT item_id, count(*) AS glosas_por_item
    FROM hospital_margin_demo.silver.glosas
    GROUP BY item_id
);

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Passo 5 — Expressões SQL (medidas e filtros reutilizáveis)
-- MAGIC Em **Configure → SQL Expressions**, cadastre só o que a Metric View **não** tem. Toda coluna leva o nome da tabela na frente
-- MAGIC (`glosas.valor_glosa`, e não só `valor_glosa`), senão o Genie não consegue combinar a expressão com outras tabelas.
-- MAGIC
-- MAGIC **Medida — Taxa de glosa de OPME** (sinônimos: glosa de OPME, glosa de prótese):
-- MAGIC ```
-- MAGIC try_divide(
-- MAGIC   SUM(CASE WHEN faturamento.tipo_item = 'OPME' THEN glosas.valor_glosa END),
-- MAGIC   SUM(CASE WHEN faturamento.tipo_item = 'OPME' THEN faturamento.valor_item END)
-- MAGIC )
-- MAGIC ```
-- MAGIC
-- MAGIC **Medida — Glosa por falta de autorização** (sinônimos: glosa recuperável, glosa por autorização prévia):
-- MAGIC ```
-- MAGIC SUM(CASE WHEN glosas.motivo_glosa = 'Falta de autorização prévia de OPME' THEN glosas.valor_glosa END)
-- MAGIC ```
-- MAGIC
-- MAGIC **Filtro — Período de deterioração** (sinônimos: depois de agosto, último trimestre, deterioração):
-- MAGIC ```
-- MAGIC internacoes.mes_competencia >= DATE'2026-08-01'
-- MAGIC ```

-- COMMAND ----------

-- Conferência do Passo 5: as três expressões funcionando juntas, com os mesmos nomes de tabela usados no Agent.
-- Esperado: Aurora Seguros com 60,0% de glosa de OPME e R$ 1.488.000,00 de glosa por falta de autorização; demais entre 3% e 6%.
SELECT
    internacoes.operadora,
    round(100 * try_divide(
        SUM(CASE WHEN faturamento.tipo_item = 'OPME' THEN glosas.valor_glosa END),
        SUM(CASE WHEN faturamento.tipo_item = 'OPME' THEN faturamento.valor_item END)
    ), 1)                                                                                          AS taxa_glosa_opme_pct,
    SUM(CASE WHEN glosas.motivo_glosa = 'Falta de autorização prévia de OPME' THEN glosas.valor_glosa END) AS glosa_por_falta_de_autorizacao
FROM hospital_margin_demo.silver.faturamento AS faturamento
JOIN hospital_margin_demo.silver.internacoes AS internacoes
  ON faturamento.internacao_id = internacoes.internacao_id
LEFT JOIN hospital_margin_demo.silver.glosas AS glosas
  ON glosas.item_id = faturamento.item_id
WHERE internacoes.mes_competencia >= DATE'2026-08-01'      -- filtro "Período de deterioração"
GROUP BY internacoes.operadora
ORDER BY taxa_glosa_opme_pct DESC;

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC ### Passo 6 — SQL de exemplo
-- MAGIC Em **Configure → SQL Queries**, cadastre consultas que **ensinam um formato** de pergunta. Não precisa de muitas: uma por formato.
-- MAGIC Cada célula abaixo é uma consulta de exemplo. Rode, confira o resultado e cole a consulta com a pergunta indicada.
-- MAGIC
-- MAGIC <div style="max-width: 1000px; margin: 0 auto;">
-- MAGIC <table style="width: 100%; border-collapse: collapse; line-height: 1.6;">
-- MAGIC   <tr style="background: #1B3139; color: #fff;"><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">#</th><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Pergunta para cadastrar</th><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Formato que ensina</th></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">1</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Ranking das operadoras por taxa de glosa no período de deterioração</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Metric View + filtro + ranking</td></tr>
-- MAGIC   <tr style="background: #fff;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">2</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Quanto foi glosado por operadora e motivo no período de deterioração?</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">tabelas de detalhe + join</td></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">3</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Qual seria a margem % sem a glosa por falta de autorização de OPME?</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">simulação: Metric View em CTE + detalhe</td></tr>
-- MAGIC </table>
-- MAGIC </div>

-- COMMAND ----------

-- Exemplo 1 — Ranking das operadoras por taxa de glosa no período de deterioração
SELECT
    operadora,
    MEASURE(receita_bruta) AS receita_bruta,
    MEASURE(glosas)        AS glosas,
    MEASURE(taxa_glosa)    AS taxa_glosa
FROM hospital_margin_demo.gold.mv_margem_hospitalar
WHERE mes_competencia >= DATE'2026-08-01'
GROUP BY ALL
ORDER BY taxa_glosa DESC;

-- COMMAND ----------

-- Exemplo 2 — Quanto foi glosado por operadora e motivo no período de deterioração?
SELECT
    internacoes.operadora,
    glosas.motivo_glosa,
    count(*)                AS itens_glosados,
    sum(glosas.valor_glosa) AS valor_glosado
FROM hospital_margin_demo.silver.glosas AS glosas
JOIN hospital_margin_demo.silver.internacoes AS internacoes
  ON internacoes.internacao_id = glosas.internacao_id
WHERE internacoes.mes_competencia >= DATE'2026-08-01'
GROUP BY internacoes.operadora, glosas.motivo_glosa
ORDER BY valor_glosado DESC;

-- COMMAND ----------

-- Exemplo 3 — Qual seria a margem % sem a glosa por falta de autorização de OPME (período de deterioração)?
-- A Metric View fica num CTE; a glosa recuperável vem do detalhe; depois combinamos os dois.
WITH atual AS (
    SELECT
        MEASURE(receita_liquida) AS receita_liquida,
        MEASURE(margem)          AS margem
    FROM hospital_margin_demo.gold.mv_margem_hospitalar
    WHERE mes_competencia >= DATE'2026-08-01'
),
glosa_recuperavel AS (
    SELECT sum(glosas.valor_glosa) AS valor
    FROM hospital_margin_demo.silver.glosas AS glosas
    JOIN hospital_margin_demo.silver.internacoes AS internacoes
      ON internacoes.internacao_id = glosas.internacao_id
    WHERE glosas.motivo_glosa = 'Falta de autorização prévia de OPME'
      AND internacoes.mes_competencia >= DATE'2026-08-01'
)
SELECT
    round(atual.margem / atual.receita_liquida * 100, 1)                                                   AS margem_pct_atual,
    glosa_recuperavel.valor                                                                                AS glosa_recuperavel,
    round((atual.margem + glosa_recuperavel.valor) / (atual.receita_liquida + glosa_recuperavel.valor) * 100, 1) AS margem_pct_sem_essa_glosa
FROM atual
CROSS JOIN glosa_recuperavel;

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC <div style="border-left: 4px solid #2e7d32; background: #f7fdf4; padding: 14px 18px; border-radius: 4px; margin: 16px 0;">
-- MAGIC   <strong style="display:block; color:#1b5e20; margin-bottom:6px; font-size: 1.1em;">O que observar</strong>
-- MAGIC   <div style="color:#333;">
-- MAGIC     <p style="margin: 6px 0;">recuperar só a glosa por falta de autorização de OPME (R$ 1,49 milhão) levaria a margem de <strong>16,9%</strong> para <strong>19,1%</strong>, ou seja, cerca de <strong>metade</strong> da margem perdida do Passo 1. É a ação de maior retorno para a diretoria.</p>
-- MAGIC   </div>
-- MAGIC </div>

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Passo 7 — Instruções de texto
-- MAGIC Em **Configure → Instructions**, cole o bloco abaixo. Instrução de texto é o **último recurso**: tudo que pôde virar fonte, coluna,
-- MAGIC join, expressão ou exemplo já foi configurado nos passos anteriores. Aqui ficam só regras gerais de comportamento.
-- MAGIC ```
-- MAGIC ## PURPOSE
-- MAGIC - Responder à controladoria e ao faturamento do Hospital Data Matter sobre receita, glosas, custos e margem de contribuição.
-- MAGIC - Os dados são sintéticos e cobrem admissões de nov/2025 a out/2026.
-- MAGIC
-- MAGIC ## DISAMBIGUATION
-- MAGIC - "Período de deterioração", "depois de agosto" ou "último trimestre" = ago/2026 a out/2026; "base" = nov/2025 a jul/2026.
-- MAGIC - "Margem" sem outra indicação = margem de contribuição em % (margem_pct).
-- MAGIC - "Glosa recuperável" = glosa com motivo "Falta de autorização prévia de OPME".
-- MAGIC
-- MAGIC ## DATA QUALITY NOTES
-- MAGIC - O mês de competência é o mês da admissão; a alta pode cair depois de 31/10/2026.
-- MAGIC
-- MAGIC ## CONSTRAINTS
-- MAGIC - Não responda perguntas sobre pacientes individuais.
-- MAGIC
-- MAGIC ## Instructions you must follow when providing summaries
-- MAGIC - Mostre valores em R$ e percentuais com uma casa decimal.
-- MAGIC - Informe sempre o período usado na resposta.
-- MAGIC ```
-- MAGIC
-- MAGIC **Por que estas instruções existem?** O significado de "período de deterioração" e de "glosa recuperável" é uma convenção da diretoria,
-- MAGIC não está em nenhuma coluna. A regra de não falar de pacientes é uma proteção extra: as fontes já não têm dados pessoais.
-- MAGIC A seção de resumo usa o título em inglês exatamente como o Genie espera.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Passo 8 — Perguntas de exemplo
-- MAGIC Em **Configure → Sample questions**, cadastre perguntas que mostram ao usuário o que o Agent sabe responder:
-- MAGIC ```
-- MAGIC Quanto de margem perdemos no período de deterioração em relação à base?
-- MAGIC Qual operadora mais aumentou a taxa de glosa depois de agosto?
-- MAGIC Quanto da glosa é recuperável com autorização prévia de OPME?
-- MAGIC Qual seria a margem se recuperássemos a glosa por falta de autorização?
-- MAGIC Quais procedimentos têm a menor margem no último trimestre?
-- MAGIC ```

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC ### Passo 9 — Benchmarks (avaliação do Agent)
-- MAGIC Em **Benchmarks**, cadastre perguntas com a **resposta conferida**. Depois clique em **Run benchmarks** para ver quantas o Agent acerta.
-- MAGIC Use frases **diferentes** das perguntas de exemplo: o objetivo é testar, não decorar.
-- MAGIC
-- MAGIC <div style="max-width: 1000px; margin: 0 auto;">
-- MAGIC <table style="width: 100%; border-collapse: collapse; line-height: 1.6;">
-- MAGIC   <tr style="background: #1B3139; color: #fff;"><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">#</th><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Pergunta do benchmark</th><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Resposta esperada</th></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">B1</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Qual foi a margem de contribuição % entre agosto e outubro de 2026?</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">16,9%</td></tr>
-- MAGIC   <tr style="background: #fff;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">B2</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Qual convênio teve a maior taxa de glosa de ago a out/2026?</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Aurora Seguros, 14,5%</td></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">B3</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Quantos reais foram glosados por falta de autorização prévia de OPME?</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">R$ 1.488.000,00</td></tr>
-- MAGIC   <tr style="background: #fff;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">B4</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Qual a taxa de glosa de OPME da Aurora Seguros antes e depois de agosto/2026?</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">4,3% → 60,0%</td></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">B5</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Qual a margem % da Unidade Sul na alta complexidade no último trimestre?</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">5,8%</td></tr>
-- MAGIC </table>
-- MAGIC </div>
-- MAGIC
-- MAGIC A célula abaixo calcula todas as respostas de uma vez: é o gabarito que você cola em cada benchmark.

-- COMMAND ----------

-- Gabarito dos benchmarks: cada linha é calculada com a mesma fonte que o Agent deve usar.
WITH opme AS (
    SELECT
        internacoes.mes_competencia >= DATE'2026-08-01' AS deterioracao,
        try_divide(
            SUM(CASE WHEN faturamento.tipo_item = 'OPME' THEN glosas.valor_glosa END),
            SUM(CASE WHEN faturamento.tipo_item = 'OPME' THEN faturamento.valor_item END)
        ) AS taxa_glosa_opme
    FROM hospital_margin_demo.silver.faturamento AS faturamento
    JOIN hospital_margin_demo.silver.internacoes AS internacoes
      ON faturamento.internacao_id = internacoes.internacao_id
    LEFT JOIN hospital_margin_demo.silver.glosas AS glosas
      ON glosas.item_id = faturamento.item_id
    WHERE internacoes.operadora = 'Aurora Seguros'
    GROUP BY ALL
),
ranking_glosa AS (
    SELECT operadora, MEASURE(taxa_glosa) AS taxa_glosa
    FROM hospital_margin_demo.gold.mv_margem_hospitalar
    WHERE mes_competencia >= DATE'2026-08-01'
    GROUP BY ALL
    ORDER BY taxa_glosa DESC
    LIMIT 1
),
gabarito AS (
SELECT 'B1' AS benchmark, concat(round((SELECT MEASURE(margem_pct) FROM hospital_margin_demo.gold.mv_margem_hospitalar
                                        WHERE mes_competencia >= DATE'2026-08-01') * 100, 1), '%') AS resposta
UNION ALL
SELECT 'B2', concat(operadora, ', ', round(taxa_glosa * 100, 1), '%') FROM ranking_glosa
UNION ALL
-- format_number usa o padrão americano (1,488,000.00); translate troca vírgula e ponto para o padrão brasileiro
SELECT 'B3', concat('R$ ', translate(format_number((SELECT sum(valor_glosa) FROM hospital_margin_demo.silver.glosas
                                 WHERE motivo_glosa = 'Falta de autorização prévia de OPME'), 2), ',.', '.,'))
UNION ALL
SELECT 'B4', concat(round(max(CASE WHEN NOT deterioracao THEN taxa_glosa_opme END) * 100, 1), '% → ',
                    round(max(CASE WHEN deterioracao     THEN taxa_glosa_opme END) * 100, 1), '%') FROM opme
UNION ALL
SELECT 'B5', concat(round((SELECT MEASURE(margem_pct) FROM hospital_margin_demo.gold.mv_margem_hospitalar
                           WHERE unidade = 'Unidade Sul' AND complexidade = 'ALTA'
                             AND mes_competencia >= DATE'2026-08-01') * 100, 1), '%')
)
SELECT
    benchmark,
    CASE WHEN benchmark = 'B3' THEN resposta ELSE replace(resposta, '.', ',') END AS resposta   -- decimal com vírgula
FROM gabarito
ORDER BY benchmark;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Passo 10 — Testar, compartilhar e governar
-- MAGIC 1. **Teste** no chat do Agent as perguntas do Passo 8. Para cada resposta, abra o SQL gerado e confira se ele usou a Metric View
-- MAGIC    (`MEASURE(...)`) para margem e taxa de glosa, e as tabelas Silver só para OPME e motivo.
-- MAGIC 2. **Rode os benchmarks** do Passo 9. Se alguma resposta errar, melhore primeiro as fontes, colunas, expressões ou exemplos;
-- MAGIC    instrução de texto é o último recurso.
-- MAGIC 3. **Compartilhe** pelo botão **Share** com o grupo da controladoria. Cada usuário também precisa de permissão de leitura nas 4 fontes
-- MAGIC    e de uso no SQL Warehouse: o Agent respeita as permissões do Unity Catalog de quem pergunta.
-- MAGIC 4. **Governe** o Agent na interface: atribua o domínio **Hospital Data Matter › Financeiro** e marque como **Certified**.
-- MAGIC    (A Sessão 07 fez isso por SQL para tabelas e views; para o Agent, é feito na interface.)
-- MAGIC 5. **Ligue com as Pages:** na Page "Guia: Análise de Margem Hospitalar", acrescente o Agent em **Related assets**.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## D. Validação

-- COMMAND ----------

-- As fontes do Agent têm alguma coluna de dado pessoal que ficou visível?
-- Esperado: só paciente_id em silver.internacoes, que é escondida no Passo 3. Nenhuma coluna de nome, e-mail ou nascimento.
SELECT table_schema, table_name, column_name
FROM hospital_margin_demo.information_schema.columns
WHERE ((table_schema = 'gold'   AND table_name = 'mv_margem_hospitalar')
    OR (table_schema = 'silver' AND table_name IN ('glosas', 'faturamento', 'internacoes')))
  AND (column_name LIKE '%paciente%' OR column_name IN ('nome', 'email', 'data_nascimento', 'cidade', 'sexo'))
ORDER BY table_schema, table_name, column_name;

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC ## E. Exercício para o aluno
-- MAGIC
-- MAGIC <div style="border-left: 4px solid #d97706; background: #fffbeb; padding: 14px 18px; border-radius: 4px; margin: 16px 0;">
-- MAGIC   <strong style="display:block; color:#92400e; margin-bottom:6px; font-size: 1.1em;">Sua tarefa</strong>
-- MAGIC   <div style="color:#333;">
-- MAGIC     <p style="margin: 6px 0;">Crie um <strong>benchmark B6</strong>: <em>"Qual foi a receita líquida da Coopermed entre agosto e outubro de 2026?"</em>. Use a consulta abaixo para obter a resposta esperada (troque a operadora para criar outros benchmarks) e rode os benchmarks de novo. <strong>O Agent acertou? O SQL gerado usou a Metric View?</strong></p>
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
-- MAGIC <p>A resposta esperada do B6 é <strong>R$ 10.661.400,00</strong> de receita líquida da Coopermed entre ago e out/2026.</p><p>O SQL gerado pelo Agent deve usar <code>MEASURE(receita_liquida)</code> na <code>mv_margem_hospitalar</code>, com filtro de operadora e de período. Se ele somar colunas das tabelas Silver, revise as descrições e o SQL de exemplo 1, que ensina a usar a Metric View.</p>
-- MAGIC     </div>
-- MAGIC   </div>
-- MAGIC </details>

-- COMMAND ----------

SELECT MEASURE(receita_liquida) AS receita_liquida
FROM hospital_margin_demo.gold.mv_margem_hospitalar
WHERE operadora = 'Coopermed'                          -- troque aqui
  AND mes_competencia >= DATE'2026-08-01';
