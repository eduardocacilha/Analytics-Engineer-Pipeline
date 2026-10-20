# NYC Taxi Analytics — Pipeline Medalhão (S3 · Databricks · dbt)

Projeto de portfólio em Analytics/Data Engineering: ingere ~11,7 milhões de corridas
de Yellow Taxi (NYC TLC, 2024) do S3 para o Databricks e transforma em camadas
bronze → silver → gold com dbt, com testes de dados e snapshot SCD2.

## Status

- ✅ **Bronze** — `scripts/ingest_to_s3.py` (NYC TLC → S3) e `notebooks/01_bronze_ingestion.py` (S3 → Delta `bronze.nyc_taxi_trips`)
- ✅ **Silver** — limpeza e dedup (`stg_taxi_trips`), trilha de rejeitados (`stg_taxi_trips_rejeitados`), fato incremental `fct_trips` (merge por `trip_id`) e dimensões `dim_date`, `dim_zone`, `dim_payment_type`
- ✅ **Gold** — 5 agregados de consumo: corridas por mês e por vendor, receita por zona e por pagamento, qualidade da ingestão
- ✅ **Testes** — generic (`not_null`, `unique`, `relationships`, `dbt_utils`) + 5 singular, com severidade `error`/`warn`
- ✅ **Snapshot SCD2** — `snap_trip_financeiro` (demonstração)
- ✅ **CI** — GitHub Actions roda `dbt parse` a cada push
- ⏳ **Orquestração** — Databricks Workflows (depende de tornar a bronze idempotente)
- ⏳ **BI** — Power BI com RLS

## Stack

| Camada | Tecnologia |
|---|---|
| Storage (raw) | AWS S3 |
| Processamento | Databricks Free Edition + Delta Lake (Unity Catalog) |
| Transformação | dbt-core 1.12 + dbt-databricks |
| Qualidade | dbt tests + dbt_utils |
| CI | GitHub Actions |
| Orquestração | Databricks Workflows (planejado) |
| BI | Power BI (planejado) |
| Linguagens | SQL, Python (PySpark) |

## Arquitetura

```
NYC TLC ──(Python)──▶ S3 raw ──▶ BRONZE (Delta) ──dbt──▶ SILVER ──dbt──▶ GOLD ──▶ Power BI
                                                  stg_* + fato    agregados
                                                  + dimensões     de negócio
```

A silver concentra o modelo dimensional (fato + dimensões conformadas) e a gold
entrega agregados prontos para consumo — a justificativa está em
[`docs/architecture.md`](docs/architecture.md). Dicionário de dados em
[`docs/data_dictionary.md`](docs/data_dictionary.md).

## Estrutura

```
.
├── scripts/
│   ├── ingest_to_s3.py          # NYC TLC → S3 (raw)
│   └── eda/eda_taxi_trips.ipynb # análise exploratória
├── notebooks/
│   └── 01_bronze_ingestion.py   # S3 → Delta (bronze)
├── dbt/nyc_taxi_analytics/
│   ├── models/
│   │   ├── staging/   # silver: stg_*, fct_trips, dim_*
│   │   └── marts/     # gold: agg_*
│   ├── snapshots/     # SCD2 (snap_trip_financeiro)
│   ├── tests/         # testes singulares
│   ├── seeds/         # lookups da TLC (zonas, pagamento)
│   └── macros/        # generate_schema_name
├── docs/
│   ├── architecture.md
│   └── data_dictionary.md
└── .github/workflows/ci.yml
```

## Como rodar

```bash
pip install -r requirements.txt
cp .env.example .env              # credenciais AWS
python scripts/ingest_to_s3.py

cd dbt/nyc_taxi_analytics         # requer um profiles.yml do dbt-databricks (não versionado)
dbt deps
dbt build                         # models + testes
dbt snapshot
```

## Dataset

[NYC TLC Trip Record Data](https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page) — Yellow Taxi, Parquet mensal, público.
