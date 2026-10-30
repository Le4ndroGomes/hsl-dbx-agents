-- Databricks notebook source
-- MAGIC %md
-- MAGIC ![DB Academy](./Includes/images/db-academy.png)

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC # Hospital Data Matter — Sessão 07: Domínios, certificação e obsolescência
-- MAGIC
-- MAGIC ## A. Objetivo
-- MAGIC Ao final desta sessão você saberá:
-- MAGIC - montar uma **estrutura de domínios** (domínio e subdomínios) no Catalog Explorer;
-- MAGIC - **certificar** tabelas e Metric Views com a tag de sistema `system.certification_status`;
-- MAGIC - marcar um ativo antigo como **obsoleto** (`deprecated`) sem apagá-lo;
-- MAGIC - associar ativos aos subdomínios com `SET TAG` / `UNSET TAG`;
-- MAGIC - consultar as tags aplicadas em `information_schema.table_tags`.
-- MAGIC
-- MAGIC ## B. Contexto de negócio
-- MAGIC A diretoria do Hospital Data Matter quer que qualquer analista encontre, no **Catalog Explorer → Discover**, as fontes
-- MAGIC **oficiais** para falar de margem, glosa e permanência, e que saiba quais fontes **não** deve mais usar. Vamos aplicar três coisas:
-- MAGIC
-- MAGIC <div style="max-width: 1000px; margin: 0 auto;">
-- MAGIC <table style="width: 100%; border-collapse: collapse; line-height: 1.6;">
-- MAGIC   <tr style="background: #1B3139; color: #fff;"><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">O quê</th><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Como</th><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Efeito no Catalog Explorer</th></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Domínio</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">criado na interface (Passo 1) e aplicado com <code>SET TAG ON TABLE</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">o ativo aparece dentro do domínio na página Discover</td></tr>
-- MAGIC   <tr style="background: #fff;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Certificação</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>ALTER ... SET TAGS ('system.certification_status' = 'certified')</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">selo <strong>Certified</strong> no ativo</td></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Obsolescência</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>ALTER ... SET TAGS ('system.certification_status' = 'deprecated')</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">selo <strong>Deprecated</strong>: o ativo continua existindo, mas avisa que não deve ser usado</td></tr>
-- MAGIC </table>
-- MAGIC </div>
-- MAGIC
-- MAGIC **Como funciona a tag de domínio:** cada domínio criado em **Discover → Domains** vira uma *governed tag* cuja **chave é o nome do domínio**
-- MAGIC e cujo **valor é vazio** (uma tag só com chave). Um subdomínio usa o formato `Pai/Filho`. Na nossa estrutura:
-- MAGIC
-- MAGIC <div style="max-width: 1000px; margin: 0 auto;">
-- MAGIC <table style="width: 100%; border-collapse: collapse; line-height: 1.6;">
-- MAGIC   <tr style="background: #1B3139; color: #fff;"><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Nível</th><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Nome no Catalog Explorer</th><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Chave da tag</th></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Domínio</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Hospital Data Matter</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>Hospital Data Matter</code></td></tr>
-- MAGIC   <tr style="background: #fff;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Subdomínio</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Financeiro</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>Hospital Data Matter/Financeiro</code></td></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Subdomínio</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Operações Assistenciais</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>Hospital Data Matter/Operações Assistenciais</code></td></tr>
-- MAGIC </table>
-- MAGIC </div>
-- MAGIC
-- MAGIC **O que vamos marcar:**
-- MAGIC
-- MAGIC <div style="max-width: 1000px; margin: 0 auto;">
-- MAGIC <table style="width: 100%; border-collapse: collapse; line-height: 1.6;">
-- MAGIC   <tr style="background: #1B3139; color: #fff;"><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Ativo</th><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Camada</th><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Certificação</th><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Subdomínio</th></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>bronze.*</code> (5 tabelas)</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Bronze</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">nenhuma</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">nenhum</td></tr>
-- MAGIC   <tr style="background: #fff;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>silver.pacientes</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Silver</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">nenhuma</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">nenhum (dados pessoais: tratados na sessão de governança)</td></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>silver.internacoes</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Silver</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">nenhuma</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Operações Assistenciais</td></tr>
-- MAGIC   <tr style="background: #fff;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>silver.faturamento</code>, <code>silver.glosas</code>, <code>silver.custos</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Silver</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">nenhuma</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Financeiro</td></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>gold.fato_margem_hospitalar</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Gold</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><strong>certified</strong></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Financeiro e Operações Assistenciais</td></tr>
-- MAGIC   <tr style="background: #fff;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>gold.resumo_financeiro_mensal</code>, <code>gold.resumo_operadoras</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Gold</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><strong>certified</strong></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Financeiro</td></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>gold.mv_margem_hospitalar</code> (Metric View)</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Gold</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><strong>certified</strong></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Financeiro e Operações Assistenciais</td></tr>
-- MAGIC   <tr style="background: #fff;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>gold.vw_margem_mensal_legado</code> (view antiga)</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Gold</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><strong>deprecated</strong></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Financeiro</td></tr>
-- MAGIC </table>
-- MAGIC </div>
-- MAGIC
-- MAGIC Todas as instruções SQL podem ser reexecutadas: aplicar de novo a mesma tag não duplica nada.

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
-- MAGIC     Execute antes as Sessões <code>01</code> a <code>05</code>. O Passo 1 (criar os domínios) é feito na interface do Catalog Explorer.
-- MAGIC   </div>
-- MAGIC </div>

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC ## C. Implementação
-- MAGIC ### Passo 1 — Criar a estrutura de domínios (na interface)
-- MAGIC Domínios são criados pela interface do Catalog Explorer (não há comando SQL para isso):
-- MAGIC 1. Abra **Catalog Explorer → Discover → Domains** e crie o domínio **`Hospital Data Matter`**. Descrição sugerida: *"Dados sintéticos da demonstração de margem hospitalar."*
-- MAGIC 2. Dentro dele, crie o subdomínio **`Financeiro`**. Descrição: *"Receita, glosas, custos e margem de contribuição."*
-- MAGIC 3. Crie também o subdomínio **`Operações Assistenciais`**. Descrição: *"Internações, permanência e complexidade clínica."*
-- MAGIC 4. Use **exatamente** esses nomes, com acento e espaço: a chave da tag é o próprio nome.
-- MAGIC
-- MAGIC <div style="border-left: 4px solid #d97706; background: #fffbeb; padding: 14px 18px; border-radius: 4px; margin: 16px 0;">
-- MAGIC   <strong style="display:block; color:#92400e; margin-bottom:6px; font-size: 1.1em;">Atenção</strong>
-- MAGIC   <div style="color:#333;">
-- MAGIC     <p style="margin: 6px 0;">se os domínios não forem criados, os comandos <code>SET TAG</code> dos próximos passos funcionam do mesmo jeito, mas a tag fica "solta": o ativo não aparece agrupado em nenhum domínio na página Discover.</p>
-- MAGIC   </div>
-- MAGIC </div>

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Passo 2 — Quais tags existem hoje?
-- MAGIC `information_schema.table_tags` lista todas as tags de tabelas e views do catálogo. Na primeira execução, o esperado é **nenhuma linha**;
-- MAGIC numa reexecução aparecem as tags já aplicadas.

