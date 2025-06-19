
-- ==========================================
-- 🔎 EXPLAIN ANALYZE: Reinternações Precoces
-- ==========================================

EXPLAIN ANALYZE
WITH internacoes_ordenadas AS (
    SELECT
        pac_codigo,
        seq AS seq_internacao,
        dthr_internacao,
        dt_saida_paciente,
        LEAD(seq) OVER (PARTITION BY pac_codigo ORDER BY dthr_internacao) AS seq_reinternacao,
        LEAD(dthr_internacao) OVER (PARTITION BY pac_codigo ORDER BY dthr_internacao) AS proxima_entrada
    FROM agh.ain_internacoes
    WHERE dthr_internacao BETWEEN '2024-01-01' AND '2024-12-31'
)
SELECT
    pac_codigo,
    seq_internacao,
    seq_reinternacao,
    dthr_internacao,
    dt_saida_paciente,
    DATE_PART('day', proxima_entrada - dt_saida_paciente) AS dias_entre
FROM internacoes_ordenadas
WHERE
    proxima_entrada IS NOT NULL
    AND dt_saida_paciente IS NOT NULL
    AND DATE_PART('day', proxima_entrada - dt_saida_paciente) > 0
    AND DATE_PART('day', proxima_entrada - dt_saida_paciente) <= 15;

-- Observações:
-- - Índice ain_int_dthr_internacao_i foi utilizado corretamente
-- - 5206 linhas processadas, 163 passaram no filtro


-- ======================================
-- 🔎 EXPLAIN ANALYZE: CIDs por Internação
-- ======================================

EXPLAIN ANALYZE
SELECT
    ai.seq AS seq_internacao,
    MAX(CASE WHEN aci.ind_prioridade_cid = 'P' THEN ac.codigo END) AS cid_principal,
    STRING_AGG(ac.codigo, ', ' ORDER BY ac.codigo) FILTER (WHERE aci.ind_prioridade_cid = 'S') AS cids_secundarios
FROM agh.ain_internacoes ai
LEFT JOIN agh.ain_cids_internacao aci ON aci.int_seq = ai.seq
LEFT JOIN agh.agh_cids ac ON ac.seq = aci.cid_seq
WHERE ai.dthr_internacao BETWEEN '2024-01-01' AND '2024-12-31'
GROUP BY ai.seq;

-- Observações:
-- - Seq Scan usado em ain_cids_internacao e agh_cids é esperado
-- - Sem filtro direto em colunas indexadas



-- ====================================
-- 🧠 Consulta de Índices Existentes
-- ====================================

-- Use esta consulta para listar os índices antes de sugerir novos
SELECT
    tab.relname AS tabela,
    idx.relname AS indice,
    am.amname AS tipo,
    ARRAY_AGG(att.attname) AS colunas
FROM
    pg_class tab
    JOIN pg_index ind ON tab.oid = ind.indrelid
    JOIN pg_class idx ON idx.oid = ind.indexrelid
    JOIN pg_am am ON idx.relam = am.oid
    JOIN pg_attribute att ON att.attrelid = tab.oid AND att.attnum = ANY(ind.indkey)
WHERE
    tab.relname IN ('ain_internacoes', 'ain_cids_internacao')
GROUP BY tab.relname, idx.relname, am.amname
ORDER BY tab.relname, idx.relname;


-- ====================================
-- ✅ View Materializada Recomendada
-- ====================================

CREATE MATERIALIZED VIEW vw_internacoes_cid AS
SELECT
    ai.seq,
    ai.pac_codigo,
    ai.dthr_internacao,
    ai.dt_saida_paciente,
    ai.esp_seq,
    MAX(CASE WHEN aci.ind_prioridade_cid = 'P' THEN ac.codigo END) AS cid_principal,
    STRING_AGG(ac.codigo, ', ') FILTER (WHERE aci.ind_prioridade_cid = 'S') AS cids_secundarios
FROM agh.ain_internacoes ai
LEFT JOIN agh.ain_cids_internacao aci ON aci.int_seq = ai.seq
LEFT JOIN agh.agh_cids ac ON ac.seq = aci.cid_seq
WHERE ai.dthr_internacao BETWEEN '2024-01-01' AND '2024-12-31'
GROUP BY ai.seq, ai.pac_codigo, ai.dthr_internacao, ai.dt_saida_paciente, ai.esp_seq;

-- Para atualizar:
-- REFRESH MATERIALIZED VIEW vw_internacoes_cid;

-- Vantagens:
-- - Reduz recomputações de GROUP BY e JOINs pesados
-- - Reutilizável em painéis e relatórios
