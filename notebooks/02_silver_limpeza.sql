-- Databricks notebook source
-- MAGIC %md
-- MAGIC ![DB Academy](./Includes/images/db-academy.png)

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC # Hospital Data Matter — Sessão 02: Camada Silver (limpeza dos dados)
-- MAGIC
-- MAGIC ## A. Objetivo
-- MAGIC Ao final desta sessão você saberá:
-- MAGIC - converter tipos com `CAST` (dinheiro em `DECIMAL(18,2)`, nunca em `DOUBLE`);
-- MAGIC - filtrar registros inválidos com `WHERE`;
-- MAGIC - padronizar textos com `trim`, `upper` e `initcap`;
-- MAGIC - tratar valores nulos com `COALESCE`;
-- MAGIC - garantir que todo registro "filho" tenha um "pai" (integridade referencial).
-- MAGIC
-- MAGIC ## B. Contexto de negócio
-- MAGIC Os dados da Bronze chegaram com problemas típicos de sistemas hospitalares:
-- MAGIC
-- MAGIC <div style="max-width: 1000px; margin: 0 auto;">
-- MAGIC <table style="width: 100%; border-collapse: collapse; line-height: 1.6;">
-- MAGIC   <tr style="background: #1B3139; color: #fff;"><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Problema na Bronze</th><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Tabela</th><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Correção na Silver</th></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Operadora em MAIÚSCULAS e com espaço sobrando</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>internacoes</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>initcap(trim(...))</code></td></tr>
-- MAGIC   <tr style="background: #fff;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">10 internações de teste com alta antes da admissão</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>internacoes</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>WHERE data_alta &gt;= data_admissao</code></td></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Tipo do item em minúsculas</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>faturamento</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>upper(...)</code></td></tr>
-- MAGIC   <tr style="background: #fff;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">20 lançamentos de teste com valor zero</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>faturamento</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>WHERE valor_item &gt; 0</code></td></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Motivo da glosa não informado</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>glosas</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>COALESCE(..., 'Não informado')</code></td></tr>
-- MAGIC   <tr style="background: #fff;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Valores em <code>DOUBLE</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">todas</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>CAST(... AS DECIMAL(18,2))</code></td></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Nome do paciente em MAIÚSCULAS e com espaço sobrando</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>pacientes</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>initcap(trim(...))</code></td></tr>
-- MAGIC   <tr style="background: #fff;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">E-mail em MAIÚSCULAS</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>pacientes</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>lower(trim(...))</code></td></tr>
-- MAGIC </table>
-- MAGIC </div>
-- MAGIC
-- MAGIC Se a Silver estiver errada, **todo** indicador financeiro da Gold fica errado.

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
-- MAGIC     Execute antes o notebook <code>01_bronze_dados_sinteticos</code>.
-- MAGIC   </div>
-- MAGIC </div>

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC ## C. Implementação em SQL
-- MAGIC ### Passo 1 — Pacientes
-- MAGIC Padronizamos o texto: `initcap(trim(nome))` deixa só a primeira letra de cada palavra maiúscula e tira os espaços sobrando;
-- MAGIC `lower(trim(email))` deixa o e-mail todo em minúsculas.
-- MAGIC
-- MAGIC <div style="border-left: 4px solid #1976d2; background: #f0f7ff; padding: 14px 18px; border-radius: 4px; margin: 16px 0;">
-- MAGIC   <strong style="display:block; color:#0d47a1; margin-bottom:6px; font-size: 1.1em;">Observação</strong>
-- MAGIC   <div style="color:#333;">
-- MAGIC     <p style="margin: 6px 0;">Esta é a única tabela com <strong>dados pessoais</strong> (nome, e-mail, data de nascimento). Ela termina na Silver:
-- MAGIC     as tabelas Gold, a Metric View e o Genie não recebem nenhum dado do paciente, nem o <code>paciente_id</code>, porque as análises são por internação.
-- MAGIC     Isso se chama <strong>minimização de dados</strong> e é um princípio da LGPD.</p>
-- MAGIC   </div>
-- MAGIC </div>

-- COMMAND ----------

CREATE OR REPLACE TABLE hospital_margin_demo.silver.pacientes
COMMENT 'Silver | 1 linha por paciente, com nome e e-mail padronizados. Contém dados pessoais: não segue para a Gold.'
AS
SELECT
    paciente_id,
    initcap(trim(nome))               AS nome,      -- '  MARIA SILVA SOUZA  ' → 'Maria Silva Souza'
    lower(trim(email))                AS email,     -- 'ANA.LIMA12@EXAMPLE.COM' → 'ana.lima12@example.com'
    upper(sexo)                       AS sexo,
    CAST(data_nascimento AS DATE)     AS data_nascimento,
    trim(cidade)                      AS cidade
