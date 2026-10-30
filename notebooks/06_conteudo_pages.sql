-- Databricks notebook source
-- MAGIC %md
-- MAGIC ![DB Academy](./Includes/images/db-academy.png)

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC # Hospital Data Matter — Sessão 06: Conteúdo das Pages (roteiro manual)
-- MAGIC
-- MAGIC ## A. Objetivo
-- MAGIC Ao final desta sessão você saberá:
-- MAGIC - o que é uma **Page** no Unity Catalog: uma página de conhecimento que explica *o que significa* um dado ou uma métrica;
-- MAGIC - preencher os campos de uma Page (Domínio, Nome, Responsável, Sinônimos, Descrição, Corpo, Ativos relacionados);
-- MAGIC - ligar Pages às tabelas e à Metric View com menções `@`;
-- MAGIC - conferir com SQL a fórmula de cada Page **antes** de publicar.
-- MAGIC
-- MAGIC ## B. Contexto de negócio
-- MAGIC Na Sessão 05 a Metric View `gold.mv_margem_hospitalar` passou a guardar **como calcular** cada métrica.
-- MAGIC Falta registrar **o que ela significa para o negócio**: quando usar, armadilhas e onde encontrar.
-- MAGIC É isso que uma Page faz. Ela é lida por pessoas (busca no Catalog Explorer) e também ajuda o Genie a responder com a definição oficial.
-- MAGIC
-- MAGIC <div style="border-left: 4px solid #1976d2; background: #f0f7ff; padding: 14px 18px; border-radius: 4px; margin: 16px 0;">
-- MAGIC   <strong style="display:block; color:#0d47a1; margin-bottom:6px; font-size: 1.1em;">Observação</strong>
-- MAGIC   <div style="color:#333;">
-- MAGIC     <p style="margin: 6px 0;"><strong>Este notebook não cria nada automaticamente.</strong> As Pages são criadas na interface: <strong>Catalog Explorer → Discover → Pages → criar nova Page</strong>. Copie cada bloco abaixo para uma Page nova. As células SQL só <strong>conferem</strong> os números citados (leitura, sem alterar tabelas).</p>
-- MAGIC   </div>
-- MAGIC </div>
-- MAGIC
-- MAGIC <div style="max-width: 1000px; margin: 0 auto;">
-- MAGIC <table style="width: 100%; border-collapse: collapse; line-height: 1.6;">
-- MAGIC   <tr style="background: #1B3139; color: #fff;"><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">#</th><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Page</th><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Domínio sugerido</th><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Ativo principal</th></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">1</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Margem de Contribuição</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Hospital Data Matter › Financeiro</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>mv_margem_hospitalar</code> (medida <code>margem_pct</code>)</td></tr>
-- MAGIC   <tr style="background: #fff;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">2</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Taxa de Glosa</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Hospital Data Matter › Financeiro</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>mv_margem_hospitalar</code> (medida <code>taxa_glosa</code>)</td></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">3</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Taxa de Glosa de OPME</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Hospital Data Matter › Financeiro</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>silver.glosas</code> + <code>silver.faturamento</code> (fora da Metric View)</td></tr>
-- MAGIC   <tr style="background: #fff;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">4</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Permanência Média</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Hospital Data Matter › Operações Assistenciais</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>mv_margem_hospitalar</code> (medida <code>permanencia_media</code>)</td></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">5</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Guia: Análise de Margem Hospitalar</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Hospital Data Matter (domínio principal)</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">página de entrada que liga todas as outras</td></tr>
-- MAGIC </table>
-- MAGIC </div>
-- MAGIC
-- MAGIC <div style="border-left: 4px solid #1976d2; background: #f0f7ff; padding: 14px 18px; border-radius: 4px; margin: 16px 0;">
-- MAGIC   <strong style="display:block; color:#0d47a1; margin-bottom:6px; font-size: 1.1em;">Observação</strong>
-- MAGIC   <div style="color:#333;">
-- MAGIC     <p style="margin: 6px 0;">O campo <strong>Domínio</strong> só aceita domínios que já existem. Antes de publicar as Pages, crie o domínio <strong>Hospital Data Matter</strong> com os subdomínios <strong>Financeiro</strong> e <strong>Operações Assistenciais</strong>, seguindo o <strong>Passo 1 da Sessão 07</strong> (Catalog Explorer → Discover → Domains). A Page 5, que é o guia geral, fica no domínio principal.</p>
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
-- MAGIC     Execute antes os notebooks <code>01</code> a <code>05</code> (Metric View <code>gold.mv_margem_hospitalar</code>).
-- MAGIC   </div>
-- MAGIC </div>

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC ---
-- MAGIC ## C. Conteúdo das Pages
-- MAGIC
-- MAGIC ## Page 1: Margem de Contribuição
-- MAGIC
-- MAGIC <div style="max-width: 1000px; margin: 0 auto;">
-- MAGIC <table style="width: 100%; border-collapse: collapse; line-height: 1.6;">
-- MAGIC   <tr style="background: #1B3139; color: #fff;"><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Campo</th><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Valor</th></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Domínio</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Hospital Data Matter › Financeiro</td></tr>
-- MAGIC   <tr style="background: #fff;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Nome</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Margem de Contribuição</td></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Responsável</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">você (seu e-mail)</td></tr>
-- MAGIC   <tr style="background: #fff;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Sinônimos</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">margem, margem %, margem percentual, rentabilidade, contribution margin</td></tr>
-- MAGIC </table>
-- MAGIC </div>
-- MAGIC
-- MAGIC **Descrição:**
-- MAGIC ```
-- MAGIC Quanto sobra da receita líquida depois de pagar o custo assistencial das
-- MAGIC internações, em reais (margem) e em percentual da receita líquida (margem %).
-- MAGIC ```
-- MAGIC
-- MAGIC **Corpo:**
-- MAGIC ```
-- MAGIC Definição
-- MAGIC Margem de Contribuição é a receita líquida menos o custo assistencial da internação.
-- MAGIC
-- MAGIC Fórmulas:
-- MAGIC   receita_liquida = receita_bruta - glosas
-- MAGIC   margem          = receita_liquida - custos
-- MAGIC   margem %        = SUM(margem) / SUM(receita_liquida)
-- MAGIC
-- MAGIC A margem % é sempre soma / soma. Nunca calcule a média de margem_pct das
-- MAGIC internações: isso dá o mesmo peso a uma internação de R$ 3 mil e a uma de
-- MAGIC R$ 80 mil (no período base: 22,4% correto x 26,0% pela média errada).
-- MAGIC
-- MAGIC Uso no negócio
-- MAGIC Use as medidas margem e margem_pct da @mv_margem_hospitalar em vez de
-- MAGIC recalcular a partir de @fato_margem_hospitalar: a Metric View guarda a
-- MAGIC definição oficial e funciona em qualquer corte (mês, unidade, operadora,
-- MAGIC procedimento, complexidade).
-- MAGIC
-- MAGIC Referência atual: 22,4% no período base (nov/25-jul/26) e 16,9% no período
-- MAGIC de deterioração (ago-out/26).
-- MAGIC
-- MAGIC Veja também: @Taxa de Glosa (as glosas reduzem a receita líquida) e
-- MAGIC @Guia: Análise de Margem Hospitalar.
-- MAGIC ```
-- MAGIC
-- MAGIC **Ativos relacionados:** `mv_margem_hospitalar`, `fato_margem_hospitalar`, `resumo_financeiro_mensal`
-- MAGIC
-- MAGIC **Fontes (opcional):** nenhuma. O conteúdo é escrito direto na Page.

