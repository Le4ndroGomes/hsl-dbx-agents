-- Databricks notebook source
-- MAGIC %md
-- MAGIC ![DB Academy](./Includes/images/db-academy.png)

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC # Hospital Data Matter — Sessão 01: Camada Bronze (dados sintéticos)
-- MAGIC
-- MAGIC ## A. Objetivo
-- MAGIC Ao final desta sessão você saberá:
-- MAGIC - criar **schemas** e **tabelas Delta** no Unity Catalog;
-- MAGIC - gerar registros sintéticos usando apenas SQL (`range`, `hash`, `CASE WHEN`);
-- MAGIC - usar funções de data (`date_add`) para montar uma linha do tempo coerente;
-- MAGIC - relacionar tabelas por chaves (`internacao_id`).
-- MAGIC
-- MAGIC ## B. Contexto de negócio
-- MAGIC O **Hospital Data Matter** tem 4 unidades e atende 5 operadoras de saúde.
-- MAGIC A receita está **subindo**, mas a **margem de contribuição está caindo**. Para investigar,
-- MAGIC vamos simular 12 meses de internações (nov/2025 a out/2026) vindas dos sistemas do hospital:
-- MAGIC
-- MAGIC <div style="max-width: 1000px; margin: 0 auto;">
-- MAGIC <table style="width: 100%; border-collapse: collapse; line-height: 1.6;">
-- MAGIC   <tr style="background: #1B3139; color: #fff;"><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Tabela Bronze</th><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Sistema de origem</th><th style="padding: 12px 16px; text-align: left; border: 1px solid #2a4a54; font-size: 20px !important;">Grão (1 linha = ...)</th></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>internacoes</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Prontuário (EHR)</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">uma internação</td></tr>
-- MAGIC   <tr style="background: #fff;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>faturamento</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Faturamento</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">um item cobrado da operadora</td></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>glosas</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Contas médicas</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">um item recusado (glosado) pela operadora</td></tr>
-- MAGIC   <tr style="background: #fff;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>custos</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Custos</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">um componente de custo da internação</td></tr>
-- MAGIC   <tr style="background: #F9F7F4;"><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;"><code>pacientes</code></td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">Cadastro de pacientes (EHR)</td><td style="padding: 12px 16px; border: 1px solid #E8E3DC; font-size: 20px !important;">um paciente (nome, e-mail, sexo, nascimento, cidade)</td></tr>
-- MAGIC </table>
-- MAGIC </div>
-- MAGIC
-- MAGIC A partir de **agosto/2026** inserimos, de propósito, três anomalias (é o nosso "gabarito"):
-- MAGIC 1. **Glosas de OPME** (órteses, próteses e materiais especiais): a operadora *Aurora Seguros* passa a recusar itens de OPME por falta de autorização prévia.
-- MAGIC 2. **Permanência maior**: pacientes de **alta complexidade** da *Unidade Sul* ficam 6 dias a mais internados.
-- MAGIC 3. **Mix de procedimentos caro**: a fatia de procedimentos de alta complexidade (alto custo e margem menor) sobe de 15% para 22%.
-- MAGIC
-- MAGIC <div style="border-left: 4px solid #1976d2; background: #f0f7ff; padding: 14px 18px; border-radius: 4px; margin: 16px 0;">
-- MAGIC   <strong style="display:block; color:#0d47a1; margin-bottom:6px; font-size: 1.1em;">Observação</strong>
-- MAGIC   <div style="color:#333;">
-- MAGIC     <p style="margin: 6px 0;">Os dados são <strong>100% sintéticos</strong>: nomes e e-mails são combinações geradas por SQL e não correspondem a pessoas reais. Os e-mails usam o domínio <code>example.com</code>, reservado para exemplos, que nunca pertence a ninguém.</p>
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

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC ## Arquitetura que vamos construir
-- MAGIC
-- MAGIC <span style="color:#991b1b; font-weight:bold; font-style:italic;">Se o diagrama abaixo não aparecer, clique na célula e depois fora dela: isso carrega a biblioteca Mermaid.</span>
-- MAGIC
-- MAGIC <div style="max-width: 1000px; margin: 0 auto;">
-- MAGIC <div class="mermaid">
-- MAGIC flowchart LR
-- MAGIC     subgraph BRONZE["<b>BRONZE (Sessão 01)</b>"]
-- MAGIC         B0["pacientes"]
-- MAGIC         B1["internacoes"]
-- MAGIC         B2["faturamento"]
-- MAGIC         B3["glosas"]
-- MAGIC         B4["custos"]
-- MAGIC     end
-- MAGIC     subgraph SILVER["<b>SILVER (Sessão 02)</b>"]
-- MAGIC         S0["pacientes<br/><small>dados pessoais ficam aqui</small>"]
-- MAGIC         S1["internacoes"]
-- MAGIC         S2["faturamento"]
-- MAGIC         S3["glosas"]
-- MAGIC         S4["custos"]
-- MAGIC     end
-- MAGIC     subgraph GOLD["<b>GOLD (Sessões 03 e 04)</b>"]
-- MAGIC         G1["fato_margem_hospitalar<br/><small>1 linha por internação</small>"]
-- MAGIC         G2["resumo_financeiro_mensal"]
-- MAGIC         G3["resumo_operadoras"]
-- MAGIC     end
-- MAGIC     subgraph SEM["<b>SEMÂNTICA E GOVERNANÇA (Sessões 05 a 07)</b>"]
-- MAGIC         M1["mv_margem_hospitalar<br/><small>Metric View</small>"]
-- MAGIC         P1["Pages<br/><small>definições de negócio</small>"]
-- MAGIC         C1["Certificação e domínios"]
-- MAGIC     end
-- MAGIC     B0 --> S0
-- MAGIC     S0 -.-|"paciente_id"| S1
-- MAGIC     B1 --> S1
-- MAGIC     B2 --> S2
-- MAGIC     B3 --> S3
-- MAGIC     B4 --> S4
-- MAGIC     S1 --> G1
-- MAGIC     S2 --> G1
-- MAGIC     S3 --> G1
-- MAGIC     S4 --> G1
-- MAGIC     G1 --> G2
-- MAGIC     G1 --> G3
-- MAGIC     G1 --> M1
-- MAGIC     M1 --> P1
-- MAGIC     M1 --> C1
-- MAGIC     classDef bronze fill:#FFF3E0,stroke:#e65100,stroke-width:2px,color:#333
-- MAGIC     classDef silver fill:#E3F2FD,stroke:#1565c0,stroke-width:2px,color:#333
-- MAGIC     classDef gold fill:#FFFDE7,stroke:#f9a825,stroke-width:2px,color:#333
-- MAGIC     classDef sem fill:#F3E5F5,stroke:#7b1fa2,stroke-width:2px,color:#333
-- MAGIC     class B0,B1,B2,B3,B4 bronze
-- MAGIC     class S0,S1,S2,S3,S4 silver
-- MAGIC     class G1,G2,G3 gold
-- MAGIC     class M1,P1,C1 sem
-- MAGIC     style BRONZE fill:#FFF8E1,stroke:#e65100,stroke-width:2px
-- MAGIC     style SILVER fill:#E8EAF6,stroke:#1565c0,stroke-width:2px
-- MAGIC     style GOLD fill:#FFFDE7,stroke:#f9a825,stroke-width:2px
-- MAGIC     style SEM fill:#FAF5FB,stroke:#7b1fa2,stroke-width:2px
-- MAGIC </div>
-- MAGIC </div>
-- MAGIC
-- MAGIC <script type="module">
-- MAGIC import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.esm.min.mjs";
-- MAGIC mermaid.initialize({
-- MAGIC   startOnLoad: true,
-- MAGIC   theme: "base",
-- MAGIC   themeVariables: {
-- MAGIC     background: "#FFFFFF",
-- MAGIC     lineColor: "#1B5162"
-- MAGIC   }
-- MAGIC });
-- MAGIC </script>

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## C. Implementação em SQL
-- MAGIC ### Passo 1 — Catálogo e schemas
-- MAGIC No Unity Catalog os dados ficam organizados em **catálogo → schema → tabela**.
-- MAGIC Usamos um schema por camada da arquitetura Medallion.