-- COMMAND ----------

SELECT schema_name, table_name, tag_name, tag_value
FROM hospital_margin_demo.information_schema.table_tags
ORDER BY schema_name, table_name, tag_name;

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC ### Passo 3 — Certificar as fontes oficiais (Gold)
-- MAGIC **O que certificar?** Só o que deve ser usado para decisão: as tabelas **Gold** e a **Metric View**.
-- MAGIC - A **Bronze** guarda dados brutos com problemas conhecidos (operadora sem padrão, registros de teste): nunca deve ser certificada.
-- MAGIC - A **Silver** é limpa, mas ainda é uma etapa intermediária; ela recebe subdomínio (para ser encontrada), mas não recebe o selo.
-- MAGIC
-- MAGIC A Metric View é uma *view*, por isso usamos `ALTER VIEW` em vez de `ALTER TABLE`.
-- MAGIC
-- MAGIC <div style="border-left: 4px solid #d97706; background: #fffbeb; padding: 14px 18px; border-radius: 4px; margin: 16px 0;">
-- MAGIC   <strong style="display:block; color:#92400e; margin-bottom:6px; font-size: 1.1em;">Atenção</strong>
-- MAGIC   <div style="color:#333;">
-- MAGIC     <p style="margin: 6px 0;">as tabelas mantêm as tags quando são recriadas com <code>CREATE OR REPLACE TABLE</code>, mas a Metric View <strong>perde</strong> as tags quando a Sessão 05 a recria com <code>CREATE OR REPLACE VIEW</code>. Sempre que rodar a Sessão 05 de novo, rode esta sessão em seguida.</p>
-- MAGIC   </div>
-- MAGIC </div>