-- COMMAND ----------

-- Conferência da Page 1: margem % por período, pela Metric View.
-- Esperado: ~22,4% (Base) e ~16,9% (Deterioração).
SELECT
    periodo,
    round(MEASURE(margem_pct) * 100, 1) AS margem_pct
FROM hospital_margin_demo.gold.mv_margem_hospitalar
GROUP BY ALL
ORDER BY periodo;

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC ---
-- MAGIC ## Page 2: Taxa de Glosa
-- MAGIC
-- MAGIC <div style="max-width: 1000px; margin: 0 auto;">
-- MAGIC <table style="width: 100%; border-collapse: collapse; line-height: 1.6;">
-- MAGIC   <tr style="background: #1B3139; color: #fff;"><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Campo</th><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Valor</th></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Domínio</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Hospital Data Matter › Financeiro</td></tr>
-- MAGIC   <tr style="background: #fff;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Nome</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Taxa de Glosa</td></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Responsável</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">você (seu e-mail)</td></tr>
-- MAGIC   <tr style="background: #fff;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Sinônimos</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">glosa, índice de glosa, recusa da operadora, denial rate</td></tr>
-- MAGIC </table>
-- MAGIC </div>
-- MAGIC
-- MAGIC **Descrição:**
-- MAGIC ```
-- MAGIC Percentual do valor faturado que as operadoras se recusaram a pagar:
-- MAGIC soma das glosas dividida pela receita bruta do mesmo período e recorte.
-- MAGIC ```
-- MAGIC
-- MAGIC **Corpo:**
-- MAGIC ```
-- MAGIC Definição
-- MAGIC Glosa é o valor de um item faturado que a operadora de saúde recusa pagar
-- MAGIC (por exemplo: cobrança em duplicidade, divergência de quantidade, item não
-- MAGIC coberto ou falta de autorização prévia).
-- MAGIC
-- MAGIC Fórmula: SUM(glosas) / SUM(receita_bruta)
-- MAGIC
-- MAGIC Uso no negócio
-- MAGIC Use a medida taxa_glosa da @mv_margem_hospitalar, cortando por operadora
-- MAGIC e período para negociar com cada convênio.
-- MAGIC
-- MAGIC Referência atual: cerca de 4% para a rede no período base. No período de
-- MAGIC deterioração a Aurora Seguros sobe para 14,5%, enquanto as demais ficam
-- MAGIC entre 4% e 5%.
-- MAGIC
-- MAGIC Para saber QUAL tipo de item foi glosado (ex.: OPME), a Metric View não
-- MAGIC basta, porque ela tem uma linha por internação. Veja @Taxa de Glosa de OPME.
-- MAGIC
-- MAGIC Veja também: @Margem de Contribuição.
-- MAGIC ```
-- MAGIC
-- MAGIC **Ativos relacionados:** `mv_margem_hospitalar`, `resumo_operadoras`, `silver.glosas`
-- MAGIC
-- MAGIC **Fontes (opcional):** nenhuma. O conteúdo é escrito direto na Page.