-- COMMAND ----------

-- Se você não tiver permissão para criar catálogos, peça ao instrutor
-- ou troque "hospital_margin_demo" por um catálogo onde você possa criar schemas.
CREATE CATALOG IF NOT EXISTS hospital_margin_demo;

CREATE SCHEMA IF NOT EXISTS hospital_margin_demo.bronze COMMENT 'Dados brutos, como chegam dos sistemas de origem';
CREATE SCHEMA IF NOT EXISTS hospital_margin_demo.silver COMMENT 'Dados limpos e padronizados';
CREATE SCHEMA IF NOT EXISTS hospital_margin_demo.gold   COMMENT 'Tabelas de negócio prontas para análise';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Passo 2 — Pacientes
-- MAGIC O cadastro de pacientes tem os **dados pessoais**: nome, e-mail, sexo, data de nascimento e cidade.
-- MAGIC - `range(0, 8000)` cria 8.000 pacientes; um mesmo paciente pode ter várias internações.
-- MAGIC - `element_at(array(...), n)` escolhe o n-ésimo nome de uma lista. Combinando nome e dois sobrenomes, temos milhares de nomes diferentes.
-- MAGIC - O e-mail é montado com `lower` e `translate` (tira os acentos: "João" vira "joao").
-- MAGIC - Pacientes com número par são do sexo feminino; os múltiplos de 4 nasceram entre 1984 e 2003 (serão usados nos partos).
-- MAGIC
-- MAGIC Esta é a única tabela com dados pessoais. Ela vai até a **Silver**; a Gold não recebe nenhum dado do paciente.

