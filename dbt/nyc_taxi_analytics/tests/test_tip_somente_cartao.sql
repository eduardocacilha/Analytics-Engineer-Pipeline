{{ config(severity='warn') }}

-- Singular test: sinaliza gorjeta (tip_amount > 0) em corridas que NÃO foram
-- pagas com cartão (payment_type_id != 1).
--
-- Severidade 'warn' DE PROPÓSITO: o dataset registra gorjeta automaticamente só
-- em pagamento com cartão; em dinheiro a gorjeta não é capturada e vem zerada.
-- A expectativa é que tip_amount > 0 só apareça em cartão — é a premissa que
-- sustenta a métrica tip_percentage do fato. Mas o dado da TLC eventualmente
-- traz exceções (registros manuais, outros meios de pagamento), então isto
-- MONITORA a hipótese em vez de barrar o build. Se aparecerem muitas linhas,
-- a premissa documentada de tip_percentage precisa ser revista.
--
-- Retorna as linhas que violam a hipótese; 0 linhas = hipótese confirmada.

select
    trip_id,
    payment_type_id,
    tip_amount

from {{ ref('fct_trips') }}

where tip_amount > 0
  and payment_type_id <> 1