FROM hospital_margin_demo.bronze.pacientes;

-- COMMAND ----------

-- Antes x depois: só os pacientes que precisaram de correção
SELECT
    b.nome   AS nome_bronze,
    s.nome   AS nome_silver,
    b.email  AS email_bronze,
    s.email  AS email_silver
FROM hospital_margin_demo.bronze.pacientes AS b
JOIN hospital_margin_demo.silver.pacientes AS s
  ON s.paciente_id = b.paciente_id
WHERE b.nome <> s.nome
   OR b.email <> s.email
LIMIT 10;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Passo 2 — Internações
-- MAGIC Aqui também calculamos dois campos derivados que vamos usar muito:
-- MAGIC - `permanencia_dias`: dias entre a admissão e a alta (`datediff`);
-- MAGIC - `mes_competencia`: o mês da admissão (`date_trunc`), usado para comparar meses.

-- COMMAND ----------

CREATE OR REPLACE TABLE hospital_margin_demo.silver.internacoes
COMMENT 'Silver | 1 linha por internação válida, com textos padronizados.'
AS
SELECT
    internacao_id,
    paciente_id,
    trim(unidade)                                    AS unidade,
    initcap(trim(operadora))                         AS operadora,     -- ' AURORA SEGUROS ' → 'Aurora Seguros'
    procedimento,
    upper(complexidade)                              AS complexidade,
    CAST(data_admissao AS DATE)                      AS data_admissao,
    CAST(data_alta     AS DATE)                      AS data_alta,
    datediff(data_alta, data_admissao)               AS permanencia_dias,
    CAST(date_trunc('MONTH', data_admissao) AS DATE) AS mes_competencia
FROM hospital_margin_demo.bronze.internacoes
WHERE data_alta >= data_admissao                     -- descarta as internações de teste (alta antes da admissão)
  AND paciente_id IN (SELECT paciente_id FROM hospital_margin_demo.silver.pacientes);   -- todo paciente precisa estar no cadastro

-- COMMAND ----------

-- Antes x depois da padronização: na Bronze havia 10 grafias de operadora; na Silver, 5.
SELECT 'bronze' AS camada, operadora, count(*) AS internacoes FROM hospital_margin_demo.bronze.internacoes GROUP BY operadora
UNION ALL
SELECT 'silver', operadora, count(*) FROM hospital_margin_demo.silver.internacoes GROUP BY operadora
ORDER BY camada, operadora;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Passo 3 — Faturamento
-- MAGIC Mantemos só itens com valor positivo **e** que pertencem a uma internação válida da Silver.
-- MAGIC O `IN (SELECT ...)` garante a integridade: nenhum item "órfão" passa para a Silver.

-- COMMAND ----------

CREATE OR REPLACE TABLE hospital_margin_demo.silver.faturamento
COMMENT 'Silver | 1 linha por item faturado válido. Valores em BRL, DECIMAL(18,2).'
AS
SELECT
    item_id,
    internacao_id,
    upper(trim(tipo_item))               AS tipo_item,      -- 'opme' → 'OPME'
    CAST(quantidade AS INT)              AS quantidade,
    CAST(valor_item AS DECIMAL(18,2))    AS valor_item,     -- dinheiro sempre com 2 casas decimais exatas
    CAST(data_faturamento AS DATE)       AS data_faturamento
FROM hospital_margin_demo.bronze.faturamento
WHERE valor_item > 0                                         -- descarta lançamentos de teste com valor zero
  AND internacao_id IN (SELECT internacao_id FROM hospital_margin_demo.silver.internacoes);

-- COMMAND ----------

SELECT tipo_item, count(*) AS itens, sum(valor_item) AS valor_total
FROM hospital_margin_demo.silver.faturamento
GROUP BY tipo_item
ORDER BY valor_total DESC;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Passo 4 — Glosas
-- MAGIC Uma glosa só é válida se o item glosado existe no faturamento **e** se o valor glosado
-- MAGIC não passa do valor do item (a operadora não pode recusar mais do que foi cobrado).
-- MAGIC O `JOIN` com o faturamento faz as duas checagens de uma vez.

-- COMMAND ----------