-- COMMAND ----------

CREATE OR REPLACE TABLE hospital_margin_demo.bronze.pacientes
COMMENT 'Bronze | 1 linha por paciente (cadastro). Dados pessoais sintéticos.'
AS
WITH sorteios AS (
    SELECT
        id                                                AS numero,
        concat('PAC-', lpad(CAST(id AS STRING), 6, '0'))  AS paciente_id,      -- mesmo formato usado nas internações
        CASE WHEN pmod(id, 2) = 0 THEN 'F' ELSE 'M' END   AS sexo,
        pmod(hash(id, 'nome'),       20)                  AS sorteio_nome,
        pmod(hash(id, 'sobrenome1'), 30)                  AS sorteio_sobrenome1,
        pmod(hash(id, 'sobrenome2'), 30)                  AS sorteio_sobrenome2,
        pmod(hash(id, 'formato'),    20)                  AS sorteio_formato
    FROM range(0, 8000)
),
nomes AS (
    SELECT
        *,
        CASE sexo
            WHEN 'F' THEN element_at(array('Ana', 'Maria', 'Juliana', 'Fernanda', 'Patrícia', 'Camila', 'Beatriz', 'Larissa', 'Mariana', 'Aline',
                                           'Gabriela', 'Letícia', 'Bruna', 'Amanda', 'Carolina', 'Vanessa', 'Débora', 'Renata', 'Luana', 'Helena'), sorteio_nome + 1)
            ELSE          element_at(array('João', 'José', 'Carlos', 'Paulo', 'Lucas', 'Rafael', 'Bruno', 'Gustavo', 'Felipe', 'Rodrigo',
                                           'Marcelo', 'André', 'Thiago', 'Diego', 'Leonardo', 'Matheus', 'Eduardo', 'Vinícius', 'Ricardo', 'Antônio'), sorteio_nome + 1)
        END AS primeiro_nome,
        -- Mesma lista de 30 sobrenomes para o nome do meio e o último sobrenome
        element_at(array('Silva', 'Santos', 'Oliveira', 'Souza', 'Rodrigues', 'Ferreira', 'Alves', 'Pereira', 'Lima', 'Gomes',
                         'Costa', 'Ribeiro', 'Martins', 'Carvalho', 'Almeida', 'Lopes', 'Soares', 'Fernandes', 'Vieira', 'Barbosa',
                         'Rocha', 'Dias', 'Nascimento', 'Andrade', 'Moreira', 'Nunes', 'Marques', 'Machado', 'Mendes', 'Freitas'), sorteio_sobrenome1 + 1) AS sobrenome_meio,
        element_at(array('Silva', 'Santos', 'Oliveira', 'Souza', 'Rodrigues', 'Ferreira', 'Alves', 'Pereira', 'Lima', 'Gomes',
                         'Costa', 'Ribeiro', 'Martins', 'Carvalho', 'Almeida', 'Lopes', 'Soares', 'Fernandes', 'Vieira', 'Barbosa',
                         'Rocha', 'Dias', 'Nascimento', 'Andrade', 'Moreira', 'Nunes', 'Marques', 'Machado', 'Mendes', 'Freitas'),
                   -- se o sorteio repetir o sobrenome do meio, pega o próximo da lista (evita 'Mendes Mendes')
                   pmod(sorteio_sobrenome2 + CASE WHEN sorteio_sobrenome2 = sorteio_sobrenome1 THEN 1 ELSE 0 END, 30) + 1) AS sobrenome
    FROM sorteios
),
cadastro AS (
    SELECT
        *,
        concat(primeiro_nome, ' ', sobrenome_meio, ' ', sobrenome) AS nome_completo,
        -- e-mail: nome.sobrenome + número, sem acentos (translate troca cada letra acentuada pela letra simples)
        concat(translate(lower(primeiro_nome), 'áâãéêíóôõúç', 'aaaeeiooouc'), '.',
               translate(lower(sobrenome),     'áâãéêíóôõúç', 'aaaeeiooouc'),
               numero, '@example.com')                     AS email_padrao
    FROM nomes
)
SELECT
    paciente_id,
    -- Problema de qualidade proposital: 5% dos nomes chegam em MAIÚSCULAS e com espaço sobrando
    CASE WHEN sorteio_formato = 0 THEN concat(upper(nome_completo), '  ') ELSE nome_completo END AS nome,
    -- Problema de qualidade proposital: outros 5% dos e-mails chegam em MAIÚSCULAS
    CASE WHEN sorteio_formato = 1 THEN upper(email_padrao) ELSE email_padrao END                 AS email,
    sexo,
    CASE WHEN pmod(numero, 4) = 0
         THEN date_add(DATE'1984-01-01', pmod(hash(numero, 'nascimento'), 7300))    -- nascidas entre 1984 e 2003
         ELSE date_add(DATE'1940-01-01', pmod(hash(numero, 'nascimento'), 24000))   -- nascidos entre 1940 e 2005
    END AS data_nascimento,
    element_at(array('São Paulo', 'Santo André', 'São Bernardo do Campo', 'Campinas', 'Guarulhos', 'Osasco'),
               pmod(hash(numero, 'cidade'), 6) + 1) AS cidade
