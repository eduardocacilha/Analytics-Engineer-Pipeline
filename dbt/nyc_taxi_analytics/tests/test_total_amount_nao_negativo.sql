{{ config(severity='warn') }}

-- Singular test: sinaliza corridas com total_amount negativo em fct_trips.
--
-- Severidade 'warn' (não 'error') DE PROPÓSITO: o dataset da NYC TLC contém
-- valores negativos legítimos — estornos, disputas e corridas anuladas entram
-- com total_amount < 0. Não é lixo a ser barrado, é um fato de negócio a ser
-- monitorado. Barrar o build por causa disso seria errado; mas se o volume de
-- negativos disparar, é sinal de problema na origem que merece investigação.
--
-- Retorna as linhas que violam a regra; 0 linhas = nenhum negativo.

select
    trip_id,
    payment_type_id,
    total_amount

from {{ ref('fct_trips') }}

where total_amount < 0
