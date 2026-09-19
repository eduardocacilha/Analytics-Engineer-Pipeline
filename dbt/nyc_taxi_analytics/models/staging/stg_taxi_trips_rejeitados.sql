{{ config(materialized='table') }}

-- Camada silver: trilha de auditoria. Guarda as linhas da bronze que foram
-- descartadas de stg_taxi_trips por timestamp fora do range de sanidade
-- esperado — este projeto cobre só 2024, então qualquer pickup fora de
-- [2024-01-01, 2025-01-01) é timestamp corrompido e não entra no fato.
--
-- Não é consumida por nenhum modelo downstream (nem fato, nem gold) — existe
-- só pra responder "quantas linhas foram descartadas e por quê" sem precisar
-- vasculhar a bronze de novo. Se no futuro surgirem outros motivos de
-- rejeição, dá pra unir mais CTEs aqui com o mesmo padrão (motivo_rejeicao).

with source as (

    select * from {{ source('bronze', 'nyc_taxi_trips') }}

),

rejeitados as (

    select
        *,
        'timestamp_fora_do_range_esperado' as motivo_rejeicao

    from source
    where tpep_pickup_datetime is not null
      and (
          tpep_pickup_datetime <  cast('2024-01-01' as timestamp)
          or tpep_pickup_datetime >= cast('2025-01-01' as timestamp)
      )

)

select * from rejeitados
