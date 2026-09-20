{{ config(materialized='table') }}

-- Camada gold: receita e volume de corridas por zona/borough de ORIGEM.
-- ----------------------------------------------------------------------------
-- PERGUNTA DE NEGOCIO
-- "De onde saem as corridas que mais faturam?" — leitura acionavel para
-- posicionamento de frota. Agrego por pickup_location_id (origem), nao por
-- destino. Trocar para dropoff_location_id responderia outra pergunta
-- ("para onde as pessoas vao"), nao esta.
--
-- POR QUE INNER JOIN NAO PERDE CORRIDA
-- O teste generic `relationships` de fct_trips.pickup_location_id -> dim_zone
-- garante que todo pickup_location_id existe na dimensao. Logo o inner join
-- preserva a contagem do fato — nenhuma corrida e descartada silenciosamente.
--
-- PAPEL NO DAG
-- Da a dim_zone um consumidor downstream real: a dimensao deixa de flutuar e
-- conecta organicamente, sem poluir o fato com join de validacao.

select
    z.borough,
    z.zone_name,
    count(*)                        as total_corridas,
    round(sum(f.total_amount), 2)   as receita_total,
    round(avg(f.total_amount), 2)   as ticket_medio

from {{ ref('fct_trips') }} f
inner join {{ ref('dim_zone') }} z
    on f.pickup_location_id = z.zone_id

group by z.borough, z.zone_name
order by receita_total desc
