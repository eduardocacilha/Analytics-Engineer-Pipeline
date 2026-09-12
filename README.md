# Data Pipeline — NYC Taxi Analytics (Medallion Architecture)

Projeto de portfólio para desenvolvimento em **Analytics Engineering**, construído ao
longo de um roadmap pessoal de 8 semanas. O objetivo é dominar, na prática, o ciclo completo de
um pipeline analítico moderno: ingestão, transformação em camadas (medalhão), testes
de qualidade, orquestração e consumo em BI.

## Status atual

- ✅ **Bronze** — ingestão via `scripts/ingest_to_s3.py` (NYC TLC → S3) funcionando
- ✅ **Silver** — modelos de staging em dbt (limpeza e tipagem) implementados
- 🚧 **Gold** — modelagem dimensional (fatos e dimensões de contexto) em construção
- ⏳ **BI** — consumo em Power BI ainda não iniciado

## Stack

| Camada            | Tecnologia                                   |
|-------------------|----------------------------------------------|
| Storage (raw)     | AWS S3                                        |
| Processamento     | Databricks (Community Edition / Trial)        |
| Transformação     | dbt-databricks                                |
| Orquestração      | Databricks Workflows (Jobs)                   |
| Consumo / BI      | Power BI (com RLS)                            |
| Linguagens        | SQL, Python                                   |
| Versionamento     | Git / GitHub                                  |

## Dataset

**NYC TLC Trip Record Data** (Yellow Taxi) — dataset público, mensal, em Parquet,
disponibilizado pela cidade de Nova York. Bom candidato para este projeto porque tem:

- Volume realista (milhões de linhas/mês) para simular cenários de produção.
- Tabelas de dimensão (zonas, tipos de pagamento, vendors) — permite modelar
  fatos e dimensões de verdade.
- Atualização mensal — dá pra simular cargas incrementais.

Fonte oficial: https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page

## Arquitetura (visão geral)

```
S3 (raw/bronze)  →  Databricks (bronze → silver → gold, via dbt)  →  Power BI
     ↑                                                                  ↑
 script Python                                                   dashboards + RLS
 (ingestão)
```

Ver detalhes em [`docs/architecture.md`](docs/architecture.md).

## Estrutura do repositório

```
data-pipeline/
├── README.md
├── requirements.txt
├── .gitignore
├── docs/
│   ├── roadmap.md          # plano semana a semana (8 semanas)
│   ├── architecture.md     # arquitetura detalhada + diagrama
│   └── setup-guide.md      # passo a passo: contas AWS + Databricks
├── scripts/
│   └── ingest_to_s3.py     # baixa os arquivos da NYC TLC e sobe pro S3 (raw)
├── notebooks/               # notebooks Databricks (bronze → silver, exploração)
└── dbt/
    └── nyc_taxi_analytics/  # projeto dbt (silver/gold)
        ├── dbt_project.yml
        ├── models/
        │   ├── staging/       # bronze → silver (limpeza, tipagem)
        │   ├── intermediate/  # joins e regras de negócio intermediárias
        │   └── marts/         # gold (fatos e dimensões prontos pro BI)
        └── seeds/              # dados de referência estáticos (ex: zonas)
```
