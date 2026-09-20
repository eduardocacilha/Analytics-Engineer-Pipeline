{{ config(materialized='table') }}

-- Camada gold (observabilidade): saude da ingestao.
-- ----------------------------------------------------------------------------
-- O QUE FAZ
-- Cruza as linhas descartadas (stg_taxi_trips_rejeitados) com as aceitas
-- (fct_trips) e calcula a TAXA DE REJEICAO por motivo. Nao e so contar lixo:
-- pct_rejeicao e um indicador de saude do pipeline que da pra monitorar ao
-- longo do tempo.
--
-- PAPEL NO DAG
-- Consome DUAS pecas que antes eram folha morta / so validacao:
--   - stg_taxi_trips_rejeitados (trilha de auditoria, ate agora sem consumidor)
--   - fct_trips (para o denominador de aceitas)
-- Demonstra observabilidade de pipeline, nao so transformacao.
--
-- LEITURA
-- pct_rejeicao alto ou subindo entre cargas = sinal de dado de origem
-- degradando (ex: mais timestamps corrompidos). Grao: 1 linha por motivo.

with rejeitados as (

    select
        motivo_rejeicao,
        count(*) as linhas_rejeitadas
    from {{ ref('stg_taxi_trips_rejeitados') }}
    group by motivo_rejeicao

),

aceitas as (

    select count(*) as linhas_aceitas
    from {{ ref('fct_trips') }}

)

select
    r.motivo_rejeicao,
    r.linhas_rejeitadas,
    a.linhas_aceitas,
    round(
        r.linhas_rejeitadas / (r.linhas_rejeitadas + a.linhas_aceitas) * 100,
        4
    ) as pct_rejeicao

from rejeitados r
cross join aceitas a
order by r.linhas_rejeitadas desc