FROM cadastro;

-- COMMAND ----------

SELECT *
FROM hospital_margin_demo.bronze.pacientes
ORDER BY paciente_id
LIMIT 10;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Passo 3 — Internações
-- MAGIC **Como gerar dados sem `rand()`?** `range(1, 10001)` cria os números de 1 a 10.000 (um por internação).
-- MAGIC `hash(id, 'texto')` transforma cada número em um valor "embaralhado", mas **sempre igual** para a mesma entrada.
-- MAGIC `pmod(valor, 100)` converte esse valor em um sorteio de 0 a 99. Resultado: dados que parecem aleatórios,
-- MAGIC mas que se repetem exatamente a cada execução (ótimo para a sessão e para testes).
-- MAGIC
-- MAGIC Para escalar para 100 mil internações, troque apenas `range(1, 10001)` por `range(1, 100001)`.

-- COMMAND ----------

CREATE OR REPLACE TABLE hospital_margin_demo.bronze.internacoes
COMMENT 'Bronze | 1 linha por internação (sistema de prontuário). Dados sintéticos.'
AS
WITH sorteios AS (
    -- Um "sorteio" fixo de 0 a 99 para cada característica da internação
    SELECT
        id                                                   AS internacao_id,
        date_add(DATE'2025-11-01', pmod(hash(id, 'data'), 365)) AS data_admissao,  -- 365 dias: 01/11/2025 a 31/10/2026
        pmod(hash(id, 'unidade'),   4)   AS sorteio_unidade,
        pmod(hash(id, 'operadora'), 5)   AS sorteio_operadora,
        pmod(hash(id, 'mix'),       100) AS sorteio_mix,
        pmod(hash(id, 'proc'),      100) AS sorteio_proc,
        pmod(hash(id, 'perm'),      5)   AS sorteio_perm,     -- 0 a 4 dias extras de variação natural
        pmod(hash(id, 'formato'),   20)  AS sorteio_formato
    FROM range(1, 10001)
),
clinico AS (
    SELECT
        internacao_id,
        data_admissao,
        sorteio_perm,
        sorteio_formato,
        CASE sorteio_unidade
            WHEN 0 THEN 'Unidade Centro'
            WHEN 1 THEN 'Unidade Sul'
            WHEN 2 THEN 'Unidade Norte'
            ELSE        'Unidade Oeste'
        END AS unidade,
        CASE sorteio_operadora
            WHEN 0 THEN 'Vitalis Saúde'
            WHEN 1 THEN 'Aurora Seguros'
            WHEN 2 THEN 'Coopermed'
            WHEN 3 THEN 'Servidores Saúde'
            ELSE        'Horizonte Saúde'
        END AS operadora,
        CASE
            -- ANOMALIA 3 (mix caro): a partir de ago/2026, 22% das internações (antes 15%)
            -- são procedimentos de alta complexidade, que custam mais e têm margem menor.
            WHEN sorteio_mix < CASE WHEN data_admissao >= DATE'2026-08-01' THEN 22 ELSE 15 END THEN
                CASE pmod(sorteio_proc, 3)
                    WHEN 0 THEN 'Artroplastia de quadril'
                    WHEN 1 THEN 'Angioplastia com stent'
                    ELSE        'Cirurgia cardíaca valvar'
                END
            ELSE
                CASE pmod(sorteio_proc, 5)
                    WHEN 0 THEN 'Colecistectomia'
                    WHEN 1 THEN 'Apendicectomia'
                    WHEN 2 THEN 'Tratamento de pneumonia'
                    WHEN 3 THEN 'Parto normal'
                    ELSE        'Tratamento de infecção urinária'
                END
        END AS procedimento
    FROM sorteios
),
com_complexidade AS (
    SELECT
        *,
        CASE
            WHEN procedimento IN ('Artroplastia de quadril', 'Angioplastia com stent', 'Cirurgia cardíaca valvar') THEN 'ALTA'
            WHEN procedimento IN ('Colecistectomia', 'Apendicectomia', 'Tratamento de pneumonia')                 THEN 'MEDIA'
            ELSE 'BAIXA'
        END AS complexidade
    FROM clinico
)
SELECT
    internacao_id,
    -- paciente_id liga a internação ao cadastro (bronze.pacientes).
    -- Parto normal só é atribuído a pacientes de número múltiplo de 4 (sexo feminino, nascidas entre 1984 e 2003).
    concat('PAC-', lpad(CAST(
        CASE WHEN procedimento = 'Parto normal' THEN 4 * pmod(hash(internacao_id, 'paciente'), 2000)
             ELSE pmod(hash(internacao_id, 'paciente'), 8000)
        END AS STRING), 6, '0')) AS paciente_id,
    unidade,
    -- Problema de qualidade proposital: 5% das linhas chegam com a operadora em MAIÚSCULAS e com espaço sobrando.
    -- A camada Silver vai padronizar esse texto.
    CASE WHEN sorteio_formato = 0 THEN concat(upper(operadora), ' ') ELSE operadora END AS operadora,
    procedimento,
    complexidade,
    data_admissao,
    -- Permanência = dias base pela complexidade + variação natural de 0 a 4 dias
    date_add(
        data_admissao,
        CASE complexidade WHEN 'BAIXA' THEN 1 WHEN 'MEDIA' THEN 2 ELSE 5 END
        + sorteio_perm
        -- ANOMALIA 2 (permanência): Unidade Sul + alta complexidade + admissão a partir de ago/2026 = +6 dias
        + CASE WHEN unidade = 'Unidade Sul' AND complexidade = 'ALTA' AND data_admissao >= DATE'2026-08-01' THEN 6 ELSE 0 END
    ) AS data_alta