-- COMMAND ----------

-- Conferência da Page 2: taxa de glosa por operadora no período de deterioração.
-- Esperado: Aurora Seguros ~14,5%; demais ~4% a 5%.
SELECT
    operadora,
    round(MEASURE(taxa_glosa) * 100, 1) AS taxa_glosa_pct
FROM hospital_margin_demo.gold.mv_margem_hospitalar
WHERE periodo LIKE 'Deterioração%'
GROUP BY ALL
ORDER BY taxa_glosa_pct DESC;

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC ---
-- MAGIC ## Page 3: Taxa de Glosa de OPME
-- MAGIC
-- MAGIC <div style="max-width: 1000px; margin: 0 auto;">
-- MAGIC <table style="width: 100%; border-collapse: collapse; line-height: 1.6;">
-- MAGIC   <tr style="background: #1B3139; color: #fff;"><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Campo</th><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Valor</th></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Domínio</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Hospital Data Matter › Financeiro</td></tr>
-- MAGIC   <tr style="background: #fff;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Nome</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Taxa de Glosa de OPME</td></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Responsável</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">você (seu e-mail)</td></tr>
-- MAGIC   <tr style="background: #fff;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Sinônimos</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">glosa de OPME, glosa de prótese, glosa de órteses e próteses, glosa por autorização</td></tr>
-- MAGIC </table>
-- MAGIC </div>
-- MAGIC
-- MAGIC **Descrição:**
-- MAGIC ```
-- MAGIC Percentual do valor faturado em OPME (órteses, próteses e materiais especiais)
-- MAGIC que foi glosado pelas operadoras. Calculado no nível de item, fora da Metric View.
-- MAGIC ```
-- MAGIC
-- MAGIC **Corpo:**
-- MAGIC ```
-- MAGIC Definição
-- MAGIC Taxa de Glosa de OPME = valor glosado em itens de OPME / valor faturado em
-- MAGIC itens de OPME, para o mesmo período e operadora.
-- MAGIC
-- MAGIC Fórmula:
-- MAGIC   SUM(silver.glosas.valor_glosa      dos itens com tipo_item = 'OPME')
-- MAGIC   / SUM(silver.faturamento.valor_item dos itens com tipo_item = 'OPME')
-- MAGIC
-- MAGIC Esta métrica NÃO é uma medida da @mv_margem_hospitalar: a Metric View
-- MAGIC tem uma linha por internação e não guarda o tipo do item. É preciso juntar
-- MAGIC @glosas ao @faturamento pelo item_id e AGREGAR CADA LADO SEPARADAMENTE antes
-- MAGIC de dividir (para não duplicar valores).
-- MAGIC
-- MAGIC Uso no negócio
-- MAGIC Use esta Page como a fórmula oficial quando alguém perguntar sobre glosa de
-- MAGIC OPME ou glosa por falta de autorização prévia. O Genie não consegue chegar a
-- MAGIC esta métrica sozinho a partir da Metric View.
-- MAGIC
-- MAGIC Referência atual: a Aurora Seguros passou de 4,3% (base) para 60,0%
-- MAGIC (deterioração), com motivo "Falta de autorização prévia de OPME". As demais
-- MAGIC operadoras ficam entre 3% e 6% no período de deterioração.
-- MAGIC
-- MAGIC Veja também: @Taxa de Glosa.
-- MAGIC ```
-- MAGIC
-- MAGIC **Ativos relacionados:** `silver.glosas`, `silver.faturamento`, `silver.internacoes`
-- MAGIC
-- MAGIC **Fontes (opcional):** nenhuma. O conteúdo é escrito direto na Page.

