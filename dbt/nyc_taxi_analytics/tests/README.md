# Testes de dados (dbt)

O projeto usa os **dois** tipos de teste do dbt, cada um no seu lugar canônico:

## 1. Generic tests — nos arquivos `.yml`, ao lado de cada model

Testes reutilizáveis declarados na coluna, dentro do `.yml` do model
(`models/staging/*.yml`, `models/marts/schema.yml`). São o grosso da suíte:

- `not_null` — colunas obrigatórias (chaves, timestamps, `total_amount`).
- `unique` — chaves de fato e dimensão (`trip_id`, `zone_id`, `date_id`, ...).
- `relationships` — integridade referencial: toda FK do fato aponta para uma
  linha existente na dimensão (usa a sintaxe nova `arguments:` do dbt 1.12).

**Esses NÃO ficam nesta pasta** — o lugar deles é no `.yml` do model. Movê-los
para cá iria contra a convenção do dbt.

## 2. Singular tests — arquivos `.sql` nesta pasta (`tests/`)

Cada arquivo é uma query que retorna as linhas que **violam** uma regra.
0 linhas = passou. Servem para asserções que os generic tests não expressam
(regras de negócio, checagens que cruzam colunas ou tabelas).

| Teste | O que garante | Severidade |
|-------|---------------|------------|
| `test_dropoff_depois_pickup.sql` | `dropoff_at > pickup_at` em todo o fato — prova que a garantia da silver sobreviveu | **error** |
| `test_reconciliacao_gold_fato.sql` | Soma das corridas dos agregados da gold = contagem total do fato (nada perdido nem inventado) | **error** |
| `test_total_amount_nao_negativo.sql` | Sinaliza `total_amount < 0` | **warn** |
| `test_tip_somente_cartao.sql` | Sinaliza gorjeta em pagamento que não é cartão | **warn** |

### Por que dois `warn` e não `error`?

`error` derruba o `dbt build`; `warn` só reporta a contagem sem quebrar. Os dois
`warn` monitoram **fatos reais e legítimos do dataset da NYC TLC**, não bugs:

- **Negativos** em `total_amount` existem de verdade (estornos, disputas,
  corridas anuladas). Barrar o build por causa deles seria errado — o que
  importa é vigiar se o volume dispara.
- **Gorjeta fora de cartão** é uma hipótese documentada da métrica
  `tip_percentage`, não uma lei. O dado da TLC traz exceções raras; o teste
  monitora a premissa em vez de fingir que ela é absoluta.

Usar severidade `warn` para hipóteses e `error` para invariantes de verdade é
uma decisão consciente — mostra que a suíte distingue "regra que nunca pode ser
violada" de "premissa que a gente acompanha".

## Como rodar

```bash
dbt test                       # roda a suíte inteira (generic + singular)
dbt test --select test_type:singular   # só os singular desta pasta
dbt build                      # roda models + testes na ordem do DAG
```
