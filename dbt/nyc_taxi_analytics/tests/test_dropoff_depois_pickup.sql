-- Singular test: garante que toda corrida tem dropoff_at > pickup_at.
--
-- Severidade 'error' (padrão): isto é um invariante que a silver JÁ garante
-- (stg_taxi_trips filtra tpep_dropoff_datetime > tpep_pickup_datetime). Este
-- teste PROVA que a garantia sobreviveu até o fato — se um dia alguém afrouxar
-- o filtro da silver ou mudar a lógica do fato, o teste quebra na hora.
--
-- Um teste singular retorna as linhas que VIOLAM a regra. 0 linhas = passou.

select
    trip_id,
    pickup_at,
    dropoff_at

from {{ ref('fct_trips') }}

where dropoff_at <= pickup_at