-- COMMAND ----------

-- Conferência da Page 3: taxa de glosa de OPME por operadora e período.
-- Cada lado (faturado e glosado) é somado separadamente antes de dividir.
-- Esperado: Aurora Seguros ~4,3% (Base) → ~60,0% (Deterioração).
WITH opme_faturado AS (
    SELECT i.operadora, i.mes_competencia >= DATE'2026-08-01' AS deterioracao, sum(f.valor_item) AS faturado_opme
    FROM hospital_margin_demo.silver.faturamento AS f
    JOIN hospital_margin_demo.silver.internacoes AS i ON i.internacao_id = f.internacao_id
    WHERE f.tipo_item = 'OPME'
    GROUP BY ALL
),
opme_glosado AS (
    SELECT i.operadora, i.mes_competencia >= DATE'2026-08-01' AS deterioracao, sum(g.valor_glosa) AS glosado_opme
    FROM hospital_margin_demo.silver.glosas      AS g
    JOIN hospital_margin_demo.silver.faturamento AS f ON f.item_id = g.item_id
    JOIN hospital_margin_demo.silver.internacoes AS i ON i.internacao_id = g.internacao_id
    WHERE f.tipo_item = 'OPME'
    GROUP BY ALL
)
SELECT
    fa.operadora,
    CASE WHEN fa.deterioracao THEN 'Deterioração (ago-out/26)' ELSE 'Base (nov/25-jul/26)' END AS periodo,
    round(100 * try_divide(coalesce(gl.glosado_opme, 0), fa.faturado_opme), 1)                AS taxa_glosa_opme_pct
