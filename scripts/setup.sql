-- Copyright 2026 Snowflake Inc.
-- SPDX-License-Identifier: Apache-2.0
--
-- Apache License, Version 2.0（「ライセンス」）に基づいてライセンスされています。
-- ライセンスに準拠しない限り、このファイルを使用することはできません。
-- ライセンスのコピーは以下から入手できます：
--
-- http://www.apache.org/licenses/LICENSE-2.0
--
-- 適用法で要求されるか、書面で同意されない限り、ライセンスに基づいて
-- 配布されるソフトウェアは、「現状のまま」で配布され、
-- 明示または黙示を問わず、いかなる種類の保証または条件も含みません。
-- 権限と制限については、ライセンスを参照してください。

-- ============================================================================
-- FSI デモ セットアップスクリプト
-- 目的: AI SQL と Cortex Code を使用した定量リサーチのセットアップ
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- ============================================================================
-- Marketplace から Snowflake Public Data (Free) を自動インストール
-- 注意: 一部のアカウントでは手動での承認が必要な場合があります
-- ============================================================================
CREATE WAREHOUSE IF NOT EXISTS FSI_DEMO_WH WITH WAREHOUSE_SIZE = 'LARGE' AUTO_SUSPEND = 300 AUTO_RESUME = TRUE;
USE WAREHOUSE FSI_DEMO_WH;
CALL SYSTEM$REQUEST_LISTING_AND_WAIT('GZTSZ290BV255');
CALL SYSTEM$ACCEPT_LEGAL_TERMS('DATA_EXCHANGE_LISTING', 'GZTSZ290BV255');
CREATE DATABASE IF NOT EXISTS SNOWFLAKE_PUBLIC_DATA_FREE FROM LISTING 'GZTSZ290BV255';

-- トラッキング用のクエリタグを設定
ALTER SESSION SET query_tag = '{"origin":"sf_sit-is","name":"quantitative_research_aisql_cortex","version":{"major":1,"minor":0},"attributes":{"is_quickstart":1,"source":"sql"}}';

-- ============================================================================
-- セクション 1: ロールと権限のセットアップ
-- ============================================================================

CREATE ROLE IF NOT EXISTS FSI_DEMO_ROLE;
GRANT CREATE WAREHOUSE ON ACCOUNT TO ROLE FSI_DEMO_ROLE;
GRANT CREATE DATABASE ON ACCOUNT TO ROLE FSI_DEMO_ROLE;
GRANT CREATE INTEGRATION ON ACCOUNT TO ROLE FSI_DEMO_ROLE;

-- Snowflake Marketplace Free Public Data（インポートされたデータベース）へのアクセスを付与
GRANT IMPORTED PRIVILEGES ON DATABASE SNOWFLAKE_PUBLIC_DATA_FREE TO ROLE FSI_DEMO_ROLE;

SET CURRENT_USER = (SELECT CURRENT_USER());   
GRANT ROLE FSI_DEMO_ROLE TO USER IDENTIFIER($CURRENT_USER);

-- クロスリージョン Cortex 機能を有効化
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';

USE ROLE FSI_DEMO_ROLE;

-- ============================================================================
-- セクション 2: データベースとスキーマのセットアップ
-- ============================================================================

CREATE DATABASE IF NOT EXISTS FSI_DEMO_DB;
CREATE SCHEMA IF NOT EXISTS FSI_DEMO_DB.ANALYTICS;

-- FSI_DEMO_ROLE にデータベースとスキーマへの明示的な権限を付与
GRANT USAGE ON DATABASE FSI_DEMO_DB TO ROLE FSI_DEMO_ROLE;
GRANT ALL PRIVILEGES ON SCHEMA FSI_DEMO_DB.ANALYTICS TO ROLE FSI_DEMO_ROLE;
GRANT CREATE TABLE ON SCHEMA FSI_DEMO_DB.ANALYTICS TO ROLE FSI_DEMO_ROLE;
GRANT CREATE STAGE ON SCHEMA FSI_DEMO_DB.ANALYTICS TO ROLE FSI_DEMO_ROLE;

USE DATABASE FSI_DEMO_DB;
USE SCHEMA ANALYTICS;

-- ============================================================================
-- セクション 3: ウェアハウスとコンピュートプールのセットアップ
-- ============================================================================

CREATE OR REPLACE WAREHOUSE FSI_DEMO_WH WITH 
    WAREHOUSE_SIZE = 'LARGE'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE;