CREATE OR REPLACE TABLE hospital_margin_demo.silver.glosas
COMMENT 'Silver | 1 linha por item glosado válido. Valores em BRL, DECIMAL(18,2).'
AS
SELECT
    g.glosa_id,
    g.item_id,
    g.internacao_id,
    COALESCE(g.motivo_glosa, 'Não informado')  AS motivo_glosa,   -- nulo vira um texto explícito
    CAST(g.valor_glosa AS DECIMAL(18,2))       AS valor_glosa,
    CAST(g.data_glosa AS DATE)                 AS data_glosa
FROM hospital_margin_demo.bronze.glosas      AS g
JOIN hospital_margin_demo.silver.faturamento AS f              -- o item glosado precisa existir na Silver
  ON f.item_id = g.item_id
WHERE CAST(g.valor_glosa AS DECIMAL(18,2)) <= f.valor_item;     -- glosa nunca maior que o item

-- COMMAND ----------

SELECT motivo_glosa, count(*) AS glosas, sum(valor_glosa) AS valor_glosado
FROM hospital_margin_demo.silver.glosas
GROUP BY motivo_glosa
ORDER BY valor_glosado DESC;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Passo 5 — Custos

-- COMMAND ----------

CREATE OR REPLACE TABLE hospital_margin_demo.silver.custos
COMMENT 'Silver | 1 linha por componente de custo válido. Valores em BRL, DECIMAL(18,2).'
AS
SELECT
    custo_id,
    internacao_id,
    upper(trim(componente))              AS componente,
    CAST(valor_custo AS DECIMAL(18,2))   AS valor_custo,
    CAST(data_custo AS DATE)             AS data_custo
FROM hospital_margin_demo.bronze.custos
WHERE valor_custo >= 0
  AND internacao_id IN (SELECT internacao_id FROM hospital_margin_demo.silver.internacoes);

-- COMMAND ----------

SELECT componente, count(*) AS linhas, sum(valor_custo) AS custo_total
FROM hospital_margin_demo.silver.custos
GROUP BY componente
ORDER BY custo_total DESC;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## D. Validação

-- COMMAND ----------

-- 1) Quantas linhas a limpeza removeu? Esperado: 10 internações e 20 itens de faturamento; 0 pacientes, 0 glosas e 0 custos.
SELECT 'pacientes' AS tabela,
       (SELECT count(*) FROM hospital_margin_demo.bronze.pacientes) AS bronze,
       (SELECT count(*) FROM hospital_margin_demo.silver.pacientes) AS silver
UNION ALL SELECT 'internacoes',
       (SELECT count(*) FROM hospital_margin_demo.bronze.internacoes),
       (SELECT count(*) FROM hospital_margin_demo.silver.internacoes)
UNION ALL SELECT 'faturamento',
       (SELECT count(*) FROM hospital_margin_demo.bronze.faturamento),
       (SELECT count(*) FROM hospital_margin_demo.silver.faturamento)
UNION ALL SELECT 'glosas',
       (SELECT count(*) FROM hospital_margin_demo.bronze.glosas),
       (SELECT count(*) FROM hospital_margin_demo.silver.glosas)
UNION ALL SELECT 'custos',
       (SELECT count(*) FROM hospital_margin_demo.bronze.custos),
       (SELECT count(*) FROM hospital_margin_demo.silver.custos);

-- COMMAND ----------

-- 2) Cada internação aparece uma única vez? Esperado: internacoes = internacoes_distintas.
SELECT count(*) AS internacoes, count(DISTINCT internacao_id) AS internacoes_distintas
FROM hospital_margin_demo.silver.internacoes;

-- COMMAND ----------

-- 3) Sobrou algum texto fora do padrão, motivo nulo ou internação sem paciente?
-- Esperado: 5 operadoras, 0 motivos nulos, 0 e-mails fora do padrão e 0 internações sem paciente.
SELECT
    (SELECT count(DISTINCT operadora) FROM hospital_margin_demo.silver.internacoes)            AS operadoras,
    (SELECT count(*) FROM hospital_margin_demo.silver.glosas WHERE motivo_glosa IS NULL)       AS motivos_nulos,
    (SELECT count(*) FROM hospital_margin_demo.silver.pacientes WHERE email <> lower(email))   AS emails_fora_do_padrao,
    (SELECT count(*) FROM hospital_margin_demo.silver.internacoes AS i
      LEFT JOIN hospital_margin_demo.silver.pacientes AS p ON p.paciente_id = i.paciente_id
      WHERE p.paciente_id IS NULL)                                                            AS internacoes_sem_paciente;