FROM opme_faturado AS fa
LEFT JOIN opme_glosado AS gl USING (operadora, deterioracao)
ORDER BY periodo DESC, taxa_glosa_opme_pct DESC;

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC ---
-- MAGIC ## Page 4: Permanência Média
-- MAGIC
-- MAGIC <div style="max-width: 1000px; margin: 0 auto;">
-- MAGIC <table style="width: 100%; border-collapse: collapse; line-height: 1.6;">
-- MAGIC   <tr style="background: #1B3139; color: #fff;"><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Campo</th><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Valor</th></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Domínio</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Hospital Data Matter › Operações Assistenciais</td></tr>
-- MAGIC   <tr style="background: #fff;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Nome</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Permanência Média</td></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Responsável</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">você (seu e-mail)</td></tr>
-- MAGIC   <tr style="background: #fff;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Sinônimos</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">tempo médio de internação, média de permanência, ALOS, LOS, dias de internação</td></tr>
-- MAGIC </table>
-- MAGIC </div>
-- MAGIC
-- MAGIC **Descrição:**
-- MAGIC ```
-- MAGIC Número médio de dias entre a admissão e a alta, considerando todas as
-- MAGIC internações do recorte (total de pacientes-dia dividido pelas internações).
-- MAGIC ```
-- MAGIC
-- MAGIC **Corpo:**
-- MAGIC ```
-- MAGIC Definição
-- MAGIC Permanência Média = SUM(permanencia_dias) / COUNT(internações), em que
-- MAGIC permanencia_dias = data_alta - data_admissao (em dias).
-- MAGIC
-- MAGIC Por que importa para a margem
-- MAGIC Pelo contrato, a operadora paga no máximo 10 diárias por internação, mas o
-- MAGIC hospital tem custo em todos os dias. Cada dia além do 10º é custo sem receita.
-- MAGIC
-- MAGIC Uso no negócio
-- MAGIC Use a medida permanencia_media da @mv_margem_hospitalar, cortando por unidade
-- MAGIC e complexidade.
-- MAGIC
-- MAGIC Referência atual: cerca de 4,1 dias na rede (base). Na deterioração, a
-- MAGIC Unidade Sul com alta complexidade sobe de cerca de 7 para 12,9 dias.
-- MAGIC
-- MAGIC Veja também: @Margem de Contribuição.
-- MAGIC ```
-- MAGIC
-- MAGIC **Ativos relacionados:** `mv_margem_hospitalar`, `fato_margem_hospitalar`, `silver.internacoes`
-- MAGIC
-- MAGIC **Fontes (opcional):** nenhuma. O conteúdo é escrito direto na Page.

-- COMMAND ----------

-- Conferência da Page 4: permanência média por unidade (só alta complexidade) e período.
-- Esperado: Unidade Sul ~7 (Base) → ~12,9 (Deterioração); demais unidades ~7 nos dois períodos.
SELECT
    unidade,
    periodo,
    round(MEASURE(permanencia_media), 1) AS permanencia_media
