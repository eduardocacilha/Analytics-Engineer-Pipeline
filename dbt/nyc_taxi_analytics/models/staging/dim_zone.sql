{{ config(materialized='table') }}

-- Camada silver: dimensão de zonas de táxi de Nova York.
-- Antes vivia na camada gold — movida pra cá porque é modelagem de dado
-- (dimensão), não métrica de negócio. Materializada como tabela (e não view,
-- que é o padrão da pasta staging) porque é referenciada por fct_trips e
-- pelas métricas da gold; recalcular a partir da seed toda vez seria
-- desnecessário, já que a seed praticamente não muda.

select
    locationid   as zone_id,
    borough,
    zone         as zone_name,
    service_zone

from {{ ref('taxi_zone_lookup') }}
