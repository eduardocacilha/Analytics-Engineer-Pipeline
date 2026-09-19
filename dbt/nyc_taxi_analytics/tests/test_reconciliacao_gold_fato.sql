-- Singular test: reconciliação — a soma das corridas dos agregados da gold
-- tem que bater com a contagem total do fato na silver.
--
-- É o teste mais importante da suíte: prova que a agregação não perdeu nem
-- inventou corridas. Se um GROUP BY estiver errado, um filtro vazar, ou o fato
-- e o agregado saírem de sincronia (ex: rodou o fato mas esqueceu de rebuildar
-- a gold), os totais divergem e este teste acusa.
--
-- Severidade 'error' (padrão). Retorna uma linha por agregado que NÃO bate;
-- 0 linhas = tudo reconciliado.

with fato as (
    select count(*) as total from {{ ref('fct_trips') }}
),

agg_mes as (
    select sum(total_corridas) as total from {{ ref('agg_corridas_por_mes') }}
),

agg_vendor as (
    select sum(total_corridas) as total from {{ ref('agg_corridas_por_vendor') }}
)

select
    'agg_corridas_por_mes' as agregado,
    f.total                as total_fato,
    a.total                as total_agregado
from fato f
cross join agg_mes a
where f.total <> a.total

union all

select
    'agg_corridas_por_vendor' as agregado,
    f.total                   as total_fato,
    v.total                   as total_agregado
from fato f
cross join agg_vendor v
where f.total <> v.total