-- COMMAND ----------

-- Selo "Certified" nas três tabelas Gold
ALTER TABLE hospital_margin_demo.gold.fato_margem_hospitalar   SET TAGS ('system.certification_status' = 'certified');
ALTER TABLE hospital_margin_demo.gold.resumo_financeiro_mensal SET TAGS ('system.certification_status' = 'certified');
ALTER TABLE hospital_margin_demo.gold.resumo_operadoras        SET TAGS ('system.certification_status' = 'certified');

-- Selo "Certified" na Metric View (é uma VIEW)
ALTER VIEW  hospital_margin_demo.gold.mv_margem_hospitalar     SET TAGS ('system.certification_status' = 'certified');

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Passo 4 — Marcar um ativo como obsoleto (Deprecated)
-- MAGIC Toda empresa tem relatórios antigos que continuam sendo usados por hábito. Aqui simulamos um: a view `vw_margem_mensal_legado`,
-- MAGIC criada antes da Metric View, que calcula a margem % como **média de percentuais**, o erro que vimos na Sessão 05.
-- MAGIC
-- MAGIC Em vez de apagá-la (e quebrar quem ainda depende dela), marcamos como **deprecated** e explicamos no comentário qual é a fonte oficial.
-- MAGIC O ciclo de vida de um ativo fica assim: *sem selo → certified → deprecated*.

-- COMMAND ----------

-- A view "legada": margem % calculada como média de percentuais (errado: deveria ser soma / soma)
CREATE OR REPLACE VIEW hospital_margin_demo.gold.vw_margem_mensal_legado
COMMENT 'OBSOLETA: calcula a margem % como média de percentuais. Use a Metric View gold.mv_margem_hospitalar (medida margem_pct).'
AS
SELECT
    mes_competencia,
    round(avg(margem_pct), 4) AS margem_pct_media   -- média de percentuais: dá o mesmo peso a internações pequenas e grandes
FROM hospital_margin_demo.gold.fato_margem_hospitalar
GROUP BY mes_competencia;

-- Selo "Deprecated": a view continua funcionando, mas o Catalog Explorer avisa que ela não deve ser usada
ALTER VIEW hospital_margin_demo.gold.vw_margem_mensal_legado SET TAGS ('system.certification_status' = 'deprecated');

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **A tag de certificação só aceita dois valores:** `certified` e `deprecated`. Ela é uma *governed tag* com valores permitidos.
-- MAGIC Se alguém tentar outro valor, como `'obsoleto'`, o Unity Catalog recusa com o erro
-- MAGIC `UC_TAG_POLICY_VALUE_NOT_ALLOWED ... Allowed values: [certified, deprecated]`. Experimente tirando o comentário da linha abaixo.

-- COMMAND ----------

-- Tire o "--" para ver o erro (depois coloque de volta):
-- ALTER VIEW hospital_margin_demo.gold.vw_margem_mensal_legado SET TAGS ('system.certification_status' = 'obsoleto');

