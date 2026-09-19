# Snapshots (dbt) — SCD Type 2

Snapshots capturam o **histórico de mudanças** de uma origem que muda no lugar
(a mesma chave é atualizada ao longo do tempo). Implementam SCD Type 2: cada
mudança fecha a versão antiga (`dbt_valid_to`) e insere uma nova.

## `snap_trip_financeiro`

Versiona os valores financeiros (`fare_amount`, `total_amount`,
`payment_type_id`) por `trip_id`. É uma **demonstração conceitual**: o fato da
TLC é imutável numa carga única, então o snapshot só cria uma 2ª versão se a
origem for reprocessada com um valor corrigido. O filtro por um único dia
(`2024-01-15`) é proposital, pra não snapshotar 11,7M linhas na Free Edition.

## Roteiro de teste (ver o SCD2 acontecer)

O snapshot **não** roda no `dbt build` — tem comando próprio: `dbt snapshot`.

**1. Primeira captura (versão 1 de tudo):**

```bash
dbt snapshot
```

Cria `workspace.silver.snap_trip_financeiro`. Todo trip do dia entra com
`dbt_valid_from` = agora e `dbt_valid_to` = null (versão vigente).

**2. Pega um trip pra usar de cobaia (no SQL Editor do Databricks):**

```sql
SELECT trip_id, total_amount
FROM workspace.silver.fct_trips
WHERE pickup_date_id = '2024-01-15'
LIMIT 1;
```

**3. Simula uma correção da TLC (altera o valor na origem):**

```sql
UPDATE workspace.silver.fct_trips
SET total_amount = total_amount + 5,
    fare_amount  = fare_amount + 5
WHERE trip_id = '<cole_o_trip_id_do_passo_2>';
```

**4. Segunda captura (o snapshot detecta a mudança):**

```bash
dbt snapshot
```

**5. Vê o histórico — duas versões da mesma corrida:**

```sql
SELECT trip_id, total_amount, dbt_valid_from, dbt_valid_to
FROM workspace.silver.snap_trip_financeiro
WHERE trip_id = '<mesmo_trip_id>'
ORDER BY dbt_valid_from;
```

Esperado: **2 linhas** — a antiga com `dbt_valid_to` preenchido (fechada) e a
nova com `dbt_valid_to` = null (vigente). Isso é SCD Type 2 na prática.

**6. (opcional) Restaura o valor real do fato:**

```bash
dbt run --select fct_trips --full-refresh
```

## Quando usar snapshot de verdade

Pergunte da tabela: *"uma linha da mesma chave é ATUALIZADA ao longo do tempo, e
eu me importo com os valores antigos?"* Se sim → snapshot (ex: dimensões cujos
atributos mudam). Se a linha é um evento imutável (como o fato de corridas) →
não precisa de snapshot; o próprio carimbo de tempo já é o histórico.
