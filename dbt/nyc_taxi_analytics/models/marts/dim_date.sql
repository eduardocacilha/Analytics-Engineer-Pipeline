

with spine as (

    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('2024-01-01' as date)",
        end_date="cast('2025-01-01' as date)"
    ) }}

),

renamed as (

    select
        date_day                          as date_id,
        year(date_day)                     as ano,
        month(date_day)                    as mes,
        day(date_day)                      as dia,
        dayofweek(date_day)                as dia_semana_numero,
        quarter(date_day)                  as trimestre,
        case
            when dayofweek(date_day) in (1, 7) then true
            else false
        end                                 as is_fim_de_semana

    from spine

)

select * from renamed