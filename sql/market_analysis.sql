-- =============================================================================
-- market_analysis.sql
-- Análises do panorama de mercado — segmento de Autogestão
--
-- Tabelas esperadas (ver src/run_sql_queries.py para como são carregadas):
--   fato_financeiro(REG_ANS, trimestre, receitas_totais, despesas_totais,
--                    receita_assistencial, sinistro_liquido,
--                    despesa_administrativa, faturado_bruto, glosa,
--                    coparticipacao, dado_confiavel, padrao_tipico)
--   dim_operadora(REG_ANS, operadora, nome_fantasia, uf, cidade, grupo_comparacao)
--   dim_trimestre(trimestre, ano, num_trimestre, ordem)
--
-- Dialeto: DuckDB (compatível com a maior parte do SQL padrão ANSI;
-- a função MEDIAN() usada aqui é uma extensão do DuckDB — em um banco sem
-- suporte nativo a mediana, seria necessário calcular via PERCENTILE_CONT
-- ou lógica de janela).
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. Evolução trimestral da sinistralidade do segmento
--    Duas leituras propositalmente diferentes lado a lado:
--    - "consolidada": soma de tudo / soma de tudo (ponderada pelo porte)
--    - "mediana": mediana da sinistralidade individual de cada operadora
--      (dá peso igual a operadoras grandes e pequenas)
-- -----------------------------------------------------------------------------
SELECT
    f.trimestre,
    d.ordem,
    SUM(f.sinistro_liquido) / SUM(f.receita_assistencial)          AS sinistralidade_consolidada,
    MEDIAN(f.sinistro_liquido / f.receita_assistencial)             AS sinistralidade_mediana,
    COUNT(*)                                                        AS operadoras_confiaveis
FROM fato_financeiro f
JOIN dim_trimestre d ON f.trimestre = d.trimestre
WHERE f.dado_confiavel = TRUE
GROUP BY f.trimestre, d.ordem
ORDER BY d.ordem;


-- -----------------------------------------------------------------------------
-- 2. Ranking das maiores operadoras do segmento (por receita assistencial)
--    e sua sinistralidade no trimestre mais recente
-- -----------------------------------------------------------------------------
SELECT
    o.operadora,
    o.grupo_comparacao,
    f.receita_assistencial,
    f.sinistro_liquido / f.receita_assistencial AS sinistralidade
FROM fato_financeiro f
JOIN dim_operadora o ON f.REG_ANS = o.REG_ANS
WHERE f.trimestre = '1T2026'
  AND f.dado_confiavel = TRUE
  AND f.padrao_tipico = TRUE
ORDER BY f.receita_assistencial DESC
LIMIT 15;


-- -----------------------------------------------------------------------------
-- 3. Distribuição da sinistralidade por grupo de comparação
--    (quartis aproximados via PERCENTILE_CONT, min/max, contagem)
-- -----------------------------------------------------------------------------
SELECT
    o.grupo_comparacao,
    COUNT(*)                                                         AS n_operadoras,
    MIN(f.sinistro_liquido / f.receita_assistencial)                 AS minimo,
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY f.sinistro_liquido / f.receita_assistencial) AS p25,
    MEDIAN(f.sinistro_liquido / f.receita_assistencial)              AS mediana,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY f.sinistro_liquido / f.receita_assistencial) AS p75,
    MAX(f.sinistro_liquido / f.receita_assistencial)                 AS maximo
FROM fato_financeiro f
JOIN dim_operadora o ON f.REG_ANS = o.REG_ANS
WHERE f.trimestre = '1T2026'
  AND f.dado_confiavel = TRUE
GROUP BY o.grupo_comparacao
ORDER BY mediana DESC;


-- -----------------------------------------------------------------------------
-- 4. Identificação de outliers: operadoras com receita relevante
--    (portanto não capturadas pelo critério de dado_confiavel) mas
--    sinistralidade fora da faixa típica (< 20% ou > 150%)
-- -----------------------------------------------------------------------------
SELECT
    f.trimestre,
    o.operadora,
    f.receita_assistencial,
    f.sinistro_liquido / f.receita_assistencial AS sinistralidade
FROM fato_financeiro f
JOIN dim_operadora o ON f.REG_ANS = o.REG_ANS
WHERE f.dado_confiavel = TRUE
  AND f.padrao_tipico = FALSE
ORDER BY f.trimestre, sinistralidade DESC;


-- -----------------------------------------------------------------------------
-- 5. Variação do número de operadoras confiáveis entre trimestres
--    (documenta explicitamente o universo variável — ver notebooks/02_data_quality)
-- -----------------------------------------------------------------------------
SELECT
    d.ordem,
    f.trimestre,
    COUNT(DISTINCT f.REG_ANS) FILTER (WHERE f.dado_confiavel = TRUE) AS operadoras_confiaveis,
    COUNT(DISTINCT f.REG_ANS)                                        AS operadoras_com_demonstracao
FROM fato_financeiro f
JOIN dim_trimestre d ON f.trimestre = d.trimestre
GROUP BY d.ordem, f.trimestre
ORDER BY d.ordem;