USE WAREHOUSE FSI_DEMO_WH;

-- コンテナノートブック用の専用コンピュートプールを作成
USE ROLE ACCOUNTADMIN;
CREATE COMPUTE POOL IF NOT EXISTS FSI_DEMO_COMPUTE_POOL
  MIN_NODES = 1
  MAX_NODES = 1
  INSTANCE_FAMILY = CPU_X64_M
  AUTO_SUSPEND_SECS = 300
  AUTO_RESUME = TRUE;

GRANT USAGE ON COMPUTE POOL FSI_DEMO_COMPUTE_POOL TO ROLE FSI_DEMO_ROLE;
USE ROLE FSI_DEMO_ROLE;

-- ============================================================================
-- セクション 4: Snowflake Intelligence と Cortex のセットアップ
-- ============================================================================

USE ROLE ACCOUNTADMIN;

-- クロスリージョン Cortex を有効化（Cortex 対応リージョン以外のアカウントで必要）
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';

-- Snowflake Intelligence オブジェクトを作成
CREATE SNOWFLAKE INTELLIGENCE IF NOT EXISTS SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;

-- Snowflake Intelligence の権限付与
GRANT CREATE SNOWFLAKE INTELLIGENCE ON ACCOUNT TO ROLE FSI_DEMO_ROLE;
GRANT USAGE ON SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT TO ROLE FSI_DEMO_ROLE;
GRANT MODIFY ON SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT TO ROLE FSI_DEMO_ROLE;
GRANT USAGE ON SNOWFLAKE INTELLIGENCE SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT TO ROLE PUBLIC;

-- AI/Cortex コンポーネント作成の権限付与
GRANT CREATE AGENT ON SCHEMA FSI_DEMO_DB.ANALYTICS TO ROLE FSI_DEMO_ROLE;
GRANT CREATE CORTEX SEARCH SERVICE ON SCHEMA FSI_DEMO_DB.ANALYTICS TO ROLE FSI_DEMO_ROLE;
GRANT CREATE SEMANTIC VIEW ON SCHEMA FSI_DEMO_DB.ANALYTICS TO ROLE FSI_DEMO_ROLE;

-- アカウントレベルの Cortex 権限（LLM 関数に必要）
GRANT BIND SERVICE ENDPOINT ON ACCOUNT TO ROLE FSI_DEMO_ROLE;

USE ROLE FSI_DEMO_ROLE;
USE DATABASE FSI_DEMO_DB;
USE SCHEMA ANALYTICS;

-- ============================================================================
-- セクション 5: テーブルのセットアップ
-- ============================================================================

-- FSI_DATA: Cybersyn 価格データから事前計算された特徴量
-- これにより高速なトレーニングが可能 - 特徴量はセットアップ時に一度だけ計算される
CREATE OR REPLACE TABLE FSI_DATA AS
WITH dow30_prices AS (
    -- Cybersyn から DOW 30 の株価を取得
    SELECT 
        ticker,
        date,
        value AS price
    FROM SNOWFLAKE_PUBLIC_DATA_FREE.PUBLIC_DATA_FREE.STOCK_PRICE_TIMESERIES
    WHERE ticker IN ('MMM', 'AXP', 'AMGN', 'AMZN', 'AAPL', 'BA', 'CAT', 'CVX', 'CSCO', 'KO', 'DIS', 'GS', 'HD', 'HON', 'IBM', 'JNJ', 'JPM', 'MCD', 'MRK', 'MSFT', 'NKE', 'PG', 'RTX', 'CRM', 'SHW', 'TRV', 'UNH', 'V', 'WMT', 'NVDA')
      AND variable = 'post-market_close'
      AND date >= '2020-01-01'
),
with_returns AS (
    SELECT 
        ticker,
        date,
        price,
        LN(price / LAG(price, 1) OVER (PARTITION BY ticker ORDER BY date)) AS return
    FROM dow30_prices
),
with_features AS (
    SELECT 
        ticker,
        date,
        price,
        return,
        -- r_1: 1日リターン
        return AS r_1,
        -- r_5_1: t-5からt-1までのリターン（4日間）
        LN(LAG(price, 1) OVER (PARTITION BY ticker ORDER BY date) / 
           LAG(price, 5) OVER (PARTITION BY ticker ORDER BY date)) AS r_5_1,
        -- r_10_5: t-10からt-5までのリターン（5日間）
        LN(LAG(price, 5) OVER (PARTITION BY ticker ORDER BY date) / 
           LAG(price, 10) OVER (PARTITION BY ticker ORDER BY date)) AS r_10_5,
        -- r_21_10: t-21からt-10までのリターン（11日間）
        LN(LAG(price, 10) OVER (PARTITION BY ticker ORDER BY date) / 
           LAG(price, 21) OVER (PARTITION BY ticker ORDER BY date)) AS r_21_10,
        -- r_63_21: t-63からt-21までのリターン（42日間）
        LN(LAG(price, 21) OVER (PARTITION BY ticker ORDER BY date) / 
           LAG(price, 63) OVER (PARTITION BY ticker ORDER BY date)) AS r_63_21,
        -- y: 目的変数 - t+2からt+6までのリターン（5日間先のリターン）
        LN(LEAD(price, 6) OVER (PARTITION BY ticker ORDER BY date) / 
           LEAD(price, 2) OVER (PARTITION BY ticker ORDER BY date)) AS y
    FROM with_returns
)
SELECT * FROM with_features
WHERE r_1 IS NOT NULL 
  AND r_5_1 IS NOT NULL 
  AND r_10_5 IS NOT NULL 
  AND r_21_10 IS NOT NULL 
  AND r_63_21 IS NOT NULL;

