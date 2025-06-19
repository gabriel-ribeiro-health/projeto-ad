
# Avaliação de Performance – Projeto Reinternações Precoces

## 📊 Query Principal (LGPD)

A query principal que exibe dados mascarados para conformidade com a LGPD apresentou ótima performance ao processar 5206 internações e retornar 163 eventos de reinternação precoce.

### 🔍 Destaques do `EXPLAIN ANALYZE`

- **Tempo total de execução**: 63.645 ms
- **Index Scan ativo**: O índice `ain_int_dthr_internacao_i` foi corretamente utilizado nas leituras da tabela `ain_internacoes`.
- **Função analítica `LEAD()`** executada sobre `pac_codigo, dthr_internacao`, suportada por ordenação eficiente (`WindowAgg` + `Sort`).
- **Filtros aplicados**: datas válidas de entrada/saída e diferença de até 15 dias entre internações.
- **Joins com especialidades e pacientes**: otimizados por `Index Scan` e `Memoize`, evitando leituras repetidas.
- **CIDs**: As tabelas `ain_cids_internacao` e `agh_cids` foram acessadas via `Seq Scan`, comportamento esperado diante da leitura integral sem filtros seletivos.

### 💡 Interpretação Técnica

> "A query principal com LGPD executou de forma altamente performática. Utilizou índices corretos, apresentou caching eficiente em joins (`Memoize`) e distribuiu o plano de execução de forma balanceada entre joins, agregações e transformações. A estrutura está escalável para ambientes de volume médio-alto."

---

## 🔎 Análise de CIDs

### Comportamento:

- **Execução**: ~100ms
- **GroupAggregate + Sort** para agrupar CIDs por internação
- **Joins hash-based** entre `ain_internacoes`, `ain_cids_internacao` e `agh_cids`
- **`Seq Scan` usado em `ain_cids_internacao` e `agh_cids`**, por não haver filtros seletivos
- Índice `ain_int_dthr_internacao_i` **utilizado** corretamente para `ain_internacoes`

### Justificativa para Seq Scan:

Apesar de haver índice em `ain_cids_internacao (int_seq, cid_seq)`, o planner optou por `Seq Scan` porque:

- Não há filtros diretos sobre as colunas indexadas
- O join exige leitura ampla da tabela
- O PostgreSQL considera o custo de leitura sequencial menor do que acessos randômicos via índice
- Tabela `agh_cids` tem apenas ~14k registros → `Seq Scan` é eficiente neste caso

---

## 🧠 Sugestões de Otimização

### ✅ View Materializada Recomendada

```sql
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
```

#### Vantagens:
- Reduz recomputação de `GROUP BY` + `JOINs`
- Reutilizável por painéis e relatórios
- Pode ser atualizada com:
  ```sql
  REFRESH MATERIALIZED VIEW vw_internacoes_cid;
  ```

---

## 🔍 Política de Verificação de Índices

Antes de sugerir novos índices, execute:

```sql
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
```

---

## ✅ Conclusão

A solução proposta apresenta **boa performance, uso correto de índices**, aproveitamento de recursos como `Memoize` e `WindowAgg`, e está pronta para **escalabilidade moderada** com melhorias pontuais por materialização. Os `Seq Scan` foram analisados e são justificados pelo volume e ausência de filtros seletivos.
