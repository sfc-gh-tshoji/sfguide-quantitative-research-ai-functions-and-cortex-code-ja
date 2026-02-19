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
FSI_DEMO_DB.ANALYTICS.UNIQUE_TRANSCRIPTS テーブルを使用して、決算説明会トランスクリプトからアナリストセンチメントを抽出してください。

AI_COMPLETE と claude-4-sonnet を使用して各トランスクリプトを分析します。アナリストの質問とトーンのみに焦点を当て（経営陣の発言は無視）、センチメントを1-10スケールでスコアリングしてください（1=極めてネガティブ、5=中立、10=極めてポジティブ）。

JSONで以下を返してください: score (1-10)、reason (簡単な説明)、analyst_count (ユニークアナリスト数)。

結果を AI_TRANSCRIPTS_ANALYSTS_SENTIMENTS テーブルに挿入してください。カラム: PRIMARY_TICKER, EVENT_TIMESTAMP, EVENT_TYPE, CREATED_AT, SENTIMENT_SCORE, UNIQUE_ANALYST_COUNT, SENTIMENT_REASON。

analyst_count <= 1 のイベントは除外してください。
```

![プロンプト 1: AI センチメント抽出](assets/prompt-1.gif)

---

#### プロンプト 2: ML モデルの学習と登録

```
FSI_DEMO_DB.ANALYTICS.FSI_DATA テーブルを使用します。カラム: ticker, date, price, r_1, r_5_1, r_10_5, r_21_10, r_63_21, y (ターゲット)。

四半期ごとのウォークフォワード LightGBM 回帰モデルを学習してください:
- 特徴量: r_1, r_5_1, r_10_5, r_21_10, r_63_21
- ターゲット: y (5日先リターン)
- 各テスト四半期 Q について: Q-2 より前の四半期で学習、Q-2 と Q-1 で検証、Q でテスト
- L2 メトリクスとアーリーストッピング（200ラウンド忍耐）を使用
- ハイパーパラメータグリッド: learning_rate [0.03, 0.05, 0.10], num_leaves [31, 63]

各四半期のベストモデルを Snowflake Model Registry に FIS_{quarter} として登録（例: FIS_2024Q3, FIS_2025Q1）:
- version_name="v1"
- sample_input_data は学習データから（100行）
- options={"relax_version": False, "target_methods": ["predict"], "method_options": {"predict": {"case_sensitive": True}}}

メトリクスを log_model に渡さないでください。target_methods を別パラメータとして使用しないでください。
```

![プロンプト 2: ML モデルの学習と登録](assets/prompt-2.png)

---

#### プロンプト 3: Cortex Search Service の作成

```
FSI_DEMO_DB.ANALYTICS スキーマに DOW_ANALYSTS_SENTIMENT_ANALYSIS という名前の Cortex Search Service を作成してください。

ソーステーブル: AI_TRANSCRIPTS_ANALYSTS_SENTIMENTS
検索カラム: SENTIMENT_REASON
返却カラム: PRIMARY_TICKER, EVENT_TIMESTAMP, SENTIMENT_SCORE, UNIQUE_ANALYST_COUNT, SENTIMENT_REASON
ウェアハウス: FSI_DEMO_WH
ターゲットラグ: 1日
```

![プロンプト 3: Cortex Search Service の作成](assets/prompt-3.png)

---

#### プロンプト 4: Semantic View の作成

```
FSI_DEMO_DB.ANALYTICS スキーマに ANALYST_SENTIMENTS_VIEW という名前の Semantic View を作成してください。アナリストセンチメントデータに対する自然言語クエリ用です。

ソーステーブル: AI_TRANSCRIPTS_ANALYSTS_SENTIMENTS

ディメンション:
- PRIMARY_TICKER: 企業の株式ティッカーシンボル
- EVENT_TIMESTAMP: 決算説明会の日時
- EVENT_TYPE: イベントタイプ（決算説明会）

メジャー:
- SENTIMENT_SCORE: 1-10のアナリストセンチメント評価
- UNIQUE_ANALYST_COUNT: 参加したユニークアナリスト数

定性的インサイトのための記述テキストフィールドとして SENTIMENT_REASON を含めてください。
```

![プロンプト 4: Semantic View の作成](assets/prompt-4.png)

---

#### プロンプト 5: エージェントの作成

```
FSI_DEMO_DB.ANALYTICS スキーマに QUANTITATIVE_RESEARCH_AGENT という名前の Cortex Agent を作成してください。

表示名: "Quantitative Research Agent"

インストラクション/システムプロンプト:
"あなたはダウジョーンズ30銘柄の分析を専門とするクオンツリサーチアシスタントです。以下をサポートします:
1. MLベースの株価予測 - GET_TOP_BOTTOM_STOCK_PREDICTIONS を使用して予測5日リターンでランク付けされたトップ/ボトム銘柄を取得
2. アナリストセンチメントクエリ - セマンティックビューを介して構造化センチメントデータ（スコア、アナリスト数）をクエリ
3. センチメントインサイト - 決算説明会トランスクリプトで定性的なアナリストコメンタリーを検索
4. メールアラート - メールでポートフォリオ推奨やリサーチサマリーを送信

