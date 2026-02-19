# Cortex Code と AI Functions を使用した Snowflake パブリックデータによるクオンツリサーチとデータサイエンス

Snowflake Cortex AI、ML Model Registry、インテリジェントエージェントを使用して、非構造化の決算説明会トランスクリプトを実用的な投資インサイトに変換します。すべて **Cortex Code** で加速できます。

## なぜこれが重要か

金融アナリストは決算説明会トランスクリプトの手動レビューに膨大な時間を費やしています。このガイドでは、**AI Functions**（`AI_COMPLETE`、`AI_SQL`）を使用して**非構造化データを大規模に体系的に処理する方法**を示します。生のトランスクリプトテキストを、定量モデルに直接取り込める構造化されたセンチメントスコア、アナリスト参加指標、投資シグナルに変換します。

> **詳細ガイド:** アーキテクチャ、ビジネスインパクト、ユースケースの詳細については、[Snowflake Developers Guide](https://www.snowflake.com/en/developers/guides/quantitative-research-with-ai-functions-and-cortex-code/) を参照してください。

## 作成者

**Harry Yu**  
Senior Data Scientist, Finance | Snowflake  
📧 [h.yu@snowflake.com](mailto:h.yu@snowflake.com) | 💻 [GitHub](https://github.com/sfc-gh-harryu)

---

## 学べること
- **Cortex Code** を使用して自然言語で ML パイプライン全体を構築する方法
- `AI_COMPLETE()` を使用して非構造化テキストから構造化インサイトを抽出する方法
- Snowflake の Model Registry で ML モデルを学習・登録する方法
- Cortex Search で非構造化データに対するセマンティック検索を作成する方法
- Cortex Analyst を介した自然言語 SQL クエリのための Semantic View を構築する方法
- 複数の AI ツールを統合した Cortex Agent を構築する方法
- Snowflake Intelligence を通じてエージェントにアクセスする方法

## 構築するもの
- `AI_COMPLETE()` を使用して決算説明会トランスクリプトをスコアリング（1-10 スケール）する**センチメント分析パイプライン**
- ウォークフォワード検証を備え、Snowflake Model Registry に登録された **LightGBM 株価予測モデル**
- センチメントインサイトに対するセマンティック検索のための **Cortex Search サービス**
- Cortex Analyst を介した自然言語クエリを可能にする **Semantic View**
- ML 予測、構造化クエリ、セマンティック検索、メール通知を統合し、Snowflake Intelligence からアクセス可能な **Cortex Agent**

## 前提条件

- `ACCOUNTADMIN` アクセス権を持つ Snowflake アカウント（[無料トライアルにサインアップ](https://signup.snowflake.com/)）（下記の注意を参照）

> **権限に関する注意:** このガイドでは、デモおよび学習環境での簡便さのために `ACCOUNTADMIN` を使用しています。本番環境では、最小権限の原則に従い、必要な特定の権限のみを持つ専用ロールを作成してください。

## はじめに

### ステップ 1: セットアップスクリプトの実行

1. Snowsight で **Projects > Workspaces** に移動
2. 新しい SQL ファイルを作成し、[`scripts/setup.sql`](https://github.com/Snowflake-Labs/sfguide-quantitative-research-ai-functions-and-cortex-code/blob/main/scripts/setup.sql) の内容をコピー
3. スクリプト全体を実行

これにより、以下を含む完全なデモ環境が作成されます:
- **Snowflake Public Data (Free)** を Marketplace から自動インストール
- データベース、ウェアハウス、ロールのセットアップ
- 事前計算された ML 特徴量（`FSI_DATA` テーブル）
- テーブル、ストアドプロシージャ、ML モデルインフラストラクチャ
- このリポジトリからリファレンスノートブックをデプロイ

### ステップ 2: パスを選択

| パス | 説明 |
|------|------|
| **[パス A: Cortex Code](#パス-a-cortex-code推奨)** | 自然言語プロンプトですべてを構築 |
| **[パス B: ノートブック](#パス-b-ノートブックオプション)** | 事前構築されたノートブックを実行 |

---

## パス A: Cortex Code（推奨）

Cortex Code との対話を通じて、クオンツリサーチパイプライン全体を構築します。

### A0: セットアップスクリプトの実行

開始前に、必要なデータベースオブジェクトを作成するセットアップスクリプトを実行します:

1. Snowsight で SQL ワークシートを開く
2. [scripts/setup.sql](https://github.com/Snowflake-Labs/sfguide-quantitative-research-ai-functions-and-cortex-code/blob/main/scripts/setup.sql) の内容をコピーして実行

これにより、ラボに必要なデータベース、スキーマ、ロール、ウェアハウス、ベーステーブルが作成されます。

### A1: 新しいノートブックの作成

1. Snowsight で **Projects → Notebooks** に移動
2. **+ Notebook**（右上）をクリック
3. ノートブックを設定:
   - **Notebook location:** `FSI_DEMO_DB` → `ANALYTICS`
   - **Notebook warehouse:** `FSI_DEMO_WH`
4. **Create** をクリック
5. 自動入力されたサンプルセルを削除（セルを選択 → 削除）
6. Python セルを追加し、以下のスターターコードを実行:

```python
import pandas as pd
import numpy as np
from snowflake.snowpark.context import get_active_session
session = get_active_session()
session.use_role("FSI_DEMO_ROLE")
session.use_warehouse("FSI_DEMO_WH")
session.use_database("FSI_DEMO_DB")
session.use_schema("ANALYTICS")
```

7. **Packages**（トップメニュー）をクリックして以下を追加:
   - `lightgbm`
   - `scikit-learn`
   - `snowflake-ml-python`
   - `matplotlib`
   - `seaborn`
   - `statsmodels`

8. **Start** をクリックしてノートブックを起動

### A2: Cortex Code を開く

ノートブックの右下隅にある **Cortex Code アイコン** をクリックします。

> **ヒント:** 最初のプロンプトの前にページを更新すると、Cortex Code がノートブックコンテキストを認識しやすくなります。

### A3: プロンプトを順番に実行

以下のプロンプトを1つずつ使用します。次のプロンプトに進む前に、各プロンプトで生成されたコードを実行してください。

> **ヒント:** 生成されたコードを実行する方法は複数あります:
> - **+** ボタンをクリックしてノートブックに新しいセルとして追加
> - Cortex Code が提供する **Run** オプションを使用
> - **再生ボタン** をクリックしてチャットインターフェース内で実行

---

#### プロンプト 1: AI センチメント抽出

```
Using FSI_DEMO_DB.ANALYTICS.UNIQUE_TRANSCRIPTS table, extract analyst sentiment from earnings call transcripts.

Use AI_COMPLETE with claude-4-sonnet to analyze each transcript. Focus ONLY on analyst questions and tone (ignore management remarks). Score sentiment on 1-10 scale where 1=extremely negative, 5=neutral, 10=extremely positive.

Return JSON with: score (1-10), reason (brief explanation), analyst_count (number of unique analysts).

Insert results into AI_TRANSCRIPTS_ANALYSTS_SENTIMENTS table with columns: PRIMARY_TICKER, EVENT_TIMESTAMP, EVENT_TYPE, CREATED_AT, SENTIMENT_SCORE, UNIQUE_ANALYST_COUNT, SENTIMENT_REASON.

Filter out events with analyst_count <= 1.
```

![プロンプト 1: AI センチメント抽出](assets/prompt-1.gif)

---

#### プロンプト 2: ML モデルの学習と登録

```
Using FSI_DEMO_DB.ANALYTICS.FSI_DATA table which has columns: ticker, date, price, r_1, r_5_1, r_10_5, r_21_10, r_63_21, and y (target).

Train a quarterly walk-forward LightGBM regression model:
- Features: r_1, r_5_1, r_10_5, r_21_10, r_63_21
- Target: y (5-day forward return)
- For each test quarter Q: train on quarters < Q-2, validate on Q-2 and Q-1, test on Q
- Use L2 metric with early stopping (200 rounds patience)
- Hyperparameter grid: learning_rate [0.03, 0.05, 0.10], num_leaves [31, 63]

Register each quarter's best model to Snowflake Model Registry as FIS_{quarter} (e.g., FIS_2024Q3, FIS_2025Q1) with:
- version_name="v1"
- sample_input_data from training data (100 rows)
- options={"relax_version": False, "target_methods": ["predict"], "method_options": {"predict": {"case_sensitive": True}}}

Do NOT pass metrics to log_model. Do NOT use target_methods as a separate parameter.
```

![プロンプト 2: ML モデルの学習と登録](assets/prompt-2.png)

---

#### プロンプト 3: Cortex Search Service の作成

```
Create a Cortex Search Service named DOW_ANALYSTS_SENTIMENT_ANALYSIS in FSI_DEMO_DB.ANALYTICS schema.

Source table: AI_TRANSCRIPTS_ANALYSTS_SENTIMENTS
Search column: SENTIMENT_REASON
Columns to return: PRIMARY_TICKER, EVENT_TIMESTAMP, SENTIMENT_SCORE, UNIQUE_ANALYST_COUNT, SENTIMENT_REASON
Warehouse: FSI_DEMO_WH
Target lag: 1 day
```

![プロンプト 3: Cortex Search Service の作成](assets/prompt-3.png)

---

#### プロンプト 4: Semantic View の作成

```
Create a Semantic View named ANALYST_SENTIMENTS_VIEW in FSI_DEMO_DB.ANALYTICS schema for natural language queries on analyst sentiment data.

Source table: AI_TRANSCRIPTS_ANALYSTS_SENTIMENTS

Dimensions:
- PRIMARY_TICKER: Company stock ticker symbol
- EVENT_TIMESTAMP: Date and time of the earnings call
- EVENT_TYPE: Type of event (Earnings Call)

Measures:
- SENTIMENT_SCORE: Analyst sentiment rating from 1-10
- UNIQUE_ANALYST_COUNT: Number of unique analysts participating

Include SENTIMENT_REASON as descriptive text field for qualitative insights.
```

![プロンプト 4: Semantic View の作成](assets/prompt-4.png)

---

#### プロンプト 5: エージェントの作成

```
Create a Cortex Agent named QUANTITATIVE_RESEARCH_AGENT in FSI_DEMO_DB.ANALYTICS schema.

Display name: "Quantitative Research Agent"

Instructions/System prompt:
"You are a quantitative research assistant specializing in Dow Jones 30 stock analysis. You help users with:
1. ML-based stock predictions - Use GET_TOP_BOTTOM_STOCK_PREDICTIONS to get top/bottom ranked stocks by predicted 5-day returns
2. Analyst sentiment queries - Query structured sentiment data (scores, analyst counts) via the semantic view
3. Sentiment insights - Search earnings call transcripts for qualitative analyst commentary
4. Email alerts - Send portfolio recommendations or research summaries via email

When asked about stock picks or predictions, always use the ML prediction tool first. When asked about analyst opinions or sentiment, combine both the semantic view (for scores) and search service (for reasoning). Be concise and data-driven in responses."

Sample questions:
- "What are the top 5 stocks to buy this week based on ML predictions?"
- "Which stocks have the most positive analyst sentiment?"
- "What did analysts say about Apple's last earnings call?"
- "Show me stocks with bullish sentiment but negative ML predictions"
- "Email me a summary of this week's top stock picks"

Tools to include (use SQL CREATE AGENT syntax with tool_resources array):
1. Semantic view tool: type='semantic_view', identifier='FSI_DEMO_DB.ANALYTICS.ANALYST_SENTIMENTS_VIEW'
2. Cortex search tool: type='cortex_search', identifier='FSI_DEMO_DB.ANALYTICS.DOW_ANALYSTS_SENTIMENT_ANALYSIS'
3. Procedure tool (ML predictions): type='procedure', identifier='FSI_DEMO_DB.ANALYTICS.GET_TOP_BOTTOM_STOCK_PREDICTIONS', execution_environment='sandbox'
   - Parameters: MODEL_NAME (STRING, optional - auto-detects latest model if NULL), TOP_N (INTEGER, default 5 - returns both top N and bottom N stocks)
   - Returns ranked stocks by predicted 5-day forward returns
4. Procedure tool (email): type='procedure', identifier='FSI_DEMO_DB.ANALYTICS.SEND_EMAIL', execution_environment='sandbox'
   - Parameters: RECIPIENT_EMAIL (VARCHAR, optional - uses current user's email if NULL), SUBJECT (VARCHAR), BODY (VARCHAR)

IMPORTANT: For procedure tools, you must include execution_environment='sandbox' in the tool_resources.

Model: claude-3-5-sonnet
Warehouse: FSI_DEMO_WH
```

![プロンプト 5: エージェントの作成](assets/prompt-5.png)

---

#### プロンプト 6: Snowflake Intelligence への登録

```
Register the agent FSI_DEMO_DB.ANALYTICS.QUANTITATIVE_RESEARCH_AGENT with Snowflake Intelligence object SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT so users can interact with it conversationally.
```

---

### A3: エージェントのテスト

**AI & ML → Snowflake Intelligence** に移動し、**Quantitative Research Agent** を選択します。以下を試してください:

**ML 予測:**
```
次の期間のトップ3とボトム3の取引予測を教えて
```

**センチメントクエリ:**
```
センチメントスコアが最も高い企業は？
```

**セマンティック検索:**
```
マージンに懸念がある企業を検索
```

**複合分析:**
```
予測上位銘柄とそのアナリストセンチメントスコアを比較
```

**メールレポート:**
> **注意:** メール機能を使用するには、Snowflake ユーザーに検証済みメールアドレスが必要です。Snowsight でメールを確認: ユーザーメニュー → Setting → Profile → Verify Email

```
本日のトップ銘柄の概要をメールで送信して
```

---

### オプションプロンプト（学習・理解用）

これらのプロンプトは深い探索のためのもので、エージェントには必須ではありません。

<details>
<summary><b>オプションプロンプト A: 特徴量エンジニアリング（ゼロから）</b></summary>

> **注意:** これは `setup.sql` で既に実行されており、事前計算された特徴量を持つ `FSI_DATA` テーブルが作成されています。特徴量エンジニアリングプロセスを理解または再作成したい場合にこのプロンプトを使用してください。

```
Using SNOWFLAKE_PUBLIC_DATA_FREE.PUBLIC_DATA_FREE.STOCK_PRICE_TIMESERIES for Dow Jones 30 stocks (MMM, AXP, AMGN, AMZN, AAPL, BA, CAT, CVX, CSCO, KO, DIS, GS, HD, HON, IBM, JNJ, JPM, MCD, MRK, MSFT, NKE, PG, RTX, CRM, SHW, TRV, UNH, V, WMT, NVDA).

Construct momentum features using log returns:
- r_1: today's return
- r_5_1: return from t-4 to t-1
- r_10_5: return from t-9 to t-5
- r_21_10: return from t-20 to t-11
- r_63_21: return from t-62 to t-21

Construct target variable y: future return from t+2 to t+6.

Keep as panel data with ticker as a column.
```
</details>

<details>
<summary><b>オプションプロンプト B: バックテスト戦略</b></summary>

```
Test if the ML strategy works starting 2021.

Portfolio construction:
- Generate forecasts on Tuesdays
- At Wednesday close, go long top-5 and short bottom-5 by predicted return (equal weight)
- Hold through Thursday to next Wednesday (the t+2..t+6 window)
- Transaction cost: 3.0 bps one-way via weekly turnover

Show metrics:
- Information Ratio (before/after costs)
- Max drawdown
- Calmar ratio

Plot equity curves for before and after costs.
```
</details>

<details>
<summary><b>オプションプロンプト C: センチメント-リターン回帰分析</b></summary>

```
Analyze the relationship between analyst sentiment and stock returns.

Merge sentiment data with price data using merge_asof (forward direction).

Create:
- 1D return: reaction during earnings call
- 3D return: return_lead_1 + return_lead_2 + return_lead_3 (post-earnings drift)

Run OLS regression: return ~ sentiment_score
Winsorize returns at 1st/99th percentiles.

Create scatter plots showing:
- Sentiment Score vs 1D Return with OLS fit line, β, t-stat
- Sentiment Score vs 3D Return with OLS fit line, β, t-stat

Repeat analysis using sentiment_change (vs previous earnings call).
```
</details>

---

## パス B: ノートブック（オプション）

Cortex Code プロンプトの代わりに事前構築されたコードを実行したい場合:

### B1: START_HERE ノートブックの実行
1. **Projects > Notebooks** に移動
2. ロールを `FSI_DEMO_ROLE` に切り替え
3. `START_HERE` ノートブックを開く
4. すべてのセルを実行して AI Functions を使用したアナリストセンチメントを抽出

*プロンプト 1 と同等*

### B2: TRAIN_ML_MODELS ノートブックの実行
1. `TRAIN_ML_MODELS` ノートブックを開く
2. すべてのセルを実行して ML モデルを学習・登録

*プロンプト 2 と同等*

### B3: CREATE_CORTEX_COMPONENTS ノートブックの実行
1. `CREATE_CORTEX_COMPONENTS` ノートブックを開く
2. すべてのセルを実行して Cortex Search、Semantic View、Agent を作成

*プロンプト 3-6 と同等*

### B4: エージェントのテスト
**AI & ML → Snowflake Intelligence** に移動し、**Quantitative Research Agent** を選択します。

---

## Cortex Code パワームーブ

ガイド付きプロンプト以外にも、Cortex Code でできること:

### 探索と理解
```
FSI_DEMO_DB.ANALYTICS にはどんなテーブルがある？それぞれを説明して。
```
```
このノートブックをセルごとに説明して
```

### デバッグと修正
```
このセルがエラーを出している - 修正を手伝って
```
```
モデルの予測が NULL を返すのはなぜ？
```

### 結果の分析
```
モデルの特徴量重要度を要約して
```
```
予測誤差が最も大きかった銘柄は？
```

---

## クリーンアップ

すべてのデモオブジェクトを削除するには:

1. **Projects > Workspaces** に移動
2. [`scripts/teardown.sql`](https://github.com/Snowflake-Labs/sfguide-quantitative-research-ai-functions-and-cortex-code/blob/main/scripts/teardown.sql) の内容で新しい SQL ファイルを作成
3. スクリプトを実行

---

## 次のステップ

Snowflake 内で完全な AI 駆動のクオンツリサーチパイプラインを構築しました。ここから:

- **カバレッジを拡大** - DOW 30 以外の企業を追加
- **新しい特徴量を追加** - Cortex Code を使用してテクニカル指標（RSI、MACD）を追加
- **モデルを改善** - 異なるアルゴリズムを試す
- **ダッシュボードを構築** - 可視化のための Streamlit アプリを作成
- **更新を自動化** - Snowflake Tasks で日次予測をスケジュール

**Cortex Code** を使用してすべてを支援してもらえます。構築したいものを説明するだけです。

---

## リソース

- [Cortex Code ドキュメント](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code)
- [Cortex AI Functions](https://docs.snowflake.com/en/user-guide/snowflake-cortex/aisql)
- [Cortex Search](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-search/cortex-search-overview)
- [Cortex Analyst](https://docs.snowflake.com/en/user-guide/snowflake-cortex/cortex-analyst)
- [Snowflake Intelligence](https://docs.snowflake.com/en/user-guide/snowflake-intelligence/overview)
- [Snowflake ML Model Registry](https://docs.snowflake.com/en/developer-guide/snowflake-ml/model-registry/overview)
- [Snowflake Notebooks](https://docs.snowflake.com/en/user-guide/ui-snowsight/notebooks)

## ライセンス

Copyright (c) Snowflake Inc. All rights reserved.

このリポジトリのコードは Apache 2.0 ライセンスの下でライセンスされています。
