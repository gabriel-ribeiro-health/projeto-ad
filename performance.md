
# Avaliação de Performance – Projeto Reinternações Precoces

## 📊 Query Principal (LGPD)

A query principal que exibe dados mascarados para conformidade com a LGPD apresentou **ótima performance** ao processar **5206 internações** e retornar **163 eventos de reinternação precoce**.

---

## ✅ Visão Geral do Plano

**Execution Time: 63.645 ms**

O tempo total de execução foi de **63ms**, o que é excelente considerando:

- Múltiplos **`JOINs`**
- Uso de **`LEAD()`** (função analítica)
- Processamento de **5206 internações**
- **Mascaramento e transformação** de campos sensíveis (`nome`, `CPF`, `idade`)

---

## 🔍 Quebra passo a passo

### 🔁 Etapa 1 – Subquery com `WindowAgg`

> `WindowAgg → Sort → Index Scan on ain_internacoes`

- Utiliza corretamente o índice **`ain_int_dthr_internacao_i`**
- Faz ordenação por `pac_codigo, dthr_internacao` para aplicar `LEAD()`
- Retornou **5206 linhas**, removeu **5043** após filtro → restaram **163 reinternações precoces**
- Executado em: **~8ms**

---

### 🔗 Etapa 2 – CIDs + Especialidades

> `Nested Loop Left Join (internacoes_ordenadas com ain, esp)`
> → `GroupAggregate (por seq)` → `Hash Left Join` → `Hash Right Join`

- Agrupa os **CIDs por internação e reinternação**
- Usa `GroupAggregate + Sort + Hash Join`
- Os `Seq Scan` em `ain_cids_internacao` e `agh_cids` são **esperados**, pois **não há filtros seletivos**
- O índice `ain_int_dthr_internacao_i` é **usado novamente**
- Total dessa parte: **~21ms + 21ms = ~42ms**

---

### 🧠 Etapa 3 – Paciente (`aip_pacientes`)

> `Memoize + Index Scan on aip_pacientes using primary key`

- Excelente uso de `Memoize`, que **evita refazer a leitura** do paciente já consultado
- 134 **misses** / 29 **hits** → caching já sendo eficiente
- Executado em: **~2ms**


---

## ❓ Justificativa para `Seq Scan`

Apesar da tabela `ain_cids_internacao` possuir índices como:

- `ain_cdi_cid_fk1_i` (`cid_seq`)
- `ain_cids_internacao_pkey` (`int_seq`, `cid_seq`)

O planner **optou por `Seq Scan`** devido a:

- Ausência de **filtros seletivos diretos**
- O `JOIN` exige leitura de **toda a tabela**
- **Custo de leitura sequencial** é mais barato do que múltiplos acessos aleatórios por índice
- A tabela `agh_cids`, com ~14k registros, também é pequena o suficiente para justificar `Seq Scan`

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

## 📎 Considerações Finais

A solução proposta apresenta **boa performance, uso correto de índices**, aproveitamento de recursos como `Memoize` e `WindowAgg`, e está pronta para **escalabilidade moderada** com melhorias pontuais por materialização. Os `Seq Scan` foram analisados e são justificados pelo volume e ausência de filtros seletivos.