-- Compare a view legada com a fonte certificada: a diferença é o erro da média de percentuais
WITH certificada AS (
    SELECT mes_competencia, MEASURE(margem_pct) AS margem_pct
    FROM hospital_margin_demo.gold.mv_margem_hospitalar
    GROUP BY ALL
)
SELECT
    l.mes_competencia,
    round(l.margem_pct_media * 100, 1)  AS margem_pct_legado,
    round(c.margem_pct * 100, 1)        AS margem_pct_certificada
FROM hospital_margin_demo.gold.vw_margem_mensal_legado AS l
JOIN certificada AS c
  ON c.mes_competencia = l.mes_competencia
ORDER BY l.mes_competencia;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Passo 5 — Associar cada ativo ao seu subdomínio
-- MAGIC ``SET TAG ON <TABLE|VIEW> <ativo> `<chave>` `` aplica uma tag só com chave. As crases (`` ` ``) são obrigatórias
-- MAGIC porque a chave tem espaço, barra e acento. Um ativo pode pertencer a **mais de um** subdomínio: basta aplicar as duas tags.
-- MAGIC A view obsoleta também recebe subdomínio: assim quem a encontrar no Discover vê o selo **Deprecated** e o comentário com a fonte oficial.

-- COMMAND ----------

-- Silver: cada tabela no subdomínio do seu assunto (silver.pacientes fica sem tag: será tratada na sessão de governança)
SET TAG ON TABLE hospital_margin_demo.silver.internacoes `Hospital Data Matter/Operações Assistenciais`;
SET TAG ON TABLE hospital_margin_demo.silver.faturamento `Hospital Data Matter/Financeiro`;
SET TAG ON TABLE hospital_margin_demo.silver.glosas      `Hospital Data Matter/Financeiro`;
SET TAG ON TABLE hospital_margin_demo.silver.custos      `Hospital Data Matter/Financeiro`;

-- Gold: tabelas de negócio
SET TAG ON TABLE hospital_margin_demo.gold.fato_margem_hospitalar   `Hospital Data Matter/Financeiro`;
SET TAG ON TABLE hospital_margin_demo.gold.fato_margem_hospitalar   `Hospital Data Matter/Operações Assistenciais`;  -- também tem permanência e complexidade
SET TAG ON TABLE hospital_margin_demo.gold.resumo_financeiro_mensal `Hospital Data Matter/Financeiro`;
SET TAG ON TABLE hospital_margin_demo.gold.resumo_operadoras        `Hospital Data Matter/Financeiro`;

-- Metric View: atende os dois subdomínios
SET TAG ON VIEW hospital_margin_demo.gold.mv_margem_hospitalar `Hospital Data Matter/Financeiro`;
SET TAG ON VIEW hospital_margin_demo.gold.mv_margem_hospitalar `Hospital Data Matter/Operações Assistenciais`;

-- View obsoleta: continua no subdomínio, com o selo Deprecated
SET TAG ON VIEW hospital_margin_demo.gold.vw_margem_mensal_legado `Hospital Data Matter/Financeiro`;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Passo 6 — Corrigindo um subdomínio errado
-- MAGIC Se um ativo foi colocado no subdomínio errado, use `UNSET TAG`. Remover uma tag que não existe **não dá erro**,
-- MAGIC então a instrução abaixo pode ser executada quantas vezes quiser. Neste exemplo, garantimos que a Bronze não esteja em nenhum subdomínio.

-- COMMAND ----------

-- A Bronze não pertence a domínio nenhum: removemos por garantia (não falha se a tag não existir)
UNSET TAG ON TABLE hospital_margin_demo.bronze.faturamento `Hospital Data Matter/Financeiro`;
UNSET TAG ON TABLE hospital_margin_demo.bronze.glosas      `Hospital Data Matter/Financeiro`;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## D. Validação

-- COMMAND ----------

-- 1) Visão por ativo: certificação e subdomínios.
-- Esperado: 4 ativos Gold "certified", 1 view "deprecated", Silver só com subdomínio, Bronze e silver.pacientes ausentes.
SELECT
    schema_name,
    table_name,
    max(CASE WHEN tag_name = 'system.certification_status' THEN tag_value END)                AS certificacao,
    array_join(array_sort(collect_list(
        CASE WHEN tag_name LIKE 'Hospital Data Matter/%' THEN replace(tag_name, 'Hospital Data Matter/', '') END
    )), ', ')                                                                                  AS subdominios
FROM hospital_margin_demo.information_schema.table_tags
GROUP BY schema_name, table_name
ORDER BY schema_name, table_name;

-- COMMAND ----------

-- 2) Contagens de controle. Esperado: 4 certificados, 1 obsoleto, 11 tags de subdomínio, 0 tags na Bronze.
SELECT
    count_if(tag_name = 'system.certification_status' AND tag_value = 'certified')   AS ativos_certificados,
    count_if(tag_name = 'system.certification_status' AND tag_value = 'deprecated')  AS ativos_obsoletos,
    count_if(tag_name LIKE 'Hospital Data Matter/%')                                AS tags_de_subdominio,
    count_if(schema_name = 'bronze')                                                AS tags_na_bronze
FROM hospital_margin_demo.information_schema.table_tags;

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC <div style="border-left: 4px solid #2e7d32; background: #f7fdf4; padding: 14px 18px; border-radius: 4px; margin: 16px 0;">
-- MAGIC   <strong style="display:block; color:#1b5e20; margin-bottom:6px; font-size: 1.1em;">O que observar</strong>
-- MAGIC   <div style="color:#333;">
-- MAGIC     <p style="margin: 6px 0;">abra o <strong>Catalog Explorer</strong>, procure <code>fato_margem_hospitalar</code> e veja o selo <strong>Certified</strong>; procure <code>vw_margem_mensal_legado</code> e veja o selo <strong>Deprecated</strong> e o comentário apontando para a Metric View. Em <strong>Discover → Domains → Hospital Data Matter</strong>, os ativos aparecem agrupados nos subdomínios Financeiro e Operações Assistenciais. Genie Agents e Pages não são certificados nem associados a domínio por SQL: isso é feito na interface.</p>
-- MAGIC   </div>
-- MAGIC </div>

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC ## E. Exercício para o aluno
-- MAGIC
-- MAGIC <div style="border-left: 4px solid #d97706; background: #fffbeb; padding: 14px 18px; border-radius: 4px; margin: 16px 0;">
-- MAGIC   <strong style="display:block; color:#92400e; margin-bottom:6px; font-size: 1.1em;">Sua tarefa</strong>
-- MAGIC   <div style="color:#333;">
-- MAGIC     <p style="margin: 6px 0;">O custo assistencial também interessa à equipe clínica. Acrescente <code>silver.custos</code> ao subdomínio <code>Operações Assistenciais</code> tirando o comentário da instrução abaixo e rode de novo a validação 2. <strong>Quantas tags de subdomínio aparecem agora?</strong> Depois desfaça a mudança com <code>UNSET TAG</code> e confira que a contagem volta ao valor original.</p>
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
-- MAGIC <p>Depois do <code>SET TAG</code>, a validação 2 mostra <strong>12</strong> tags de subdomínio (eram 11). Com o <code>UNSET TAG</code>, a contagem volta para <strong>11</strong>. Certificados (4) e obsoletos (1) não mudam: subdomínio e certificação são independentes.</p>
-- MAGIC     </div>
-- MAGIC   </div>
-- MAGIC </details>

-- COMMAND ----------

-- Exercício: tire o "--" da linha abaixo, execute a célula e rode de novo a validação 2.
-- SET TAG ON TABLE hospital_margin_demo.silver.custos `Hospital Data Matter/Operações Assistenciais`;

-- Para desfazer, tire o "--" desta linha e execute:
-- UNSET TAG ON TABLE hospital_margin_demo.silver.custos `Hospital Data Matter/Operações Assistenciais`;

SELECT 'Edite as linhas acima para fazer o exercício' AS instrucao;
