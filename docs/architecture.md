# Arquitetura

## Visão geral

```
                         ┌──────────────────────────────────────────────────────┐
                         │                      DATABRICKS                        │
                         │                                                        │
  ┌───────────┐  Parquet │   ┌────────┐   dbt    ┌──────────────┐   dbt   ┌─────┐ │   Power BI
  │  NYC TLC  │──────────┼──▶│ BRONZE │─────────▶│    SILVER    │────────▶│GOLD │ │───────────▶ Dashboards
  │  (fonte   │  script  │   │ (raw,  │ (stg_* + │  (limpo,     │ (aggs / │(sel │ │   + RLS
  │  pública) │  Python  │   │ Delta) │  fato +  │  conformado, │ métricas│ pró │ │
  └───────────┘          │   └────────┘  dims)   │  dimensional)│  BI)    │ BI) │ │
        │                └──────────────────────────────────────────────────────┘
        ▼
  ┌───────────┐
  │  AWS S3   │  (raw/bronze zone — pouso do dado antes do Databricks ler)
  └───────────┘
```

## Por que arquitetura medalhão (bronze / silver / gold)?

- **Bronze**: cópia fiel do dado de origem + metadados técnicos de ingestão
  (quando chegou, de qual arquivo veio). Nunca se aplica regra de negócio
  aqui — serve como "fonte da verdade" caso precise reprocessar tudo.
- **Silver**: dado limpo, tipado, com nomes de coluna padronizados, duplicatas
  removidas, testado (`not_null`, `unique`, `relationships`) e **conformado no
  modelo dimensional** — é aqui que vivem o fato de grão fino (`fct_trips`) e as
  dimensões (`dim_zone`, `dim_payment_type`, `dim_date`). É a camada reutilizável:
  um único fato conformado alimenta vários modelos de consumo na gold.
- **Gold**: modelos de **consumo prontos pro BI** — agregações e métricas de
  negócio (`agg_corridas_por_mes`, `agg_corridas_por_vendor`), construídos em
  cima do fato da silver. Poucas linhas, forma final, é o que os dashboards leem.

### Por que dimensões na silver, e não na gold?

Existem duas convenções válidas. A convenção clássica do dbt (marts) coloca
fatos e dimensões juntos na camada de consumo. A definição de medalhão da
**própria Databricks** descreve silver como "cleansed *and conformed*" (onde
entram as dimensões conformadas) e gold como "curated, business-level, often
aggregated, ready for BI". Este projeto segue a segunda: a silver conforma o
modelo dimensional, a gold entrega o dado já agregado pro consumo.

A justificativa concreta está no próprio DAG: `fct_trips` (grão fino, silver) é
reaproveitado por **dois** agregados diferentes na gold. Esse reuso — um fato
conformado servindo várias métricas — é o que justifica ter a separação
silver/gold, e não o simples fato de "onde a dimensão mora". Se a silver fosse
só um espelho da bronze, a camada não se justificaria; ao concentrar a
modelagem dimensional nela, a silver passa a ter responsabilidade própria.

Essa separação isola responsabilidades: se uma **regra de negócio/agregação**
mudar, você refaz só a gold; se a **modelagem/limpeza** mudar, você mexe só na
silver; se o **schema de origem** mudar, você conserta só bronze/silver.

### Consumo no Power BI: star schema, não tabela achatada

"Gold pronta pro BI" **não** significa colapsar tudo numa tabela larga
desnormalizada. O Power BI (motor VertiPaq) é otimizado para **star schema** —
dimensões separadas ligadas ao fato por relacionamentos dão slicing mais
flexível, modelo menor e medidas DAX mais limpas. Por isso:

- Para **exploração interativa**, o Power BI conecta no star da silver
  (`fct_trips` + `dim_*` como tabelas separadas, com relacionamentos e
  incremental refresh via `RangeStart`/`RangeEnd` sobre `pickup_at`).
- Para **dashboards de números redondos** (ex: corridas por mês), o Power BI
  consome os agregados da gold direto — já vêm prontos, sem join.

## Testes de dados

O projeto usa os dois tipos de teste do dbt (detalhes em `dbt/nyc_taxi_analytics/tests/README.md`):

- **Generic tests** (`not_null`, `unique`, `relationships`) declarados nos
  `.yml` ao lado de cada model — validam obrigatoriedade, unicidade de chaves e
  integridade referencial fato→dimensão.
- **Singular tests** (`.sql` na pasta `tests/`) para regras que os generic não
  cobrem: `dropoff_at > pickup_at` no fato, reconciliação da soma dos agregados
  da gold contra a contagem do fato, e o monitoramento (severidade `warn`) de
  `total_amount` negativo e de gorjeta fora de cartão.

A distinção de severidade é intencional: `error` para invariantes que nunca
podem ser violados (derruba o build), `warn` para premissas do dataset que a
gente acompanha sem barrar (negativos e gorjetas são fatos reais da TLC, não
bugs).

## Papel de cada tecnologia

| Componente   | Responsabilidade                                                    |
|--------------|----------------------------------------------------------------------|
| S3           | Armazenamento barato e durável do dado bruto (data lake)             |
| Databricks   | Motor de processamento (Spark) + Delta Lake para tabelas versionadas |
| dbt          | Transformação declarativa em SQL, testes de dados, documentação      |
| Power BI     | Camada de consumo/visualização, com segurança (RLS)                   |

## Fluxo de dados passo a passo

1. `scripts/ingest_to_s3.py` baixa os arquivos Parquet da NYC TLC e sobe para
   `s3://<bucket>/raw/nyc_taxi/ano=YYYY/mes=MM/`.
2. Um notebook/Job no Databricks lê o raw do S3 e grava como tabela Delta na
   camada bronze (`bronze.nyc_taxi_trips`), com colunas técnicas adicionadas.
3. dbt roda os models de `staging/` (silver): limpeza + tipagem + dedup em
   `stg_taxi_trips`, filtro de sanidade com trilha de auditoria em
   `stg_taxi_trips_rejeitados`, o fato conformado `fct_trips` (incremental,
   merge por `trip_id`) e as dimensões `dim_zone`, `dim_payment_type`,
   `dim_date`. Testes rodam sobre esses models.
4. dbt roda os models de `marts/` (gold): agregações de negócio
   (`agg_corridas_por_mes`, `agg_corridas_por_vendor`) construídas sobre o fato
   da silver.
5. Power BI conecta via Databricks SQL Warehouse — no star da silver para
   exploração interativa e nos agregados da gold para dashboards prontos —
   com RLS aplicando filtro por usuário/role.

## Decisões em aberto

- **Idempotência da ingestão bronze**: hoje o notebook usa `mode("append")`, o
  que duplica linhas se reprocessado (mitigado a jusante por dedup na silver via
  `QUALIFY ROW_NUMBER()`). Avaliar `replaceWhere` / MERGE por hash para tornar a
  ingestão idempotente na origem. A validar com o mentor antes de implementar.
- **Cobertura de `dim_date`**: hoje cobre só 2024; ao ingerir outros anos, o
  `date_spine` e o filtro de sanidade temporal da silver precisam crescer juntos.
- **RLS estático vs dinâmico** no Power BI (Semana 7).
- **Orquestração**: usar Databricks Workflows (nativo, suficiente para o
  projeto) ou introduzir Airflow — Workflows evita complexidade desnecessária.
  Depende de resolver a idempotência primeiro.
