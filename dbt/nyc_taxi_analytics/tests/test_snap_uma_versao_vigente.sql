-- Teste singular (severity: error) sobre o snapshot SCD Type 2.
-- ----------------------------------------------------------------------------
-- INVARIANTE
-- Num SCD Type 2 correto, cada chave (trip_id) pode ter no MAXIMO uma versao
-- vigente por vez — a linha aberta, com dbt_valid_to = null. Se um trip_id
-- aparecer com duas ou mais linhas abertas, o snapshot esta corrompido: o dbt
-- deixou de fechar a versao antiga ao inserir a nova.
--
-- Este teste da ao snap_trip_financeiro um no filho no DAG (deixa de ser folha)
-- e, mais importante, valida o proprio mecanismo do snapshot — nao so a
-- existencia dele. Retorna linhas apenas quando a invariante e violada.

select
    trip_id,
    count(*) as versoes_vigentes

from {{ ref('snap_trip_financeiro') }}
where dbt_valid_to is null

group by trip_id
having count(*) > 1