-- AI_TRANSCRIPTS_ANALYSTS_SENTIMENTS: Notebook 1 によって投入される
-- 注意: Notebook 1 は CREATE OR REPLACE を使用してデータを確実に投入する
CREATE TABLE IF NOT EXISTS AI_TRANSCRIPTS_ANALYSTS_SENTIMENTS (
    primary_ticker VARCHAR,
    event_timestamp TIMESTAMP_NTZ,
    event_type VARCHAR,
    created_at TIMESTAMP_NTZ,
    sentiment_score NUMBER(38,0),
    unique_analyst_count NUMBER(38,0),
    sentiment_reason VARCHAR
);

-- UNIQUE_TRANSCRIPTS: トランスクリプト重複排除用のステージングテーブル
CREATE OR REPLACE TABLE UNIQUE_TRANSCRIPTS (
    primary_ticker VARCHAR,
    event_timestamp TIMESTAMP_NTZ,
    event_type VARCHAR,
    created_at TIMESTAMP_NTZ,
    transcript VARIANT
);

-- Marketplace データから UNIQUE_TRANSCRIPTS を投入（DOW Jones 30 銘柄）
INSERT INTO UNIQUE_TRANSCRIPTS
WITH filtered_transcripts AS (
    SELECT *
    FROM SNOWFLAKE_PUBLIC_DATA_FREE.PUBLIC_DATA_FREE.COMPANY_EVENT_TRANSCRIPT_ATTRIBUTES
    WHERE primary_ticker IN ('MMM', 'AXP', 'AMGN', 'AMZN', 'AAPL', 'BA', 'CAT', 'CVX', 'CSCO', 'KO', 'DIS', 'GS', 'HD', 'HON', 'IBM', 'JNJ', 'JPM', 'MCD', 'MRK', 'MSFT', 'NKE', 'PG', 'RTX', 'CRM', 'SHW', 'TRV', 'UNH', 'V', 'WMT', 'NVDA')
      AND event_type = 'Earnings Call'
      AND transcript_type = 'SPEAKERS_ANNOTATED'
      AND transcript IS NOT NULL
      AND event_timestamp >= '2024-01-01'
    ORDER BY event_timestamp DESC
),
deduplicated_transcripts AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY primary_ticker, event_timestamp
            ORDER BY created_at ASC   -- 最も古いバージョンを保持（ポイントインタイム）
        ) AS rn
    FROM filtered_transcripts
)
SELECT
    primary_ticker,
    event_timestamp,
    event_type,
    created_at,
    transcript
FROM deduplicated_transcripts
WHERE rn = 1;

-- ============================================================================
-- セクション 7: ストアドプロシージャ
-- ============================================================================

-- 登録された ML モデルを使用した株式パフォーマンス予測器
CREATE OR REPLACE PROCEDURE GET_TOP_BOTTOM_STOCK_PREDICTIONS(
    MODEL_NAME STRING DEFAULT NULL,
    TOP_N INTEGER DEFAULT 5
)
RETURNS STRING
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python', 'pandas', 'numpy')
HANDLER = 'main'
EXECUTE AS OWNER
AS
$$
import pandas as pd
import json
import snowflake.snowpark as snowpark
import snowflake.snowpark.functions as F
from snowflake.snowpark.window import Window

