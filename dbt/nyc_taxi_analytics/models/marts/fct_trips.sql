{{ config(
    materialized='incremental',
    unique_key='trip_id',
    incremental_strategy='merge',
    on_schema_change='append_new_columns'
) }}

-- Camada gold: fato de corridas. Grão: 1 linha = 1 corrida (chave: trip_id).
--
-- MODELAGEM (star schema puro)
-- O fato guarda apenas as chaves estrangeiras para as dimensões e as métricas.
-- Atributos descritivos (nome da zona, borough, descrição do pagamento) NÃO são
-- desnormalizados aqui de propósito — quem faz essa junção é a camada de BI,
-- via relacionamentos com dim_zone, dim_payment_type e dim_date. Trazer esses
-- textos para dentro do fato inflaria a tabela e duplicaria a dimensão.
--
-- DIMENSÕES DEGENERADAS
-- vendor_id, rate_code_id e store_and_fwd_flag ficam no próprio fato: são
-- atributos de baixa cardinalidade que ainda não justificam tabela própria.
--
-- CARGA INCREMENTAL
-- Processa apenas corridas novas, com janela de retrocesso de 3 dias para
-- capturar dados que chegaram atrasados (late-arriving data). A estratégia
-- 'merge' com unique_key=trip_id garante que reprocessar uma corrida já
-- existente ATUALIZE a linha em vez de duplicá-la.
-- Primeira execução após mudar a materialização exige --full-refresh.

with trips as (

    select * from {{ ref('stg_taxi_trips') }}

    {% if is_incremental() %}
    where pickup_at >= (
        select coalesce(max(pickup_at), cast('1900-01-01' as timestamp))
        from {{ this }}
    ) - interval 3 days
    {% endif %}

),

final as (

    select
        -- chave do fato
        trip_id,

        -- chaves estrangeiras para as dimensões
        cast(pickup_at as date)       as pickup_date_id,
        pickup_location_id,
        dropoff_location_id,
        cast(payment_type_id as int)  as payment_type_id,

        -- dimensões degeneradas
        vendor_id,
        rate_code_id,
        store_and_fwd_flag,

        -- timestamps (grão fino, para análise por hora do dia)
        pickup_at,
        dropoff_at,

        -- métricas aditivas
        passenger_count,
        trip_distance_miles,
        fare_amount,
        extra_amount,
        mta_tax_amount,
        tip_amount,
        tolls_amount,
        improvement_surcharge_amount,
        congestion_surcharge_amount,
        total_amount,

        -- métricas derivadas
        round((unix_timestamp(dropoff_at) - unix_timestamp(pickup_at)) / 60.0, 2)
            as trip_duration_minutes,

        case
            when trip_distance_miles > 0
            then round(total_amount / trip_distance_miles, 2)
        end as amount_per_mile,

        -- ATENÇÃO ANALÍTICA: gorjeta só é registrada em pagamento com cartão
        -- (payment_type_id = 1). Em dinheiro o campo vem zerado mesmo quando
        -- houve gorjeta. Filtre por cartão ao usar esta métrica, senão a média
        -- fica artificialmente baixa.
        case
            when fare_amount > 0
            then round(tip_amount / fare_amount * 100, 2)
        end as tip_percentage

    from trips

)

select * from final
