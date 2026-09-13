

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
