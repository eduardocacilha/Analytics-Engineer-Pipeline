-- Camada gold: métrica de negócio — corridas por fornecedor (vendor_id).
-- Grão: 1 linha por vendor. O dataset da TLC só tem 2 vendors (fornecedores
-- do sistema TPEP) — não confundir com "taxista": não existe ID de motorista
-- neste dataset, só o provedor de tecnologia que registrou a corrida.
-- Consome o fato pronto na camada silver.

with trips as (

    select * from {{ ref('fct_trips') }}

),

final as (

    select
        vendor_id,
        count(*)                     as total_corridas,
        round(avg(total_amount), 2)  as ticket_medio,
        round(sum(total_amount), 2)  as receita_total

    from trips
    group by 1

)

select * from final
order by vendor_id
