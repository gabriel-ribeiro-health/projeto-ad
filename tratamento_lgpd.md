# Tratamento LGPD – Dados Sensíveis dos Pacientes

## 📌 Campos Tratados

Durante a análise, os seguintes campos sensíveis foram identificados e tratados conforme os princípios da Lei Geral de Proteção de Dados Pessoais (LGPD):

| Campo Original     | Tipo de Dado Pessoal       | Técnica Aplicada                                           |
|--------------------|----------------------------|------------------------------------------------------------|
| `nome`             | Identificável direto       | Exibido como: Primeiro nome + iniciais (ex: João A. B.)   |
| `cpf`              | Identificável direto       | Mascarado: `***.***.890-45`                                |
| `dt_nascimento`    | Dado pessoal sensível      | Transformado em faixa etária (ex: 30-44 anos)              |
| `sexo`             | Dado pessoal sensível      | Mantido, por ser necessário para análise clínica           |
| `nome_mae`         | Identificável direto       | Removido do resultado final                                |
| `pac_codigo`       | Identificador interno      | Removido para resultados públicos; uso restrito interno    |

---

## 🛡️ Técnicas de Mascaramento e Pseudonimização

### 🔤 Nome

- Utilizado `INITCAP(SPLIT_PART(...))` para obter o primeiro nome com letra maiúscula;
- Utilizado `REGEXP_REPLACE(SUBSTRING(...))` para extrair as iniciais dos sobrenomes com sufixo `.`;
- Exemplo: `Jose Carlos Dine` → `Jose C. D.`

### 🔢 CPF

- Convertido para texto com `LPAD(..., 11, '0')` para garantir 11 dígitos com zeros à esquerda;
- Aplicado `SUBSTRING(... FROM 7 FOR 3)` para capturar os 3 últimos do corpo;
- Aplicado `SUBSTRING(... FROM 10 FOR 2)` para os dois dígitos verificadores;
- Resultado formatado como `***.***.890-45`.

### 📅 Data de Nascimento

- Utilizada a função `AGE()` para calcular a idade;
- Classificada em faixas etárias usando `CASE WHEN`;
- Faixas utilizadas: `0-17`, `18-29`, `30-44`, `45-59`, `60+`.

### 🚻 Sexo

- Mantido no resultado final por ter **valor analítico importante** e **não ser identificável isoladamente**.

### 🗃️ Outros campos

- `nome_mae` e `pac_codigo` **não foram exibidos**, por permitirem reidentificação direta ou cruzada.

---

## 👁️ Visibilidade em Painéis

| Campo                   | Painéis Internos        | Painéis Públicos         |
|------------------------|--------------------------|---------------------------|
| Nome (mascarado)       | ✅ Permitido              | ✅ Permitido              |
| CPF (parcialmente)     | ✅ Permitido              | ✅ Permitido              |
| Sexo                   | ✅ Permitido              | ✅ Permitido              |
| Faixa Etária           | ✅ Permitido              | ✅ Permitido              |
| CID Principal          | ✅ Permitido              | ✅ Permitido              |
| Especialidade          | ✅ Permitido              | ✅ Permitido              |
| Identificador paciente | ✅ Permitido com pseudônimo | ❌ Ocultar ou remover    |
| Nome da Mãe            | ✅ Permitido com autorização | ❌ Ocultar               |

---

## 📎 Considerações Finais

Todos os dados exibidos respeitam os princípios de:
- **Necessidade**: apenas dados úteis para análise foram mantidos;
- **Minimização**: nenhum dado em excesso ou identificável diretamente foi exibido;
- **Transparência e segurança**: garantindo que a visualização pública esteja em conformidade com a LGPD.

O uso de dados não mascarados ou completos deve ser **restrito a ambientes internos e controlados**.
