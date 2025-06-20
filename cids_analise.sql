
-- ========================================
-- 1. Top 10 CIDs com mais ocorrências em 2024
-- ========================================
SELECT
    ac.codigo AS cid,
    ac.descricao AS descricao,
    COUNT(*) AS total_ocorrencias
FROM agh.ain_internacoes ai
LEFT JOIN agh.ain_cids_internacao aci ON aci.int_seq = ai.seq
LEFT JOIN agh.agh_cids ac ON ac.seq = aci.cid_seq
WHERE
    ai.dthr_internacao BETWEEN '2024-01-01' AND '2024-12-31'
    AND aci.ind_prioridade_cid = 'P'
GROUP BY ac.codigo, ac.descricao
ORDER BY total_ocorrencias DESC
LIMIT 10;


-- ========================================
-- 2. Evolução mensal dos 3 CIDs principais mais frequentes em 2024
-- ========================================
WITH top_3_cids AS (
    SELECT
        ac.codigo
    FROM agh.ain_internacoes ai
    LEFT JOIN agh.ain_cids_internacao aci ON aci.int_seq = ai.seq
    LEFT JOIN agh.agh_cids ac ON ac.seq = aci.cid_seq
    WHERE
        ai.dthr_internacao BETWEEN '2024-01-01' AND '2024-12-31'
        AND aci.ind_prioridade_cid = 'P'
    GROUP BY ac.codigo
    ORDER BY COUNT(*) DESC
    LIMIT 3
),
internacoes_filtradas AS (
    SELECT
        ac.codigo AS cid,
        DATE_TRUNC('month', ai.dthr_internacao) AS mes
    FROM agh.ain_internacoes ai
    LEFT JOIN agh.ain_cids_internacao aci ON aci.int_seq = ai.seq
    LEFT JOIN agh.agh_cids ac ON ac.seq = aci.cid_seq
    WHERE
        ai.dthr_internacao BETWEEN '2024-01-01' AND '2024-12-31'
        AND aci.ind_prioridade_cid = 'P'
        AND ac.codigo IN (SELECT codigo FROM top_3_cids)
)
SELECT
    cid,
    TO_CHAR(mes, 'YYYY-MM') AS mes,
    COUNT(*) AS total_ocorrencias
FROM internacoes_filtradas
GROUP BY cid, mes
ORDER BY cid, mes;


-- ========================================
-- 3. CIDs mais comuns entre pacientes com reinternações precoces em 2024
-- ========================================
WITH internacoes_ordenadas AS (
    SELECT
        ai.pac_codigo,
        ai.seq AS seq_internacao,
        ai.dthr_internacao,
        ai.dt_saida_paciente,
        LEAD(ai.seq) OVER (PARTITION BY ai.pac_codigo ORDER BY ai.dthr_internacao) AS seq_reinternacao,
        LEAD(ai.dthr_internacao) OVER (PARTITION BY ai.pac_codigo ORDER BY ai.dthr_internacao) AS entrada_reinternacao
    FROM agh.ain_internacoes ai
    WHERE ai.dthr_internacao BETWEEN '2024-01-01' AND '2024-12-31'
),
reinternacoes_precoces AS (
    SELECT
        seq_internacao
    FROM internacoes_ordenadas
    WHERE
        entrada_reinternacao IS NOT NULL
        AND dt_saida_paciente IS NOT NULL
        AND DATE_PART('day', entrada_reinternacao - dt_saida_paciente) > 0
        AND DATE_PART('day', entrada_reinternacao - dt_saida_paciente) <= 15
)
SELECT
    ac.codigo AS cid,
    ac.descricao AS descricao,
    COUNT(*) AS total_ocorrencias
FROM reinternacoes_precoces rp
JOIN agh.ain_cids_internacao aci ON aci.int_seq = rp.seq_internacao
JOIN agh.agh_cids ac ON ac.seq = aci.cid_seq
WHERE aci.ind_prioridade_cid = 'P'
GROUP BY ac.codigo, ac.descricao
ORDER BY total_ocorrencias DESC;


-- ========================================
-- 4. Validador de múltiplos CIDs principais por internação precoce
-- ========================================
WITH internacoes_ordenadas AS (
    SELECT
        ai.pac_codigo,
        ai.seq AS seq_internacao,
        ai.dthr_internacao,
        ai.dt_saida_paciente,
        LEAD(ai.seq) OVER (PARTITION BY ai.pac_codigo ORDER BY ai.dthr_internacao) AS seq_reinternacao,
        LEAD(ai.dthr_internacao) OVER (PARTITION BY ai.pac_codigo ORDER BY ai.dthr_internacao) AS entrada_reinternacao
    FROM agh.ain_internacoes ai
    WHERE ai.dthr_internacao BETWEEN '2024-01-01' AND '2024-12-31'
),
reinternacoes_precoces AS (
    SELECT
        seq_internacao
    FROM internacoes_ordenadas
    WHERE
        entrada_reinternacao IS NOT NULL
        AND dt_saida_paciente IS NOT NULL
        AND DATE_PART('day', entrada_reinternacao - dt_saida_paciente) > 0
        AND DATE_PART('day', entrada_reinternacao - dt_saida_paciente) <= 15
)
SELECT 
    int_seq,
    COUNT(cid_seq) AS qtd_cids_principais
FROM agh.ain_cids_internacao aci 
INNER JOIN reinternacoes_precoces ai ON ai.seq_internacao = aci.int_seq
WHERE ind_prioridade_cid = 'P'
GROUP BY int_seq
HAVING COUNT(cid_seq) > 1;