def get_latest_model(session: snowpark.Session) -> str:
    """登録されている最新のMLモデルを動的に検索"""
    try:
        session.sql("SHOW MODELS LIKE 'FIS_%'").collect()
        result = session.sql("""
            SELECT "name" FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())) 
            ORDER BY "created_on" DESC LIMIT 1
        """).collect()
        if result:
            return result[0][0]
    except:
        pass
    return None

def parse_prediction(prediction_json):
    """MLモデル出力から予測JSONをパース"""
    try:
        if isinstance(prediction_json, str):
            prediction_dict = json.loads(prediction_json)
            return float(prediction_dict['output_feature_0'])
        elif isinstance(prediction_json, dict) and 'output_feature_0' in prediction_json:
            return float(prediction_json['output_feature_0'])
        else:
            return float(prediction_json)
    except:
        return None
        
def get_top_bottom_stock_predictions(session: snowpark.Session, 
                                   model_name: str = None,
                                   top_n: int = 5) -> str:
    """
    バッチ予測を使用して最大パフォーマンスで株式予測を生成。
    登録されたMLモデルを使用し、モメンタム特徴量に基づいて株式リターンを予測。
    model_nameが指定されない場合、自動的に最新のFIS_*モデルを使用。
    """
    
    try:
        # 指定がなければ最新モデルを自動検出
        if model_name is None or model_name.strip() == '':
            model_name = get_latest_model(session)
            if model_name is None:
                return "ERROR: MLモデルが見つかりません。先にTRAIN_ML_MODELSノートブックを実行してください。"
        
        # FSIデータソースの存在を検証
        fsi_table_name = "FSI_DATA"
        
        try:
            fsi_df = session.table(fsi_table_name)
            schema = fsi_df.schema
            column_names = [field.name for field in schema.fields]
            
            # カラムマッピングを検索
            ticker_col = None
            date_col = None
            price_col = None
            
            for col_name in column_names:
                clean_name = col_name.strip('"').upper()
                if clean_name in ['TICKER', 'SYMBOL']:
                    ticker_col = col_name
                elif clean_name in ['DATE', 'DT']:
                    date_col = col_name
                elif clean_name in ['PRICE', 'CLOSE', 'CLOSE_PRICE']:
                    price_col = col_name
            
            if not all([ticker_col, date_col, price_col]):
                return f"ERROR: FSI_DATAに必要なカラムがありません。検出: {column_names}。必要: ticker, date, price カラム。"
                
        except Exception as e:
            raise ValueError(f"""ERROR: {str(e)}""")
        
        # 事前計算された特徴量を確認
        feature_columns = {}
        for col_name in column_names:
            clean_name = col_name.strip('"').upper()
            if clean_name == 'R_1':
                feature_columns['r_1'] = col_name
            elif clean_name == 'R_5_1':
                feature_columns['r_5_1'] = col_name
            elif clean_name == 'R_10_5':
                feature_columns['r_10_5'] = col_name
            elif clean_name == 'R_21_10':
                feature_columns['r_21_10'] = col_name
            elif clean_name == 'R_63_21':
                feature_columns['r_63_21'] = col_name
        
        window_spec = Window.partition_by(F.col(ticker_col)).order_by(F.col(date_col).desc())
        
        # 完全な特徴量を持つ銘柄ごとの最新レコードを取得
        latest_features_df = fsi_df.filter(
            F.col(feature_columns['r_1']).is_not_null() &
            F.col(feature_columns['r_5_1']).is_not_null() &
            F.col(feature_columns['r_10_5']).is_not_null() &
            F.col(feature_columns['r_21_10']).is_not_null() &
            F.col(feature_columns['r_63_21']).is_not_null()
        ).with_column(
            "row_num", 
            F.row_number().over(window_spec)
        ).filter(
            F.col("row_num") == 1
        ).select(
            F.col(ticker_col).alias("ticker"),
            F.col(feature_columns['r_1']).alias("r_1"),
            F.col(feature_columns['r_5_1']).alias("r_5_1"),
            F.col(feature_columns['r_10_5']).alias("r_10_5"),
            F.col(feature_columns['r_21_10']).alias("r_21_10"),
            F.col(feature_columns['r_63_21']).alias("r_63_21")
        )
        
        # 登録モデルを使用したバッチ予測（完全修飾名を使用）
        batch_predictions_df = latest_features_df.with_column(
            "prediction_json",
            F.call_function(f"FSI_DEMO_DB.ANALYTICS.{model_name}!PREDICT", 
                          F.col("r_1"), 
                          F.col("r_5_1"), 
                          F.col("r_10_5"), 
                          F.col("r_21_10"), 
                          F.col("r_63_21"))
        ).select(
            F.col("ticker"),
            F.col("prediction_json")
        )
        
        prediction_results = batch_predictions_df.collect()
        
        # すべての予測を処理
        predictions = []
        for row in prediction_results:
            try:
                ticker = row[0]
                prediction_json = row[1]
                prediction_value = parse_prediction(prediction_json)
                
                if prediction_value is not None:
                    predictions.append((ticker, prediction_value))
                    
            except Exception as e:
                continue
        
        if not predictions:
            return "ERROR: どのシンボルに対しても有効な予測を生成できませんでした。"
        
        # 予測値で降順ソート
        predictions.sort(key=lambda x: x[1], reverse=True)
        
        # 上位N件と下位N件を取得
        top_n_results = predictions[:top_n]
        bottom_n_results = predictions[-top_n:] if len(predictions) >= top_n else []
        
        # 出力をフォーマット
        result = f"使用モデル: {model_name}\n\n"
        result += f"予測パフォーマンス 上位 {top_n}:\n"
        for i, (symbol, prediction) in enumerate(top_n_results, 1):
            result += f"{i}. {symbol}: {prediction:.6f}\n"
        
        if bottom_n_results:
            result += f"\n予測パフォーマンス 下位 {top_n}:\n"
            for i, (symbol, prediction) in enumerate(bottom_n_results, 1):
                result += f"{i}. {symbol}: {prediction:.6f}\n"
        
        return result
        
    except Exception as e:
        return f"ERROR 予測生成中: {str(e)}"

