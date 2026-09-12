
--   - materialized='incremental' usando pickup_at como chave de incremento
--   - joins com dim_zone (pickup e dropoff) e uma futura dim_payment_type
--   - métricas derivadas: duração da corrida, valor por milha, % de gorjeta

select
    t.pickup_location_id,
    t.dropoff_location_id,
    t.payment_type_id,
    t.pickup_at,
    t.dropoff_at,
    t.passenger_count,
    t.trip_distance_miles,
    t.fare_amount,
    t.tip_amount,
    t.total_amount

from {{ ref('stg_taxi_trips') }} t