FROM com_complexidade;

-- COMMAND ----------

-- Problema de qualidade proposital: o sistema de origem também enviou 10 internações de TESTE
-- com data de alta ANTERIOR à admissão. A camada Silver deve descartá-las.
-- (INSERT INTO acrescenta linhas a uma tabela que já existe.)
INSERT INTO hospital_margin_demo.bronze.internacoes
SELECT
    id                                      AS internacao_id,
    'PAC-TESTE'                             AS paciente_id,
    'Unidade Centro'                        AS unidade,
    'Vitalis Saúde'                         AS operadora,
    'Parto normal'                          AS procedimento,
    'BAIXA'                                 AS complexidade,
    DATE'2026-03-10'                        AS data_admissao,
    DATE'2026-03-01'                        AS data_alta        -- alta antes da admissão: inválido!
FROM range(900001, 900011);

-- COMMAND ----------

-- Amostra: veja como cada internação tem unidade, operadora, procedimento e datas
SELECT *
FROM hospital_margin_demo.bronze.internacoes
ORDER BY internacao_id
LIMIT 10;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Passo 4 — Faturamento
-- MAGIC Cada internação gera de 3 a 4 itens cobrados da operadora: **diárias**, **procedimento**,
-- MAGIC **materiais e medicamentos (MATMED)** e, nos procedimentos de alta complexidade, **OPME**.
-- MAGIC
-- MAGIC - A tabela de preços é escrita direto no SQL com `VALUES` (8 procedimentos).
-- MAGIC - `explode(array(...))` transforma 1 linha de internação em 4 linhas de item.
-- MAGIC - **Regra contratual:** as operadoras pagam **no máximo 10 diárias** por internação. Dias além disso viram custo sem receita.
-- MAGIC - O `item_id` é montado a partir do `internacao_id` (ex.: internação 25, um parto normal sem OPME → itens 251, 252 e 253), então todo item tem "pai".