def main(session: snowpark.Session, model_name: str = None, top_n: int = 5) -> str:
    """ストアドプロシージャのメインハンドラー関数"""
    return get_top_bottom_stock_predictions(session, model_name, top_n)
$$;

-- メール通知インテグレーション（ACCOUNTADMIN が必要）
USE ROLE ACCOUNTADMIN;

CREATE OR REPLACE NOTIFICATION INTEGRATION EMAIL_INTEGRATION
  TYPE=EMAIL
  ENABLED=TRUE
  DEFAULT_SUBJECT = 'Snowflake Intelligence';

-- FSI_DEMO_ROLE にメールインテグレーションの使用権限を付与
GRANT USAGE ON INTEGRATION EMAIL_INTEGRATION TO ROLE FSI_DEMO_ROLE;

-- プロシージャ作成のために FSI_DEMO_ROLE に切り替え
USE ROLE FSI_DEMO_ROLE;
USE DATABASE FSI_DEMO_DB;
USE SCHEMA ANALYTICS;

CREATE OR REPLACE PROCEDURE SEND_EMAIL(
    RECIPIENT_EMAIL VARCHAR DEFAULT NULL,
    SUBJECT VARCHAR DEFAULT 'Snowflake Intelligence',
    BODY VARCHAR DEFAULT NULL
)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python')
HANDLER = 'send_email'
AS
$$
def send_email(session, recipient_email, subject, body):
    try:
        # 指定がなければ現在のユーザーのメールアドレスを取得
        if not recipient_email or recipient_email.strip() == '':
            result = session.sql("SELECT CURRENT_USER()").collect()
            current_user = result[0][0] if result else None
            if current_user:
                # SHOW USERS からユーザーのメールを取得
                session.sql(f"SHOW USERS LIKE '{current_user}'").collect()
                user_info = session.sql("SELECT \"email\" FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))").collect()
                if user_info and user_info[0][0]:
                    recipient_email = user_info[0][0]
                else:
                    return "エラー: 宛先メールアドレスを特定できませんでした。メールアドレスを指定してください。"
            else:
                return "エラー: 現在のユーザーを特定できませんでした。メールアドレスを指定してください。"
        
        # 指定がなければデフォルトの件名を使用
        if not subject or subject.strip() == '':
            subject = 'Snowflake Intelligence'
        
        # 本文が指定されているか確認
        if not body or body.strip() == '':
            return "エラー: メール本文は必須です。"
        
        # SQLインジェクション防止のためシングルクォートをエスケープ
        escaped_body = body.replace("'", "''")
        escaped_subject = subject.replace("'", "''")
        
        # システムプロシージャを実行
        session.sql(f"""
            CALL SYSTEM$SEND_EMAIL(
                'EMAIL_INTEGRATION',
                '{recipient_email}',
                '{escaped_subject}',
                '{escaped_body}',
                'text/html'
            )
        """).collect()
        
        return f'メールを {recipient_email} に送信しました。件名: "{subject}"'
    except Exception as e:
        return f"メール送信エラー: {str(e)}"