株式選択や予測について聞かれた場合は、まずML予測ツールを使用してください。アナリストの意見やセンチメントについて聞かれた場合は、セマンティックビュー（スコア用）と検索サービス（理由用）の両方を組み合わせてください。回答は簡潔でデータドリブンにしてください。"

サンプル質問:
- "ML予測に基づく今週のトップ5銘柄は？"
- "アナリストセンチメントが最もポジティブな銘柄は？"
- "Apple の直近の決算説明会でアナリストは何と言っていた？"
- "センチメントは強気だがML予測がネガティブな銘柄を見せて"
- "今週のトップ銘柄のサマリーをメールして"

含めるツール（SQL CREATE AGENT 構文で tool_resources 配列を使用）:
1. セマンティックビューツール: type='semantic_view', identifier='FSI_DEMO_DB.ANALYTICS.ANALYST_SENTIMENTS_VIEW'
2. Cortex 検索ツール: type='cortex_search', identifier='FSI_DEMO_DB.ANALYTICS.DOW_ANALYSTS_SENTIMENT_ANALYSIS'
3. プロシージャツール（ML予測）: type='procedure', identifier='FSI_DEMO_DB.ANALYTICS.GET_TOP_BOTTOM_STOCK_PREDICTIONS', execution_environment='sandbox'
   - パラメータ: MODEL_NAME (STRING, オプション - NULL の場合は最新モデルを自動検出), TOP_N (INTEGER, デフォルト 5 - トップ N とボトム N の両方を返却)
   - 予測5日先リターンでランク付けされた銘柄を返却
4. プロシージャツール（メール）: type='procedure', identifier='FSI_DEMO_DB.ANALYTICS.SEND_EMAIL', execution_environment='sandbox'
   - パラメータ: RECIPIENT_EMAIL (VARCHAR, オプション - NULL の場合は現在のユーザーのメールを使用), SUBJECT (VARCHAR), BODY (VARCHAR)

重要: プロシージャツールには tool_resources に execution_environment='sandbox' を含める必要があります。

モデル: claude-3-5-sonnet
ウェアハウス: FSI_DEMO_WH
```

![プロンプト 5: エージェントの作成](assets/prompt-5.png)

---

#### プロンプト 6: Snowflake Intelligence への登録

```
エージェント FSI_DEMO_DB.ANALYTICS.QUANTITATIVE_RESEARCH_AGENT を Snowflake Intelligence オブジェクト SNOWFLAKE_INTELLIGENCE_OBJECT_DEFAULT に登録して、ユーザーが会話形式でやり取りできるようにしてください。
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
SNOWFLAKE_PUBLIC_DATA_FREE.PUBLIC_DATA_FREE.STOCK_PRICE_TIMESERIES を使用して、ダウジョーンズ30銘柄（MMM, AXP, AMGN, AMZN, AAPL, BA, CAT, CVX, CSCO, KO, DIS, GS, HD, HON, IBM, JNJ, JPM, MCD, MRK, MSFT, NKE, PG, RTX, CRM, SHW, TRV, UNH, V, WMT, NVDA）のデータを処理してください。

対数リターンを使用してモメンタム特徴量を構築:
- r_1: 当日のリターン
- r_5_1: t-4 から t-1 までのリターン
- r_10_5: t-9 から t-5 までのリターン
- r_21_10: t-20 から t-11 までのリターン
- r_63_21: t-62 から t-21 までのリターン

ターゲット変数 y を構築: t+2 から t+6 までの将来リターン。

ティッカーをカラムとしてパネルデータとして保持してください。
```
</details>

<details>
<summary><b>オプションプロンプト B: バックテスト戦略</b></summary>

```
2021年以降でML戦略が機能するかテストしてください。

ポートフォリオ構築:
- 火曜日に予測を生成
- 水曜日のクローズ時に、予測リターンでトップ5をロング、ボトム5をショート（等ウェイト）
- 木曜日から翌水曜日まで保持（t+2..t+6 ウィンドウ）
- 取引コスト: 週次ターンオーバーで片道3.0bps

メトリクスを表示:
- インフォメーションレシオ（コスト前/後）
- 最大ドローダウン
- カルマーレシオ

コスト前後のエクイティカーブをプロットしてください。
```
</details>

<details>
<summary><b>オプションプロンプト C: センチメント-リターン回帰分析</b></summary>

```
アナリストセンチメントと株式リターンの関係を分析してください。

merge_asof（forward方向）を使用してセンチメントデータと価格データをマージ。

作成:
- 1D リターン: 決算説明会中の反応
- 3D リターン: return_lead_1 + return_lead_2 + return_lead_3（決算後ドリフト）

OLS回帰を実行: return ~ sentiment_score
リターンを1パーセンタイル/99パーセンタイルでウィンソライズ。

散布図を作成:
- センチメントスコア vs 1D リターン（OLS回帰線、β、t統計量付き）
- センチメントスコア vs 3D リターン（OLS回帰線、β、t統計量付き）

sentiment_change（前回の決算説明会との比較）を使用して分析を繰り返してください。
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
