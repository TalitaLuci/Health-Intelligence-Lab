-- =============================================================================
-- pasa_analysis.sql
-- Estudo de caso: PASA (REG_ANS 331988)
-- Dialeto: DuckDB
-- =============================================================================


-- -----------------------------------------------------------------------------
-- 1. Série trimestral completa da PASA: sinistralidade, resultado
--    operacional e taxa de glosa lado a lado
-- -----------------------------------------------------------------------------
SELECT
    f.trimestre,
    d.ordem,
    f.receita_assistencial,
    f.sinistro_liquido,
    f.sinistro_liquido / f.receita_assistencial            AS sinistralidade,
    f.receitas_totais - f.despesas_totais                  AS resultado_operacional,
    f.glosa / NULLIF(f.faturado_bruto, 0)                  AS taxa_glosa
FROM fato_financeiro f
JOIN dim_trimestre d ON f.trimestre = d.trimestre
WHERE f.REG_ANS = 331988
ORDER BY d.ordem;


-- -----------------------------------------------------------------------------
-- 2. PASA vs. peer group (fundações de previdência/seguridade) — 1T2026
--    Mostra a distribuição do grupo, não apenas a posição da PASA isolada.
-- -----------------------------------------------------------------------------
SELECT
    o.operadora,
    f.receita_assistencial,
    f.sinistro_liquido / f.receita_assistencial AS sinistralidade,
    CASE WHEN f.REG_ANS = 331988 THEN 'PASA' ELSE 'Peer group' END AS destaque
FROM fato_financeiro f
JOIN dim_operadora o ON f.REG_ANS = o.REG_ANS
WHERE f.trimestre = '1T2026'
  AND (o.grupo_comparacao = 'Fundação de previdência' OR f.REG_ANS = 331988)
ORDER BY sinistralidade DESC;


-- -----------------------------------------------------------------------------
-- 3. Posição relativa da PASA dentro do peer group (percentil aproximado)
--    via window function — sem depender de MEDIAN()/PERCENTILE_CONT.
-- -----------------------------------------------------------------------------
WITH grupo AS (
    SELECT
        f.REG_ANS,
        f.sinistro_liquido / f.receita_assistencial AS sinistralidade
    FROM fato_financeiro f
    JOIN dim_operadora o ON f.REG_ANS = o.REG_ANS
    WHERE f.trimestre = '1T2026'
      AND (o.grupo_comparacao = 'Fundação de previdência' OR f.REG_ANS = 331988)
),
ranqueado AS (
    SELECT
        REG_ANS,
        sinistralidade,
        PERCENT_RANK() OVER (ORDER BY sinistralidade) AS percentil
    FROM grupo
)
SELECT * FROM ranqueado WHERE REG_ANS = 331988;


-- -----------------------------------------------------------------------------
-- 4. Variação trimestre a trimestre dos principais indicadores da PASA
--    (LAG para comparar com o período anterior)
-- -----------------------------------------------------------------------------
WITH serie AS (
    SELECT
        f.trimestre,
        d.ordem,
        f.sinistro_liquido / f.receita_assistencial AS sinistralidade,
        f.glosa / NULLIF(f.faturado_bruto, 0)       AS taxa_glosa
    FROM fato_financeiro f
    JOIN dim_trimestre d ON f.trimestre = d.trimestre
    WHERE f.REG_ANS = 331988
)
SELECT
    trimestre,
    sinistralidade,
    sinistralidade - LAG(sinistralidade) OVER (ORDER BY ordem)   AS variacao_sinistralidade,
    taxa_glosa,
    taxa_glosa - LAG(taxa_glosa) OVER (ORDER BY ordem)           AS variacao_taxa_glosa
FROM serie
ORDER BY ordem;
