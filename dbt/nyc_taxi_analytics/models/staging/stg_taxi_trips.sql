

with source as (

    select * from {{ source('bronze', 'nyc_taxi_trips') }}

),

renamed as (

    select
        -- chave substituta (surrogate key) - o dataset não tem ID de corrida nativo
        {{ dbt_utils.generate_surrogate_key([
            'vendorid',
            'tpep_pickup_datetime',
            'tpep_dropoff_datetime',
            'pulocationid',
            'dolocationid'
        ]) }} as trip_id,

        -- chaves / dimensões
        vendorid                    as vendor_id,
        pulocationid                as pickup_location_id,
        dolocationid                as dropoff_location_id,
        payment_type                as payment_type_id,
        cast(ratecodeid as int)                  as rate_code_id,
        store_and_fwd_flag          as store_and_fwd_flag,

        -- tempo
        tpep_pickup_datetime        as pickup_at,
        tpep_dropoff_datetime       as dropoff_at,

        -- métricas
        cast(passenger_count as int)              as passenger_count,
        trip_distance                as trip_distance_miles,

        -- financeiro
        fare_amount                  as fare_amount,
        extra                        as extra_amount,
        mta_tax                      as mta_tax_amount,
        tip_amount                   as tip_amount,
        tolls_amount                 as tolls_amount,
        improvement_surcharge        as improvement_surcharge_amount,
        congestion_surcharge         as congestion_surcharge_amount,
        total_amount                 as total_amount,

        -- metadados técnicos (vindos da bronze)
        _ingested_at,
        _source_file

    from source
    where tpep_pickup_datetime is not null
      and tpep_dropoff_datetime is not null
      and tpep_dropoff_datetime > tpep_pickup_datetime
      and tpep_dropoff_datetime <= tpep_pickup_datetime + INTERVAL 3 HOURS
      and dolocationid is not null
      and payment_type is not null
      and passenger_count is not null
      and trip_distance is not null
      -- filtro de sanidade temporal: este projeto ingeriu SÓ dados de 2024, e a
      -- dim_date cobre exatamente o ano civil de 2024. Qualquer pickup fora de
      -- [2024-01-01, 2025-01-01) é timestamp corrompido (relógio/sensor do
      -- veículo) — não existe corrida real de 2002 ou 2090 num arquivo de 2024.
      -- Restringir aqui garante integridade referencial fato -> dim_date. As
      -- linhas descartadas ficam auditadas em stg_taxi_trips_rejeitados.
      -- IMPORTANTE: ao ingerir novos anos, ampliar ESTE range E o date_spine de
      -- dim_date juntos — os dois têm que cobrir o mesmo período.
      and tpep_pickup_datetime >= cast('2024-01-01' as timestamp)
      and tpep_pickup_datetime <  cast('2025-01-01' as timestamp)

),

deduplicated as (

    select *
    from renamed
    qualify row_number() over (
        partition by trip_id
        order by _ingested_at desc
    ) = 1

)

select * from deduplicated
