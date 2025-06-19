# Projeto: Análise de Reinternações Precoces – Liberty

## 📊 Objetivo

Identificar e analisar eventos de **reinternações precoces (≤ 15 dias)** durante o ano de 2024, considerando:

- Internações com intervalo de até 15 dias entre alta e nova entrada do mesmo paciente;
- Diagnósticos (CID) relacionados a cada evento;
- Especialidades envolvidas;
- Cumprimento da LGPD no tratamento dos dados sensíveis;
- Estrutura otimizada e legível para uso em painéis internos e externos.

---

## ⚙️ Estrutura da Solução

A query foi dividida em **CTEs** para organização e performance:

1. **`internacoes_ordenadas`** – Ordena as internações por paciente e calcula a reinternação seguinte;
2. **`reinternacoes_precoces`** – Filtra eventos com intervalo positivo e ≤ 15 dias;
3. **`cid_por_internacao` / `cid_por_reinternacao`** – Recupera CID principal e lista de CIDs secundários para cada internação;
4. **`especialidade_por_internacao` / `especialidade_por_reinternacao`** – Recupera a especialidade associada à internação e reinternação.

---

## 🔒 Tratamento LGPD

Para adequação da visualização em **painéis públicos**, os seguintes tratamentos foram aplicados:

| Campo Original | Tratamento Aplicado                    |
|----------------|----------------------------------------|
| `nome`         | Primeiro nome + iniciais (ex: João M. S.) |
| `cpf`          | Máscara aplicada: `***.***.890-45`     |
| `dt_nascimento`| Faixa etária calculada (ex: 45-59 anos)|
| `nome_mae`, `pac_codigo` | **Removidos do resultado final** |

Todos os dados foram tratados com base no princípio da **minimização de uso**, exibindo apenas o necessário para análise.

---

## 🧠 Justificativas Técnicas

- **`LEAD()`**: Identificação da próxima internação por paciente;
- **`DATE_PART()`**: Cálculo preciso do intervalo entre alta e nova entrada;
- **`STRING_AGG()` com `FILTER`**: Concatenação dos CIDs secundários em formato limpo;
- **`REGEXP_REPLACE` + `SPLIT_PART`**: Para mascarar e preservar parcialmente os nomes dos pacientes;
- **`LPAD` + `SUBSTRING`**: Para manter a formatação de CPF com máscara correta.

---

## 📈 Campos do Resultado Final

| Campo                     | Descrição                                          |
|--------------------------|----------------------------------------------------|
| `nome_mascarado`         | Nome com iniciais do paciente                      |
| `cpf_mascarado`          | CPF mascarado, últimos dígitos visíveis            |
| `faixa_etaria`           | Faixa etária atual do paciente                     |
| `sexo`                   | Sexo biológico informado                           |
| `entrada_anterior`       | Data da internação original                        |
| `saida_anterior`         | Alta da internação original                        |
| `entrada_reinternacao`  | Nova entrada (reinternação precoce)               |
| `saida_reinternacao`    | Alta da reinternação                               |
| `dias_entre`             | Intervalo entre alta anterior e nova entrada       |
| `cid_principal_*`        | CID principal da internação/reinternação           |
| `cids_secundarios_*`     | Lista dos CIDs secundários                         |
| `especialidade_*`        | Especialidade clínica responsável                  |

---

## ✅ Considerações Finais

- A query está preparada para rodar em ambientes PostgreSQL com suporte a CTEs e funções analíticas;
- Os dados exibidos foram tratados para **uso externo**, garantindo conformidade com a LGPD;
- A estrutura modular permite **expansão futura**, como inclusão de indicadores assistenciais, taxa de reinternação por especialidade, e agrupamentos regionais.

