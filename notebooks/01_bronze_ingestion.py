# Databricks notebook source
# /// script
# [tool.databricks.environment]
# environment_version = "5"
# ///
# MAGIC %md
# MAGIC # 01_bronze_ingestion
# MAGIC
# MAGIC Lê os Parquets da camada raw do S3 (`s3://eduardo-personal-data-projects/raw/nyc_taxi/`)
# MAGIC e grava como tabela Delta na camada bronze (`workspace.bronze.nyc_taxi_trips`),
# MAGIC adicionando colunas técnicas de ingestão (`_ingested_at`, `_source_file`).
# MAGIC
# MAGIC Roda num compute Serverless do Databricks (Unity Catalog). Por isso o Spark não
# MAGIC pode ler direto de `file:/tmp/...` (restrição de isolamento do Serverless) — o
# MAGIC arquivo é baixado do S3 pro disco local via boto3, lido com pandas, e só depois
# MAGIC convertido pra Spark DataFrame.
# MAGIC
# MAGIC Credenciais da AWS vêm do secret scope `aws` (nunca hardcoded no notebook).

# COMMAND ----------

import boto3

access_key = dbutils.secrets.get(scope="aws", key="access_key_id")
secret_key = dbutils.secrets.get(scope="aws", key="secret_access_key")

s3 = boto3.client(
    "s3",
    aws_access_key_id=access_key,
    aws_secret_access_key=secret_key,
    region_name="us-east-2",
)

bucket = "eduardo-personal-data-projects"
prefix = "raw/nyc_taxi/"

response = s3.list_objects_v2(Bucket=bucket, Prefix=prefix)
keys = [obj["Key"] for obj in response.get("Contents", []) if obj["Key"].endswith(".parquet")]
print(f"{len(keys)} arquivos encontrados:", keys)

# COMMAND ----------

import pandas as pd
from pyspark.sql import functions as F

CATALOG = "workspace"
SCHEMA = "bronze"

spark.sql(f"CREATE SCHEMA IF NOT EXISTS {CATALOG}.{SCHEMA}")

for key in keys:
    local_path = f"/tmp/{key.split('/')[-1]}"
    s3.download_file(bucket, key, local_path)

    pdf = pd.read_parquet(local_path)

    df = (
        spark.createDataFrame(pdf)
        .withColumn("_ingested_at", F.current_timestamp())
        .withColumn("_source_file", F.lit(key))
    )

    (
        df.write
        .format("delta")
        .mode("append")
        .option("mergeSchema", "true")
        .saveAsTable(f"{CATALOG}.{SCHEMA}.nyc_taxi_trips")
    )

    print(f"Gravado: {key}")

print("Ingestão bronze concluída.")

# COMMAND ----------

# MAGIC %md ## Validação

# COMMAND ----------

spark.sql("""
    SELECT
        COUNT(*) AS total_linhas,
        MIN(_ingested_at) AS primeiro_ingest,
        COUNT(DISTINCT _source_file) AS arquivos_distintos
    FROM workspace.bronze.nyc_taxi_trips
""").show()

# COMMAND ----------

# MAGIC %sql
# MAGIC SELECT COUNT(*) FROM workspace.gold.dim_zone;

# COMMAND ----------

# MAGIC %sql
# MAGIC SELECT pickup_date_id, COUNT(*) AS corridas
# MAGIC FROM workspace.gold.fct_trips
# MAGIC WHERE pickup_date_id NOT BETWEEN DATE'2024-01-01' AND DATE'2024-12-31'
# MAGIC GROUP BY pickup_date_id
# MAGIC ORDER BY pickup_date_id;

# COMMAND ----------

# MAGIC %sql
# MAGIC SELECT * FROM workspace.gold.agg_corridas_por_mes ORDER BY mes_referencia;
# MAGIC --SELECT * FROM workspace.gold.agg_corridas_por_vendor;