-- COMMAND ----------

CREATE OR REPLACE TABLE hospital_margin_demo.bronze.faturamento
COMMENT 'Bronze | 1 linha por item faturado para a operadora. Dados sintéticos.'
AS
WITH tabela_precos (procedimento, valor_procedimento, valor_opme, valor_diaria, valor_matmed_dia) AS (
    VALUES
        ('Artroplastia de quadril',          9000, 18000, 3200, 1500),
        ('Angioplastia com stent',           8000, 15000, 3200, 1500),
        ('Cirurgia cardíaca valvar',        22000, 20000, 3200, 1500),
        ('Colecistectomia',                  4500,     0, 1700,  600),
        ('Apendicectomia',                   3800,     0, 1700,  600),
        ('Tratamento de pneumonia',          2000,     0, 1700,  600),
        ('Parto normal',                     2500,     0, 1200,  300),
        ('Tratamento de infecção urinária',  1200,     0, 1200,  300)
),
internacao_com_preco AS (
    SELECT
        i.internacao_id,
        i.data_alta,
        datediff(i.data_alta, i.data_admissao) AS dias,
        p.*
    FROM hospital_margin_demo.bronze.internacoes AS i
    JOIN tabela_precos AS p
      ON p.procedimento = i.procedimento
    WHERE i.data_alta >= i.data_admissao          -- não faturamos as internações de teste
),
itens AS (
    -- 1 internação → 4 linhas, uma por tipo de item
    SELECT *, explode(array('DIARIA', 'PROCEDIMENTO', 'MATMED', 'OPME')) AS tipo_item
    FROM internacao_com_preco
)
SELECT
    internacao_id * 10 + CASE tipo_item WHEN 'DIARIA' THEN 1 WHEN 'PROCEDIMENTO' THEN 2 WHEN 'MATMED' THEN 3 ELSE 4 END AS item_id,
    internacao_id,
    -- Problema de qualidade proposital: o sistema grava o tipo do item em minúsculas
    lower(tipo_item) AS tipo_item,
    CASE tipo_item
        WHEN 'DIARIA'       THEN least(dias, 10)                  -- limite contratual de 10 diárias
        WHEN 'MATMED'       THEN dias
        ELSE 1
    END AS quantidade,
    -- Valores chegam como DOUBLE (ponto flutuante); a Silver converte para DECIMAL(18,2)
    CAST(CASE tipo_item
        WHEN 'DIARIA'       THEN least(dias, 10) * valor_diaria
        WHEN 'PROCEDIMENTO' THEN valor_procedimento
        WHEN 'MATMED'       THEN dias * valor_matmed_dia
        ELSE valor_opme
    END AS DOUBLE) AS valor_item,
    date_add(data_alta, 5) AS data_faturamento                 -- conta enviada 5 dias após a alta
FROM itens
WHERE NOT (tipo_item = 'OPME' AND valor_opme = 0);           -- só existe item de OPME quando o procedimento usa OPME

-- COMMAND ----------

-- Problema de qualidade proposital: 20 lançamentos de teste com valor zero.
INSERT INTO hospital_margin_demo.bronze.faturamento
SELECT
    9000000000 + id     AS item_id,
    id                  AS internacao_id,      -- pertencem a internações reais
    'taxa teste'        AS tipo_item,
    1                   AS quantidade,
    CAST(0 AS DOUBLE)   AS valor_item,
    DATE'2026-01-15'    AS data_faturamento
FROM range(1, 21);

-- COMMAND ----------

