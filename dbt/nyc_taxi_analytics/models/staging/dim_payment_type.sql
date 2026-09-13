{{ config(materialized='table') }}

-- Camada silver: dimensão de formas de pagamento.
-- Movida da gold pra cá pelo mesmo motivo de dim_zone: é modelagem de dado,
-- não métrica de negócio.

select
    payment_type_id,
    payment_type_description

from {{ ref('payment_type_lookup') }}
