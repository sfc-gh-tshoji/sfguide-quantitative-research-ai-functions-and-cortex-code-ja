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

/*-----------------------------------------------------------------------------
  FSI AI SQL & Data Science Agent デモ - 削除スクリプト
  
  このスクリプトはデモで作成されたすべてのオブジェクトを削除します。
  
  警告: すべてのデータとオブジェクトが完全に削除されます！
  
  デモ完了後にこのスクリプトを実行してクリーンアップしてください。
-----------------------------------------------------------------------------*/

USE ROLE FSI_DEMO_ROLE;

-- ============================================================================
-- Snowflake Intelligence Agent の削除
-- ============================================================================
DROP AGENT IF EXISTS FSI_DEMO_DB.ANALYTICS.QUANTITATIVE_RESEARCH_AGENT;

-- ============================================================================
-- Cortex Search Service の削除
-- ============================================================================
DROP CORTEX SEARCH SERVICE IF EXISTS FSI_DEMO_DB.ANALYTICS.DOW_ANALYSTS_SENTIMENT_ANALYSIS;

-- ============================================================================
-- Semantic View の削除
-- ============================================================================
DROP SEMANTIC VIEW IF EXISTS FSI_DEMO_DB.ANALYTICS.ANALYST_SENTIMENTS_VIEW;

-- ============================================================================
-- ノートブックの削除
-- ============================================================================
DROP NOTEBOOK IF EXISTS FSI_DEMO_DB.ANALYTICS.START_HERE;
DROP NOTEBOOK IF EXISTS FSI_DEMO_DB.ANALYTICS.TRAIN_ML_MODELS;
DROP NOTEBOOK IF EXISTS FSI_DEMO_DB.ANALYTICS.CREATE_CORTEX_COMPONENTS;

-- ============================================================================
-- レジストリからMLモデルを削除（作成されている場合）
-- ============================================================================
-- 注意: モデル名はトレーニング実行時に基づいて FIS_{YEAR}Q{QUARTER} となります。
-- 既存のモデルは以下で確認: SHOW MODELS IN SCHEMA FSI_DEMO_DB.ANALYTICS;
-- 各モデルを削除する例:
-- DROP MODEL IF EXISTS FSI_DEMO_DB.ANALYTICS.FIS_2024Q4;
-- DROP MODEL IF EXISTS FSI_DEMO_DB.ANALYTICS.FIS_2025Q1;
-- DROP MODEL IF EXISTS FSI_DEMO_DB.ANALYTICS.FIS_2025Q2;
-- DROP MODEL IF EXISTS FSI_DEMO_DB.ANALYTICS.FIS_2025Q3;
-- DROP MODEL IF EXISTS FSI_DEMO_DB.ANALYTICS.FIS_2025Q4;

-- ============================================================================
-- ストアドプロシージャの削除
-- ============================================================================
DROP PROCEDURE IF EXISTS FSI_DEMO_DB.ANALYTICS.GET_TOP_BOTTOM_STOCK_PREDICTIONS(STRING, INTEGER);
DROP PROCEDURE IF EXISTS FSI_DEMO_DB.ANALYTICS.SEND_EMAIL(VARCHAR, VARCHAR, VARCHAR);

-- ============================================================================
-- テーブルの削除
-- ============================================================================
DROP TABLE IF EXISTS FSI_DEMO_DB.ANALYTICS.FSI_DATA;
DROP TABLE IF EXISTS FSI_DEMO_DB.ANALYTICS.AI_TRANSCRIPTS_ANALYSTS_SENTIMENTS;
DROP TABLE IF EXISTS FSI_DEMO_DB.ANALYTICS.UNIQUE_TRANSCRIPTS;

-- ============================================================================
-- Git リポジトリの削除
-- ============================================================================
DROP GIT REPOSITORY IF EXISTS FSI_DEMO_DB.ANALYTICS.FSI_DEMO_REPO;

-- ============================================================================
-- ステージの削除（現在使用なし）
-- ============================================================================
-- 注意: SEMANTIC_MODELS ステージは削除済み - 代わりに Semantic View を使用

-- ============================================================================
-- 通知インテグレーションの削除（ACCOUNTADMIN が必要）
-- ============================================================================
USE ROLE ACCOUNTADMIN;
DROP NOTIFICATION INTEGRATION IF EXISTS EMAIL_INTEGRATION;

-- ============================================================================
-- Git API インテグレーションの削除
-- ============================================================================
DROP API INTEGRATION IF EXISTS GIT_HTTPS_API;

-- ============================================================================
-- データベースの削除
-- ============================================================================
USE ROLE FSI_DEMO_ROLE;
DROP DATABASE IF EXISTS FSI_DEMO_DB;

-- ============================================================================
-- ウェアハウスの削除
-- ============================================================================
DROP WAREHOUSE IF EXISTS FSI_DEMO_WH;

-- ============================================================================
-- コンピュートプールの削除（ACCOUNTADMIN が必要）
-- ============================================================================
USE ROLE ACCOUNTADMIN;
DROP COMPUTE POOL IF EXISTS FSI_DEMO_COMPUTE_POOL;

-- ============================================================================
-- Snowflake Intelligence オブジェクトの削除
-- ============================================================================
DROP SNOWFLAKE INTELLIGENCE IF EXISTS SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT;

-- ============================================================================
-- デモロールの削除
-- ============================================================================
DROP ROLE IF EXISTS FSI_DEMO_ROLE;

SELECT '削除が正常に完了しました！' AS STATUS;
