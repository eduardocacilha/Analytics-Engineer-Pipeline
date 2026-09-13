-- Camada gold: métrica de negócio — corridas por mês.
-- Grão: 1 linha por mês (ano_mes). Substitui a antiga fct_trips como
-- conteúdo da gold: em vez de ~13 milhões de linhas de grão fino, a gold
-- passa a guardar só o resultado já agregado (~12 linhas por ano de dados).
-- Consome o fato pronto na camada silver.

with trips as (

    select * from {{ ref('fct_trips') }}

),

final as (

    select
        cast(date_format(pickup_at, 'yyyy-MM') as string) as ano_mes,
        date_trunc('month', pickup_at)                    as mes_referencia,
        count(*)                                          as total_corridas,
        round(avg(total_amount), 2)                       as ticket_medio,
        round(sum(total_amount), 2)                       as receita_total

    from trips
    group by 1, 2

)

select * from final
order by mes_referencia