SELECT *
FROM hospital_margin_demo.bronze.faturamento
WHERE internacao_id IN (1, 2, 3)
ORDER BY item_id;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Passo 5 — Glosas
-- MAGIC **Glosa** é quando a operadora se recusa a pagar um item cobrado. Toda glosa aponta para um **item do faturamento**.
-- MAGIC - Situação normal: 8% dos itens são glosados em 50% do valor (motivos administrativos variados).
-- MAGIC - **ANOMALIA 1:** a partir de ago/2026, a *Aurora Seguros* recusa 60% dos itens de OPME **integralmente**,
-- MAGIC   por "falta de autorização prévia" (mudança na regra de autorização da operadora).

-- COMMAND ----------

CREATE OR REPLACE TABLE hospital_margin_demo.bronze.glosas
COMMENT 'Bronze | 1 linha por item glosado pela operadora. Dados sintéticos.'
AS
WITH itens AS (
    SELECT
        f.item_id,
        f.internacao_id,
        f.tipo_item,
        f.valor_item,
        f.data_faturamento,
        pmod(hash(f.item_id, 'glosa'), 100) AS sorteio_glosa,
        -- ANOMALIA 1: Aurora Seguros + item de OPME + internação a partir de ago/2026
        (i.operadora = 'Aurora Seguros' AND f.tipo_item = 'opme' AND i.data_admissao >= DATE'2026-08-01') AS regra_autorizacao_opme
    FROM hospital_margin_demo.bronze.faturamento AS f
    JOIN hospital_margin_demo.bronze.internacoes AS i
      ON i.internacao_id = f.internacao_id
    WHERE f.valor_item > 0
)
SELECT
    item_id + 500000000000 AS glosa_id,          -- id próprio da glosa, derivado do item glosado
    item_id,
    internacao_id,
    CASE
        WHEN regra_autorizacao_opme     THEN 'Falta de autorização prévia de OPME'
        WHEN sorteio_glosa = 7          THEN NULL   -- problema proposital: motivo não informado
        WHEN pmod(sorteio_glosa, 3) = 0 THEN 'Cobrança em duplicidade'
        WHEN pmod(sorteio_glosa, 3) = 1 THEN 'Divergência de quantidade'
        ELSE                                 'Item não coberto pelo contrato'
    END AS motivo_glosa,
    CASE WHEN regra_autorizacao_opme THEN valor_item          -- recusa total do item
         ELSE round(valor_item * 0.5, 2)                       -- recusa parcial (50%)
    END AS valor_glosa,
    date_add(data_faturamento, 30) AS data_glosa              -- a operadora responde ~30 dias após a cobrança
FROM itens
WHERE sorteio_glosa < CASE WHEN regra_autorizacao_opme THEN 60 ELSE 8 END;

-- COMMAND ----------

SELECT *
FROM hospital_margin_demo.bronze.glosas
ORDER BY glosa_id
LIMIT 10;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Passo 6 — Custos
-- MAGIC O sistema de custos registra quanto o hospital **gastou** em cada internação, nos mesmos 4 componentes.
-- MAGIC Diferença importante: o custo da diária é contado em **todos** os dias internados (sem o limite de 10 do faturamento).
-- MAGIC Por isso a anomalia 2 (permanência maior) aumenta o custo mais do que a receita.

-- COMMAND ----------

CREATE OR REPLACE TABLE hospital_margin_demo.bronze.custos
COMMENT 'Bronze | 1 linha por componente de custo da internação. Dados sintéticos.'
AS
WITH tabela_custos (procedimento, custo_procedimento, custo_opme, custo_diaria, custo_matmed_dia) AS (
    VALUES
        ('Artroplastia de quadril',          7200, 15200, 2400, 1150),
        ('Angioplastia com stent',           6450, 12600, 2400, 1150),
        ('Cirurgia cardíaca valvar',        18000, 16900, 2400, 1150),
        ('Colecistectomia',                  2750,     0, 1250,  430),
        ('Apendicectomia',                   2300,     0, 1250,  430),
        ('Tratamento de pneumonia',          1250,     0, 1250,  430),
        ('Parto normal',                     1450,     0,  860,  210),
        ('Tratamento de infecção urinária',   720,     0,  860,  210)
),
internacao_com_custo AS (
    SELECT
        i.internacao_id,
        i.data_alta,
        datediff(i.data_alta, i.data_admissao) AS dias,
        c.*
    FROM hospital_margin_demo.bronze.internacoes AS i
    JOIN tabela_custos AS c
      ON c.procedimento = i.procedimento
    WHERE i.data_alta >= i.data_admissao
),
componentes AS (
    SELECT *, explode(array('DIARIA', 'PROCEDIMENTO', 'MATMED', 'OPME')) AS componente
    FROM internacao_com_custo
)
SELECT
    internacao_id * 10 + CASE componente WHEN 'DIARIA' THEN 1 WHEN 'PROCEDIMENTO' THEN 2 WHEN 'MATMED' THEN 3 ELSE 4 END AS custo_id,
    internacao_id,
    componente,
    CAST(CASE componente
        WHEN 'DIARIA'       THEN dias * custo_diaria             -- todos os dias geram custo
        WHEN 'PROCEDIMENTO' THEN custo_procedimento
        WHEN 'MATMED'       THEN dias * custo_matmed_dia
        ELSE custo_opme
    END AS DOUBLE) AS valor_custo,
    data_alta AS data_custo
