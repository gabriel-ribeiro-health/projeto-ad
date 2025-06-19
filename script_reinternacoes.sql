WITH internacoes_ordenadas AS (
    SELECT
        pac_codigo,
        seq AS seq_internacao,
        dthr_internacao AS entrada_anterior,
        dt_saida_paciente AS saida_anterior,
        LEAD(seq) OVER (PARTITION BY pac_codigo ORDER BY dthr_internacao) AS seq_reinternacao,
        LEAD(dthr_internacao) OVER (PARTITION BY pac_codigo ORDER BY dthr_internacao) AS entrada_reinternacao,
        LEAD(dt_saida_paciente) OVER (PARTITION BY pac_codigo ORDER BY dthr_internacao) AS saida_reinternacao
    FROM agh.ain_internacoes
    WHERE dthr_internacao BETWEEN '2024-01-01' AND '2024-12-31'
),
reinternacoes_precoces AS (
    SELECT
        pac_codigo,
        seq_internacao,
        seq_reinternacao,
        entrada_anterior,
        saida_anterior,
        entrada_reinternacao,
        saida_reinternacao,
        DATE_PART('day', entrada_reinternacao - saida_anterior) AS dias_entre
    FROM internacoes_ordenadas
    WHERE
        entrada_reinternacao IS NOT NULL
        AND saida_anterior IS NOT NULL
        AND DATE_PART('day', entrada_reinternacao - saida_anterior) > 0
        AND DATE_PART('day', entrada_reinternacao - saida_anterior) <= 15
),
cid_por_internacao AS (
    SELECT
        ai.seq AS seq_internacao,
        MAX(CASE WHEN aci.ind_prioridade_cid = 'P' THEN ac.codigo END) AS cid_principal,
        STRING_AGG(ac.codigo, ', ' ORDER BY ac.codigo) FILTER (WHERE aci.ind_prioridade_cid = 'S') AS cids_secundarios
    FROM ain_internacoes ai
    LEFT JOIN ain_cids_internacao aci ON aci.int_seq = ai.seq
    LEFT JOIN agh_cids ac ON ac.seq = aci.cid_seq
    WHERE ai.dthr_internacao BETWEEN '2024-01-01' AND '2024-12-31'
    GROUP BY ai.seq
),
cid_por_reinternacao AS (
    SELECT
        ai.seq AS seq_reinternacao,
        MAX(CASE WHEN aci.ind_prioridade_cid = 'P' THEN ac.codigo END) AS cid_principal,
        STRING_AGG(ac.codigo, ', ' ORDER BY ac.codigo) FILTER (WHERE aci.ind_prioridade_cid = 'S') AS cids_secundarios
    FROM ain_internacoes ai
    LEFT JOIN ain_cids_internacao aci ON aci.int_seq = ai.seq
    LEFT JOIN agh_cids ac ON ac.seq = aci.cid_seq
    WHERE ai.dthr_internacao BETWEEN '2024-01-01' AND '2024-12-31'
    GROUP BY ai.seq
),
especialidade_por_internacao AS (
    SELECT
        ain.seq AS seq_internacao,
        esp.nome_especialidade AS especialidade_internacao
    FROM agh.ain_internacoes ain
    INNER JOIN agh.agh_especialidades esp ON esp.seq = ain.esp_seq
),
especialidade_por_reinternacao AS (
    SELECT
        ain.seq AS seq_reinternacao,
        esp.nome_especialidade AS especialidade_reinternacao
    FROM agh.ain_internacoes ain
    INNER JOIN agh.agh_especialidades esp ON esp.seq = ain.esp_seq
)
SELECT
    -- Nome mascarado: primeiro nome + iniciais
INITCAP(SPLIT_PART(pac.nome, ' ', 1)) || ' ' ||
REGEXP_REPLACE(SUBSTRING(pac.nome FROM ' .*'), '([a-zA-ZÀ-ÿ])[a-zA-ZÀ-ÿ]*', '\1.', 'g') AS nome_mascarado,
    -- CPF mascarado: ***.***.890-45
    '***.***.' ||
    SUBSTRING(LPAD(pac.cpf::TEXT, 11, '0') FROM 7 FOR 3) || '-' ||
    SUBSTRING(LPAD(pac.cpf::TEXT, 11, '0') FROM 10 FOR 2) AS cpf_mascarado,
    -- Faixa etária
    CASE
        WHEN AGE(CURRENT_DATE, pac.dt_nascimento) < INTERVAL '18 years' THEN '0-17 anos'
        WHEN AGE(CURRENT_DATE, pac.dt_nascimento) < INTERVAL '30 years' THEN '18-29 anos'
        WHEN AGE(CURRENT_DATE, pac.dt_nascimento) < INTERVAL '45 years' THEN '30-44 anos'
        WHEN AGE(CURRENT_DATE, pac.dt_nascimento) < INTERVAL '60 years' THEN '45-59 anos'
        ELSE '60+ anos'
    END AS faixa_etaria,
    pac.sexo,
    r.seq_internacao,
    r.seq_reinternacao,
    r.entrada_anterior,
    r.saida_anterior,
    r.entrada_reinternacao,
    r.saida_reinternacao,
    r.dias_entre,
    cid1.cid_principal AS cid_principal_internacao,
    cid1.cids_secundarios AS cids_secundarios_internacao,
    cid2.cid_principal AS cid_principal_reinternacao,
    cid2.cids_secundarios AS cids_secundarios_reinternacao,
    esp1.especialidade_internacao,
    esp2.especialidade_reinternacao
FROM reinternacoes_precoces r
LEFT JOIN cid_por_internacao cid1 ON cid1.seq_internacao = r.seq_internacao
LEFT JOIN cid_por_reinternacao cid2 ON cid2.seq_reinternacao = r.seq_reinternacao
LEFT JOIN especialidade_por_internacao esp1 ON esp1.seq_internacao = r.seq_internacao
LEFT JOIN especialidade_por_reinternacao esp2 ON esp2.seq_reinternacao = r.seq_reinternacao
INNER JOIN agh.aip_pacientes pac ON pac.codigo = r.pac_codigo
ORDER BY r.seq_internacao;
