{{ config(materialized='table') }}

-- Camada gold: receita, volume e gorjeta por tipo de pagamento.
-- ----------------------------------------------------------------------------
-- PERGUNTA DE NEGOCIO
-- "Cartao vs dinheiro: quanto cada forma de pagamento representa?"
--
-- POR QUE AS METRICAS DE GORJETA ESTAO AQUI
-- O fct_trips ja documenta que gorjeta so e registrada em pagamento com cartao
-- (payment_type_id = 1); em dinheiro o campo vem zerado. Trazer gorjeta_media
-- por tipo de pagamento da EVIDENCIA a esse ponto: cartao mostra media alta,
-- dinheiro ~0. O agg vira a prova em dado do argumento analitico.
--
-- POR QUE INNER JOIN NAO PERDE CORRIDA
-- O teste generic `relationships` de fct_trips.payment_type_id ->
-- dim_payment_type garante integridade referencial, entao o inner join
-- preserva a contagem do fato.
--
-- PAPEL NO DAG
-- Da a dim_payment_type um consumidor downstream real — deixa de flutuar.

select
    p.payment_type_description,
    count(*)                        as total_corridas,
    round(sum(f.total_amount), 2)   as receita_total,
    round(avg(f.total_amount), 2)   as ticket_medio,
    round(sum(f.tip_amount), 2)     as gorjeta_total,
    round(avg(f.tip_amount), 2)     as gorjeta_media

from {{ ref('fct_trips') }} f
inner join {{ ref('dim_payment_type') }} p
    on f.payment_type_id = p.payment_type_id

group by p.payment_type_description
order by receita_total desc