FROM hospital_margin_demo.gold.mv_margem_hospitalar
WHERE complexidade = 'ALTA'
GROUP BY ALL
ORDER BY unidade, periodo;

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC ---
-- MAGIC ## Page 5: Guia: Análise de Margem Hospitalar
-- MAGIC
-- MAGIC <div style="max-width: 1000px; margin: 0 auto;">
-- MAGIC <table style="width: 100%; border-collapse: collapse; line-height: 1.6;">
-- MAGIC   <tr style="background: #1B3139; color: #fff;"><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Campo</th><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Valor</th></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Domínio</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Hospital Data Matter (domínio principal)</td></tr>
-- MAGIC   <tr style="background: #fff;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Nome</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Guia: Análise de Margem Hospitalar</td></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Responsável</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">você (seu e-mail)</td></tr>
-- MAGIC   <tr style="background: #fff;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Sinônimos</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Hospital Data Matter, margem hospitalar, análise de margem, por que a margem caiu</td></tr>
-- MAGIC </table>
-- MAGIC </div>
-- MAGIC
-- MAGIC **Descrição:**
-- MAGIC ```
-- MAGIC Página de entrada do Hospital Data Matter: que dados existem, qual Metric
-- MAGIC View usar e quais perguntas sobre receita, glosa, custo e margem ela responde.
-- MAGIC ```
-- MAGIC
-- MAGIC **Corpo:**
-- MAGIC ```
-- MAGIC Definição
-- MAGIC O Hospital Data Matter (dados 100% sintéticos, para sessões de treinamento) tem 4 unidades,
-- MAGIC 5 operadoras e 12 meses de internações (nov/2025 a out/2026). A métrica
-- MAGIC oficial está na @mv_margem_hospitalar, construída sobre
-- MAGIC @fato_margem_hospitalar (uma linha por internação).
-- MAGIC
-- MAGIC Camadas: bronze (dados brutos) → silver (dados limpos) → gold (tabelas de
-- MAGIC negócio e Metric View), todas no catálogo hospital_margin_demo.
-- MAGIC
-- MAGIC Uso no negócio
-- MAGIC Perguntas que estes dados respondem:
-- MAGIC - "Qual a receita e a margem % por mês?"
-- MAGIC - "Qual operadora tem a maior taxa de glosa no último trimestre?"
-- MAGIC - "Qual unidade tem a maior permanência média na alta complexidade?"
-- MAGIC - "Por que a receita subiu e a margem % caiu a partir de agosto/2026?"
-- MAGIC
-- MAGIC Resposta resumida da última pergunta: aumentou a participação de
-- MAGIC procedimentos de alta complexidade (ticket médio maior e margem menor), a Aurora
-- MAGIC Seguros passou a glosar OPME por falta de autorização prévia e a Unidade Sul
-- MAGIC passou a manter os pacientes de alta complexidade mais dias internados.
-- MAGIC
-- MAGIC Definições das métricas: @Margem de Contribuição, @Taxa de Glosa,
-- MAGIC @Taxa de Glosa de OPME e @Permanência Média.
-- MAGIC ```
-- MAGIC
-- MAGIC **Ativos relacionados:** `mv_margem_hospitalar`, `fato_margem_hospitalar`, `resumo_financeiro_mensal`, `resumo_operadoras`
-- MAGIC
-- MAGIC **Fontes (opcional):** nenhuma. O conteúdo é escrito direto na Page.
-- MAGIC
-- MAGIC <div style="border-left: 4px solid #1976d2; background: #f0f7ff; padding: 14px 18px; border-radius: 4px; margin: 16px 0;">
-- MAGIC   <strong style="display:block; color:#0d47a1; margin-bottom:6px; font-size: 1.1em;">Observação</strong>
-- MAGIC   <div style="color:#333;">
-- MAGIC     <p style="margin: 6px 0;">Quando um Genie Agent for criado sobre a <code>mv_margem_hospitalar</code>, acrescente-o em <strong>Ativos relacionados</strong> desta Page.</p>
-- MAGIC   </div>
-- MAGIC </div>

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ---
-- MAGIC ## Dicas de preenchimento
-- MAGIC - **Domínio** aceita uma única opção por Page. Escolha onde alguém procuraria aquela definição.
-- MAGIC - **Descrição** é o resumo curto que aparece na busca e nas listagens. **Corpo** é o texto completo:
-- MAGIC   mantenha os títulos *Definição* e *Uso no negócio* com a formatação de título do editor.
-- MAGIC - Use a menção **`@`** do editor para ligar cada ativo (tabelas, Metric View) e as outras Pages.
-- MAGIC   É isso que os faz aparecer como ativos relacionados e permite navegar de uma Page para outra.
-- MAGIC - **Publique** as cinco Pages deste roteiro. Rascunhos têm prioridade menor nas respostas do Genie.
-- MAGIC - Os valores de "Referência atual" vêm das conferências SQL deste notebook (10.000 internações).
-- MAGIC   Se você mudar o volume no notebook 01, rode as conferências de novo e atualize os números.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## D. Validação
-- MAGIC Antes de publicar, confirme que todos os ativos citados nas Pages existem. Esperado: 8 linhas, sem erro.

-- COMMAND ----------

-- Todos os ativos mencionados nas Pages existem no catálogo?
SELECT table_schema, table_name, table_type
FROM hospital_margin_demo.information_schema.tables
WHERE (table_schema = 'gold'   AND table_name IN ('mv_margem_hospitalar', 'fato_margem_hospitalar', 'resumo_financeiro_mensal', 'resumo_operadoras'))
   OR (table_schema = 'silver' AND table_name IN ('glosas', 'faturamento', 'internacoes', 'custos'))
ORDER BY table_schema, table_name;
