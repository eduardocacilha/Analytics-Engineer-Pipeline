{% snapshot snap_trip_financeiro %}

{{
    config(
        target_schema='silver',
        unique_key='trip_id',
        strategy='check',
        check_cols=['fare_amount', 'total_amount', 'payment_type_id']
    )
}}

-- ============================================================================
-- SNAPSHOT (SCD Type 2) — histórico de correções financeiras por corrida.
-- ----------------------------------------------------------------------------
-- O QUE FAZ
-- Guarda o histórico dos valores financeiros de cada trip_id ao longo do tempo.
-- A cada `dbt snapshot`, o dbt compara os valores atuais com a última versão
-- gravada; se fare_amount, total_amount ou payment_type_id mudarem para um
-- trip_id, ele FECHA a versão antiga (preenche dbt_valid_to) e INSERE uma nova.
-- Resultado: dá pra perguntar "quanto essa corrida custava no dia X?".
--
-- POR QUE ESTRATÉGIA 'check' (e não 'timestamp')
-- A estratégia 'timestamp' precisa de uma coluna updated_at confiável na origem
-- que suba a cada alteração — o dataset da TLC não tem isso. A 'check' compara
-- diretamente as colunas listadas em check_cols e detecta a mudança por valor.
--
-- POR QUE ISTO É "DEMONSTRAÇÃO CONCEITUAL", NÃO PEÇA VIVA
-- O trip_id é hash de (vendor + timestamps + zonas) — NÃO inclui valor. Então,
-- se a TLC republicar um mês com tarifa corrigida, o trip_id fica estável e o
-- total_amount muda: é exatamente o caso que um snapshot captura. MAS num
-- projeto de carga única (como este) a origem nunca é reprocessada, então na
-- prática nunca surge uma 2ª versão sozinha. Este snapshot existe pra
-- DEMONSTRAR o mecanismo SCD2 no fato — veja o roteiro de teste no README.
--
-- ESCOPO DE DEMONSTRAÇÃO (IMPORTANTE)
-- O filtro `where pickup_date_id = '2024-01-15'` limita o snapshot a UM único
-- dia de propósito: snapshotar as ~11,7M linhas do fato seria caro e queimaria
-- a cota da Databricks Free Edition sem necessidade pra uma demo. EM PRODUÇÃO,
-- remova esse filtro para versionar o fato inteiro.
-- ============================================================================

select
    trip_id,
    fare_amount,
    total_amount,
    payment_type_id,
    pickup_at

from {{ ref('fct_trips') }}

where pickup_date_id = cast('2024-01-15' as date)   -- ESCOPO DE DEMO — ver nota acima

{% endsnapshot %}