$$;

-- ロールにプロシージャの使用権限を付与
GRANT USAGE ON PROCEDURE GET_TOP_BOTTOM_STOCK_PREDICTIONS(STRING, INTEGER) TO ROLE FSI_DEMO_ROLE;
GRANT USAGE ON PROCEDURE SEND_EMAIL(VARCHAR, VARCHAR, VARCHAR) TO ROLE FSI_DEMO_ROLE;

-- ============================================================================
-- セクション 8: 自動ノートブックデプロイ用の Git インテグレーション
-- ============================================================================

USE ROLE FSI_DEMO_ROLE;
USE DATABASE FSI_DEMO_DB;
USE SCHEMA ANALYTICS;

-- API インテグレーション作成のため ACCOUNTADMIN に切り替え
USE ROLE ACCOUNTADMIN;

-- パブリックリポジトリ用の Git API インテグレーションを作成
CREATE OR REPLACE API INTEGRATION GIT_HTTPS_API
  API_PROVIDER = GIT_HTTPS_API
  API_ALLOWED_PREFIXES = ('https://github.com/')
  ENABLED = TRUE;

GRANT USAGE ON INTEGRATION GIT_HTTPS_API TO ROLE FSI_DEMO_ROLE;

-- Git リポジトリ作成のため FSI_DEMO_ROLE に切り替え
USE ROLE FSI_DEMO_ROLE;
USE DATABASE FSI_DEMO_DB;
USE SCHEMA ANALYTICS;

-- Git リポジトリを作成（パブリックリポジトリ - 認証情報不要）
CREATE OR REPLACE GIT REPOSITORY FSI_DEMO_REPO
  API_INTEGRATION = GIT_HTTPS_API
  ORIGIN = 'https://github.com/Snowflake-Labs/sfguide-quantitative-research-ai-functions-and-cortex-code.git';

-- リポジトリから最新コードをフェッチ
ALTER GIT REPOSITORY FSI_DEMO_REPO FETCH;

-- ウェアハウスノートブックを作成（ML トレーニング用に高速）
-- 注意: ウェアハウスノートブックは Python と SQL の両方をウェアハウスで実行
CREATE OR REPLACE NOTEBOOK START_HERE
  FROM '@FSI_DEMO_REPO/branches/main/notebooks'
  MAIN_FILE = '0_start_here.ipynb'
  QUERY_WAREHOUSE = FSI_DEMO_WH
  IDLE_AUTO_SHUTDOWN_TIME_SECONDS = 3600;

ALTER NOTEBOOK START_HERE ADD LIVE VERSION FROM LAST;

CREATE OR REPLACE NOTEBOOK TRAIN_ML_MODELS
  FROM '@FSI_DEMO_REPO/branches/main/notebooks'
  MAIN_FILE = '1_train_and_register_ml_models.ipynb'
  QUERY_WAREHOUSE = FSI_DEMO_WH
  IDLE_AUTO_SHUTDOWN_TIME_SECONDS = 3600;

ALTER NOTEBOOK TRAIN_ML_MODELS ADD LIVE VERSION FROM LAST;

CREATE OR REPLACE NOTEBOOK CREATE_CORTEX_COMPONENTS
  FROM '@FSI_DEMO_REPO/branches/main/notebooks'
  MAIN_FILE = '2_create_cortex_components.ipynb'
  QUERY_WAREHOUSE = FSI_DEMO_WH
  IDLE_AUTO_SHUTDOWN_TIME_SECONDS = 3600;

ALTER NOTEBOOK CREATE_CORTEX_COMPONENTS ADD LIVE VERSION FROM LAST;

-- ============================================================================
-- セクション 9: 完了
-- ============================================================================

SELECT 'セットアップが正常に完了しました！次のステップ:' AS STATUS,
       '1. ノートブック実行: START_HERE (AI Functions を使用してセンチメントを抽出)' AS STEP_1,
       '2. ノートブック実行: TRAIN_ML_MODELS (ML モデルをトレーニングして登録)' AS STEP_2,
       '3. スクリプト実行: create_cortex_components.sql (Cortex Search, Semantic View, Agent を作成)' AS STEP_3;