FROM componentes
WHERE NOT (componente = 'OPME' AND custo_opme = 0);

-- COMMAND ----------

SELECT *
FROM hospital_margin_demo.bronze.custos
WHERE internacao_id IN (1, 2, 3)
ORDER BY custo_id;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## D. Validação

-- COMMAND ----------

-- 1) Quantas linhas cada tabela Bronze recebeu?
-- Esperado: 8.000 pacientes; 10.010 internações (10.000 + 10 de teste); faturamento com ~3,2 itens por internação.
SELECT 'pacientes' AS tabela, count(*) AS linhas FROM hospital_margin_demo.bronze.pacientes
UNION ALL SELECT 'internacoes', count(*) FROM hospital_margin_demo.bronze.internacoes
UNION ALL SELECT 'faturamento', count(*) FROM hospital_margin_demo.bronze.faturamento
UNION ALL SELECT 'glosas',      count(*) FROM hospital_margin_demo.bronze.glosas
UNION ALL SELECT 'custos',      count(*) FROM hospital_margin_demo.bronze.custos;

-- COMMAND ----------

-- 2) As internações estão espalhadas pelos 12 meses? Esperado: ~834 por mês em média (de 738 a 919).
SELECT
    date_trunc('MONTH', data_admissao) AS mes,
    count(*)                           AS internacoes
FROM hospital_margin_demo.bronze.internacoes
GROUP BY 1
ORDER BY 1;

-- COMMAND ----------

-- 3) Todo item faturado tem uma internação "pai"? Esperado: 0 itens órfãos.
SELECT count(*) AS itens_sem_internacao
FROM hospital_margin_demo.bronze.faturamento AS f
LEFT JOIN hospital_margin_demo.bronze.internacoes AS i
  ON i.internacao_id = f.internacao_id
WHERE i.internacao_id IS NULL;

-- COMMAND ----------

-- MAGIC %md-sandbox
-- MAGIC ## E. Exercício para o aluno
-- MAGIC
-- MAGIC <div style="border-left: 4px solid #d97706; background: #fffbeb; padding: 14px 18px; border-radius: 4px; margin: 16px 0;">
-- MAGIC   <strong style="display:block; color:#92400e; margin-bottom:6px; font-size: 1.1em;">Sua tarefa</strong>
-- MAGIC   <div style="color:#333;">
-- MAGIC     <p style="margin: 6px 0;">Na célula abaixo, conte as internações de <strong>alta complexidade</strong> por mês. Depois, troque <code>'ALTA'</code> por <code>'BAIXA'</code>. <strong>O que muda a partir de agosto/2026? Qual anomalia explica isso?</strong></p>
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
-- MAGIC <p>As internações de <strong>ALTA</strong> complexidade ficam entre 104 e 132 por mês de nov/2025 a jul/2026 e saltam para 184 a 215 por mês de ago a out/2026. As de <strong>BAIXA</strong> ficam estáveis: 257 a 312 por mês de nov/2025 a jul/2026 e 258 a 305 de ago a out/2026.</p><p>É a <strong>Anomalia 3 (mix mais caro)</strong>: a partir de agosto o gerador aumenta de 15% para 22% a fatia de procedimentos de alta complexidade.</p>
-- MAGIC     </div>
-- MAGIC   </div>
-- MAGIC </details>

-- COMMAND ----------

SELECT
    date_trunc('MONTH', data_admissao) AS mes,
    count(*)                           AS internacoes
FROM hospital_margin_demo.bronze.internacoes
WHERE complexidade = 'ALTA'          -- troque aqui
GROUP BY 1
ORDER BY 1;
