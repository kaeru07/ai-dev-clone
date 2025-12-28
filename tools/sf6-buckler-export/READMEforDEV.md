# sf6-buckler-export 仕様書

## 目次

- [概要（何のツールで、何ができるか、想定ユーザー）](#概要何のツールで何ができるか想定ユーザー)
- [5 分で動かす（前提、インストール、起動、最短手順）](#5分で動かす前提インストール起動最短手順)
- [アーキテクチャ概要（主要コンポーネント、依存関係、データ/制御の流れ）](#アーキテクチャ概要主要コンポーネント依存関係データ制御の流れ)
- [ディレクトリ構成マップ（重要ディレクトリ・主要ファイルの役割）](#ディレクトリ構成マップ重要ディレクトリ主要ファイルの役割)
- [機能一覧（機能 → 入口 → 主処理 → 出力/副作用 → 設定）](#機能一覧機能入口主処理出力副作用設定)
- [主要処理フロー（代表ユースケース 3 つをシーケンス風に）](#主要処理フロー代表ユースケース3つをシーケンス風に)
- [設定（env/設定ファイル/引数/feature flag）](#設定env設定ファイル引数feature-flag)
- [I/O 仕様（入力形式、出力形式、外部 API、DB、ファイル）](#io仕様入力形式出力形式外部apidbファイル)
- [エラーハンドリング（例外、リトライ、ログ、終了コード）](#エラーハンドリング例外リトライログ終了コード)
- [テスト/品質（テストの場所、実行方法、注意点）](#テスト品質テストの場所実行方法注意点)
- [拡張ポイント（追加実装時に触る場所、ガイドライン）](#拡張ポイント追加実装時に触る場所ガイドライン)
- [FAQ（ハマりどころ）](#faqハマりどころ)
- [プロジェクト方針と設計判断](#プロジェクト方針と設計判断)

---

## 概要（何のツールで、何ができるか、想定ユーザー）

### ツールの目的

**sf6-buckler-export** は、ストリートファイター 6（SF6）の公式戦績サイト「Buckler's Boot Camp」から、ランクマッチのバトルログを自動でスクレイピングして CSV 形式で保存する Node.js ベースのツールです。

### 主要機能

- Buckler's Boot Camp の「battlelog/rank」ページ（最大 10 ページ）から対戦履歴を自動収集
- Playwright を使用したブラウザ自動操作によるデータ抽出
- Next.js の`__NEXT_DATA__`から JSON 形式でバトルログを取得
- CSV 形式での戦績データエクスポート
- 自動ループ実行とセッション維持機能
- 複数 CSV ファイルの統合・重複排除機能

### 想定ユーザー

- SF6 のランクマッチ戦績を継続的に記録・分析したいプレイヤー
- 自分の対戦データを外部ツール（Excel、データ分析ツール等）で活用したいユーザー
- 長期的な成長記録やキャラクター別成績を可視化したいプレイヤー

---

## 5 分で動かす（前提、インストール、起動、最短手順）

### 前提条件

- Node.js v14 以降がインストール済み
- Windows 環境（バッチファイル使用）
- SF6 の Buckler アカウントを持っていること
- 自分の SID（プレイヤー ID）を把握していること
  - 根拠: [src/export_buckler.js](tools/sf6-buckler-export/src/export_buckler.js#L14) `const SID = "1146188535";`

### インストール

```bash
cd C:\ai-script\tools\sf6-buckler-export
npm install
npx playwright install chromium
```

- 根拠: [package.json](tools/sf6-buckler-export/package.json#L11) `"playwright": "^1.57.0"` が依存関係に定義
- **重要**: `npx playwright install chromium` でブラウザバイナリをインストール（自動では入らない）

### SID の設定

ファイル [src/export_buckler_auto.js](tools/sf6-buckler-export/src/export_buckler_auto.js#L18) を編集:

```javascript
const SID = "1146188535"; // ←自分のSIDに変更
```

- バッチファイルは自動的にツールディレクトリに移動（`cd /d "%~dp0"`）
- 文字コードを UTF-8 に設定（`chcp 65001`）
- `node src\export_buckler_auto.js` を実行
- 根拠: [export.bat#L2-L12](tools/sf6-buckler-export/export.bat#L2-L12)

2. ブラウザが起動するので Buckler にログイン
3. バトルログ（ランクマ）画面が表示されたら Enter キーを押す
4. 自動でデータ取得が開始される（150 分ごとにループ）
5. 停止するには **Ctrl+C** を押す（自動的に CSV 統合が実行される）kler にログイン
6. バトルログ（ランクマ）画面が表示されたら Enter キーを押す
7. 自動でデータ取得が開始される

---

## アーキテクチャ概要（主要コンポーネント、依存関係、データ/制御の流れ）

### 主要コンポーネント

#### 1. スクレイピングエンジン

- **export_buckler.js**: 単発実行版（手動 Enter 待機 → 1 回実行 → 終了）
  - 関数: `main()`, `getNextData()`, `extractMyIdentity()`, `pickSides()`, `decideResultAndScore()`
- **export_buckler_auto.js**: 自動ループ版（定期実行 + セッション維持）
  - 関数: `main()`, `consolidateCSV()`, `startKeepAlive()`
  - 根拠: [export_buckler_auto.js](tools/sf6-buckler-export/src/export_buckler_auto.js#L19-L21)
    ```javascript
    const SCRAPE_INTERVAL = 150; // 分（スクレイピング間隔）
    const KEEP_ALIVE_INTERVAL = 60; // 分（セッション延命のページアクセス間隔）
    ```

#### 2. データ統合エンジン

- **consolidate_csv.js**: 複数 CSV の統合・重複排除・ソート処理
  - 関数: `readCSV()`, `parseCSVLine()`, `escapeCSV()`, `deleteOldFiles()`
  - 根拠: [consolidate_csv.js](tools/sf6-buckler-export/src/consolidate_csv.js#L11-L14)
    ```javascript
    const OUTPUT_FILE = path.join(CSV_DIR, "battlelog_consolidated.csv");
    const ARCHIVE_DIR = path.join(CSV_DIR, "archived");
    const ARCHIVE_DAYS = 30; // 保持日数
    ```

#### 3. セッション管理

- **buckler-session.json**: Playwright によるブラウザセッション（Cookie 等）の永続化
  - 根拠: [export_buckler_auto.js](tools/sf6-buckler-export/src/export_buckler_auto.js#L22) `const SESSION_FILE = path.join(__dirname, "buckler-session.json");`

### 依存関係

```
Playwright (^1.57.0)
  └─ Chromium (headless: false)
      └─ Buckler's Boot Camp Web Page
          └─ __NEXT_DATA__ JSON
```

- 根拠: [package.json](tools/sf6-buckler-export/package.json#L11)

### データフロー

```
1. Buckler Webページ (__NEXT_DATA__)
   ↓ (Playwright評価)
2. getNextData() → JSON抽出
   ↓
3. extractMyIdentity() → 自分のshort_id/fighter_id特定
   ↓
4. pickSides() → 自分側/相手側の判定
   ↓
5. decideResultAndScore() → 勝敗・ラウンドスコア算出
   ↓
6. CSV出力 (battlelog_YYYYMMDD_HHMM.csv)
   ↓
7. consolidate_csv.js → 統合CSV (battlelog_consolidated.csv)
   ↓
8. 元ファイル → archived/ へ移動
```

---

## ディレクトリ構成マップ（重要ディレクトリ・主要ファイルの役割）

```
sf6-buckler-export/
├─ src/                           # ソースコード
│   ├─ export_buckler.js          # 単発実行版スクレイパー
│   ├─ export_buckler_auto.js     # 自動ループ版スクレイパー（メイン）
│   ├─ consolidate_csv.js         # CSV統合スクリプト
│   ├─ update_consolidated_with_new_spec.js  # 統合CSV更新ツール（旧仕様→新仕様変換）
│   ├─ verify_csv_update.js       # CSV整合性検証ツール
│   └─ buckler-session.json       # Playwrightセッション情報（Cookie等）
├─ exported-csv/                  # 出力先ディレクトリ
│   ├─ battlelog_consolidated.csv # 統合済み最終CSV
│   ├─ archived/                  # 統合後の元ファイル保管場所（30日保持）
│   └─ _debug_nextdata/           # デバッグ用JSON（手動保存の参考資料、自動保存なし）
├─ test/                          # テスト用（現在空、実装検討中）
├─ node_modules/                  # npm依存関係
├─ package.json                   # プロジェクト定義・依存管理
├─ package-lock.json              # ロックファイル
├─ export.bat                     # Windows用起動バッチファイル
└─ CSV                            # 【削除可】旧ファイル、現在未使用
```

### 主要ファイルの役割

| ファイル                                                                                                  | 役割                              | エントリポイント |
| --------------------------------------------------------------------------------------------------------- | --------------------------------- | ---------------- |
| [export.bat](tools/sf6-buckler-export/export.bat)                                                         | Windows 用起動スクリプト          | ✓ ユーザー起動   |
| [export_buckler_auto.js](tools/sf6-buckler-export/src/export_buckler_auto.js)                             | 自動ループ実行・セッション維持    | ✓ bat 経由       |
| [export_buckler.js](tools/sf6-buckler-export/src/export_buckler.js)                                       | 単発実行版（レガシー）            | △ 直接実行可     |
| [consolidate_csv.js](tools/sf6-buckler-export/src/consolidate_csv.js)                                     | CSV 統合処理（Ctrl+C 時自動実行） | △ 自動/手動      |
| [update_consolidated_with_new_spec.js](tools/sf6-buckler-export/src/update_consolidated_with_new_spec.js) | 旧仕様 CSV→ 新仕様 CSV 変換ツール | △ 手動実行       |
| [verify_csv_update.js](tools/sf6-buckler-export/src/verify_csv_update.js)                                 | CSV 整合性検証ツール              | △ 手動実行       |
| [buckler-session.json](tools/sf6-buckler-export/src/buckler-session.json)                                 | ブラウザセッション永続化          | -                |
| [battlelog_consolidated.csv](tools/sf6-buckler-export/exported-csv/battlelog_consolidated.csv)            | 最終出力データ                    | -                |

---

## 機能一覧（機能 → 入口 → 主処理 → 出力/副作用 → 設定）

### 機能 1: バトルログスクレイピング

- **入口**: `export_buckler_auto.js` → `main()` 関数
- **主処理**:
  1. Playwright でブラウザ起動（headless: false）
  2. `BASE_URL` にアクセス（`https://www.streetfighter.com/6/buckler/ja-jp/profile/${SID}/battlelog/rank`）
  3. ページ 1〜10 を順次巡回
  4. 各ページで `getNextData()` を実行し `__NEXT_DATA__` JSON 取得
     - 根拠: [export_buckler_auto.js](tools/sf6-buckler-export/src/export_buckler_auto.js#L127-L134)
  5. `extractMyIdentity()` で自分の short_id 特定
  6. `replay_list` から各試合の `pickSides()` → `decideResultAndScore()` 実行
- **出力**: `C:\ai-script\tools\sf6-buckler-export\exported-csv\battlelog_YYYYMMDD_HHMM.csv`
  - **⚠️ パス固定の注意**: `OUTPUT_DIR` はコード内で絶対パス `"C:\\ai-script\\tools\\sf6-buckler-export\\exported-csv"` として固定されている
  - 異なる環境で使用する場合は [export_buckler_auto.js#L24](tools/sf6-buckler-export/src/export_buckler_auto.js#L24) の `OUTPUT_DIR` を変更する必要がある
  - **列名の注意**: 列名は `round_score` だが、実際には `myRoundResults`（自分の round_results 配列の JSON 文字列）が格納される
  - 根拠: [export_buckler_auto.js#L296-L305, L351-L363](tools/sf6-buckler-export/src/export_buckler_auto.js#L24-L363)
- **CSV 形式**:
  ```
  battle_time_jst,battle_type,my_character,opp_character,my_mr,opp_mr,result,round_score,replay_id,page
  ```
  - 根拠: [export_buckler_auto.js](tools/sf6-buckler-export/src/export_buckler_auto.js#L296-L305)
- **設定**:
  - `SID`: プレイヤー ID
  - `TOTAL_PAGES`: 取得ページ数（デフォルト 10）
  - `SCRAPE_INTERVAL`: スクレイピング間隔（デフォルト 150 分）

### 機能 2: 自動ループ実行

- **入口**: `export_buckler_auto.js` → `main()` の `while(true)` ループ
- **主処理**:
  1. 初回のみ手動ログイン待機（`waitForEnter()`）
  2. セッション保存（`context.storageState({ path: SESSION_FILE })`）
  3. スクレイピング実行
  4. `SCRAPE_INTERVAL` 分待機（`await sleep(SCRAPE_INTERVAL * 60 * 1000)`）
     - 根拠: [export_buckler_auto.js](tools/sf6-buckler-export/src/export_buckler_auto.js#L395)
  5. ループ継続
- **副作用**: プログラムが起動し続ける（Ctrl+C で終了）
- **設定**: `SCRAPE_INTERVAL = 150` （分）

### 機能 3: セッション延命（Keep-Alive）

- **入口**: `startKeepAlive()` 関数
- **主処理**:
  - `setInterval` で KEEP_ALIVE_INTERVAL 分ごとにページアクセス
  - `page.goto()` で再訪問してセッション維持
    - 根拠: [export_buckler_auto.js](tools/sf6-buckler-export/src/export_buckler_auto.js#L221-L228)
- **副作用**: バックグラウンドでの HTTP リクエスト定期送信
- **設定**: `KEEP_ALIVE_INTERVAL = 60` （分）

### 機能 4: CSV 統合・重複排除

- **入口**: `consolidate_csv.js` → `main()` 関数 or Ctrl+C 時の自動実行
- **主処理**:
  1. `exported-csv/` 内の全 CSV 読み込み（`consolidated` を除く）
  2. `replay_id + battle_time_jst` をキーに重複排除
     - 根拠: [consolidate_csv.js](tools/sf6-buckler-export/src/consolidate_csv.js#L119-L122)
  3. 日時降順ソート（新しい順）
     - 根拠: [consolidate_csv.js](tools/sf6-buckler-export/src/consolidate_csv.js#L159-L162)
  4. `battlelog_consolidated.csv` に出力
  5. 元ファイルを `archived/` へ移動
  6. 30 日以上前のアーカイブファイル削除
     - 根拠: [consolidate_csv.js](tools/sf6-buckler-export/src/consolidate_csv.js#L14) `const ARCHIVE_DAYS = 30;`
- **出力**: `battlelog_consolidated.csv`
- **副作用**: 元 CSV ファイルの `archived/` 移動

### 機能 5: 勝敗判定アルゴリズム

- **入口**: `decideResultAndScore(myRR, oppRR)` 関数
- **主処理**:
  - `round_results` 配列の各要素を `_classifyRoundCode()` で分類
    - **Win 系**: 1 (Victory), 2 (Chip 削り), 5 (OD), 6 (SA), 7 (CA), 8 (Perfect) - **0 以外の全て**
    - **Lose 系**: 0 (敗北)
    - 根拠: [export_buckler_auto.js](tools/sf6-buckler-export/src/export_buckler_auto.js#L52-L61)
  - 自分/相手のラウンド勝利数をカウント
  - 同数の場合は「LOSE」判定（ランクマではドローなし前提）
    - 根拠: [export_buckler_auto.js](tools/sf6-buckler-export/src/e
- **⚠️ 重要な注意**: この関数が返す `round_score` は **CSV 出力では使用されない**
  - `export_buckler_auto.js` では `const { result } = decideResultAndScore(...)` と **round_score を取得していない**
  - CSV8 列目には `myRoundResults`（round_results 配列の JSON 文字列）が出力される
  - 根拠: [export_buckler_auto.js#L350-L363](tools/sf6-buckler-export/src/export_buckler_auto.js#L350-L363)xport_buckler_auto.js#L86-L88)
- **出力**: `{ result: "WIN"|"LOSE"|"UNKNOWN", round_score: "2-1" }`

---

## 主要処理フロー（代表ユースケース 3 つをシーケンス風に）

### ユースケース 1: 初回起動からデータ取得まで

```
[ユーザー] export.bat をダブルクリック
    ↓
[export.bat] chcp 65001 で文字化け対策
    ↓ node src/export_buckler_auto.js 実行
[export_buckler_auto.js] Playwright起動（headless: false）
    ↓
[Playwright] Chromiumブラウザを起動
    ↓ BASE_URL?page=1 にアクセス
[ブラウザ] Bucklerログイン画面表示
    ↓
[ユーザー] 手動でログイン → バトルログ画面表示
    ↓
[ユーザー] Enter キー押下
    ↓
[export_buckler_auto.js] context.storageState() でセッション保存
    ↓
[export_buckler_auto.js] getNextData() で __NEXT_DATA__ 取得
    ↓
[export_buckler_auto.js] extractMyIdentity() → short_id特定
    ↓
[export_buckler_auto.js] 1〜10ページをループ
    各ページで replay_list 解析 → CSV行生成
    ↓
[export_buckler_auto.js] battlelog_YYYYMMDD_HHMM.csv に書き込み
    ↓
[export_buckler_auto.js] startKeepAlive() 開始
    ↓
[export_buckler_auto.js] sleep(150分)
    ↓ (150分後)
[export_buckler_auto.js] 再度スクレイピング実行（ループ継続）
```

### ユースケース 2: セッション維持と自動再ログイン

```
[export_buckler_auto.js] 2回目以降のループ開始
    ↓
[export_buckler_auto.js] SESSION_FILE から storageState 復元
    ↓ fs.existsSync(SESSION_FILE) → true
[Playwright] セッション復元成功
    ↓
[export_buckler_auto.js] page.goto(BASE_URL?page=1)
    ↓
[export_buckler_auto.js] getNextData() 実行
    ↓
[Playwright] __NEXT_DATA__ が null （ログイン切れ検出）
    ↓
[export_buckler_auto.js] console.error("⚠️ __NEXT_DATA__ が取れません")
    ↓ process.stdout.write("\x07") でビープ音
[ユーザー] ブラウザで再ログイン
    ↓
[ユーザー] Enter キー押下
    ↓
[export_buckler_auto.js] セッション再保存
    ↓
[export_buckler_auto.js] スクレイピング続行
```

- 根拠: [export_buckler_auto.js](tools/sf6-buckler-export/src/export_buckler_auto.js#L268-L285)

### ユースケース 3: Ctrl+C 終了時の CSV 統合

```
[ユーザー] Ctrl+C 押下
    ↓
[Node.js] SIGINT シグナル発火
    ↓
[export_buckler_auto.js] process.on("SIGINT", ...) ハンドラ実行
    ↓
[export_buckler_auto.js] consolidateCSV() 呼び出し
    ↓ execSync(`node consolidate_csv.js`)
[consolidate_csv.js] main() 実行
    ↓
[consolidate_csv.js] exported-csv/*.csv を全読み込み
    ↓
[consolidate_csv.js] 重複排除（replay_id + battle_time_jst）
    ↓
[consolidate_csv.js] 日時降順ソート
    ↓
[consolidate_csv.js] battlelog_consolidated.csv 書き込み
    ↓
[consolidate_csv.js] 元ファイル → archived/ 移動
    ↓
[consolidate_csv.js] 30日以前のアーカイブ削除
    ↓
[export_buckler_auto.js] browser.close()
    ↓
[export_buckler_auto.js] process.exit(0)
```

- 根拠: [export_buckler_auto.js](tools/sf6-buckler-export/src/export_buckler_auto.js#L206-L215)

---

## 設定（env/設定ファイル/引数/feature flag）

### 環境変数

なし（すべてコード内定数）

### 設定ファイル

**buckler-session.json**（自動生成・更新）

- 役割: Playwright のセッション情報（Cookie、LocalStorage 等）
- 形式: JSON
- 自動管理: `context.storageState({ path: SESSION_FILE })` で保存
- 根拠: [export_buckler_auto.js](tools/sf6-buckler-export/src/export_buckler_auto.js#L22)

### ソースコード内定数（要手動編集）

#### export_buckler_auto.js / export_buckler.js

| 定数名                | デフォルト値                                               | 説明                                | 行番号                                                         |
| --------------------- | ---------------------------------------------------------- | ----------------------------------- | -------------------------------------------------------------- |
| `SID`                 | `"1146188535"`                                             | 自分のプレイヤー ID（**必須変更**） | [L18](tools/sf6-buckler-export/src/export_buckler_auto.js#L18) |
| `TOTAL_PAGES`         | `10`                                                       | 取得するページ数                    | [L19](tools/sf6-buckler-export/src/export_buckler_auto.js#L19) |
| `SCRAPE_INTERVAL`     | `150`                                                      | スクレイピング間隔（分）            | [L20](tools/sf6-buckler-export/src/export_buckler_auto.js#L20) |
| `KEEP_ALIVE_INTERVAL` | `60`                                                       | セッション延命アクセス間隔（分）    | [L21](tools/sf6-buckler-export/src/export_buckler_auto.js#L21) |
| `OUTPUT_DIR`          | `"C:\\ai-script\\tools\\sf6-buckler-export\\exported-csv"` | CSV 出力先（絶対パス）              | [L24](tools/sf6-buckler-export/src/export_buckler_auto.js#L24) |

#### consolidate_csv.js

| 定数名         | デフォルト値 | 説明                       | 行番号                                                     |
| -------------- | ------------ | -------------------------- | ---------------------------------------------------------- |
| `ARCHIVE_DAYS` | `30`         | アーカイブファイル保持日数 | [L14](tools/sf6-buckler-export/src/consolidate_csv.js#L14) |

### コマンドライン引数

なし（現時点では未実装）

---

## I/O 仕様（入力形式、出力形式、外部 API、DB、ファイル）

### 入力

#### 1. Web ページ（スクレイピング対象）

- **URL**: `https://www.streetfighter.com/6/buckler/ja-jp/profile/${SID}/battlelog/rank?page={1..10}`
- **形式**: Next.js SSR ページ
- **データソース**: `<script id="__NEXT_DATA__" type="application/json">...</script>`
  - 根拠: [export_buckler_auto.js](tools/sf6-buckler-export/src/export_buckler_auto.js#L129-L136)
- **主要フィールド**:
  ```javascript
  {
    props: {
      pageProps: {
        fighter_banner_info: { personal_info: { short_id, fighter_id } },
        replay_list: [
          {
            replay_id, uploaded_at, replay_battle_type_name,
            player1_info: { player: {short_id, fighter_id}, master_rating, round_results, ... },
            player2_info: { ... }
          }
        ]
      }
    }
  }
  ```
  - 実例: [nextdata_page1.json](tools/sf6-buckler-export/exported-csv/_debug_nextdata/nextdata_page1.json)

#### 2. セッションファイル

- **パス**: `src/buckler-session.json`
- **形式**: Playwright StorageState JSON
- **主要構造**:
  ```json
  {
    "cookies": [ { "name": "_csrf", "value": "...", "domain": "...", ... } ],
    "origins": [ ... ]
  }
  ```

#### 3. 既存 CSV（統合処理時）

- **パス**: `exported-csv/battlelog_*.csv`
- **形式**: CSV（ヘッダー付き）

### 出力

#### 1. バトルログ CSV

- **パス**: `{OUTPUT_DIR}/battlelog_{YYYYMMDD}_{HHMM}.csv`
- **命名規則**: `nowStamp()` 関数により生成（例: `battlelog_20251229_1234.csv`）
  - フォーマット: 年月日（8 桁）\_時分（4 桁）、秒は含まない
  - 生成タイミング: スクレイピング開始時（各ループの最初）
- 根拠: [export_buckler_auto.js#L28-L36](tools/sf6-buckler-export/src/export_buckler_auto.js#L28-L36) の `nowStamp()` 関数、[L293](tools/sf6-buckler-export/src/export_buckler_auto.js#L293) での呼び出し
- **形式**: CSV（UTF-8、カンマ区切り、ダブルクォートエスケープ）
- **ヘッダー**:
  ```
  battle_time_jst,battle_type,my_character,opp_character,my_mr,opp_mr,result,round_score,replay_id,page
  ```
- **サンプル行**:
  ```
  2025-12-28-1056,RANKED MATCH,sagat,juri,1450,1418,WIN,"[8,1]",SJ6UX6XRJ,1
  ```
- **データ型**:
  - `battle_time_jst`: YYYY-MM-DD-HHMM 形式（例: `2025-12-28-1056`）
    - **変換処理**: `uploaded_at`（Unix epoch 秒）→ UTC 日時 → +9 時間で JST 変換 → フォーマット化
    - **⚠️ 重要な注意**: `uploaded_at` はリプレイのアップロード時刻であり、実際の対戦時刻（`played_at` / `battle_at`）ではない
    - **処理の根拠**: [export_buckler_auto.js#L333-L345](tools/sf6-buckler-export/src/export_buckler_auto.js#L333-L345)
    - **フォーマット処理**: [export_buckler_auto.js#L46-L50](tools/sf6-buckler-export/src/export_buckler_auto.js#L46-L50) の `formatBattleTime()` 関数
  - `my_mr`, `opp_mr`: 整数またはマスターレート（空文字の場合あり）
  - `result`: WIN / LOSE / UNKNOWN
  - **`round_score`**: **重要** - 列名は `round_score` だが、実際には **拡張された `round_results` 配列の JSON 文字列**が格納される
    - **正の値**: 自分が勝ったラウンド（1=Victory, 2=Chip, 5=OD, 6=SA, 7=CA, 8=Perfect）
    - **負の値**: 自分が負けたラウンド（相手の勝ち方をマイナスで記録）
      - 例: -8 = Perfect 負け, -7 = CA 負け, -2 = 削り負け
    - **データ例**:
      - `"[8,1]"` = 1R 目に Perfect 勝ち、2R 目に通常勝ち（2-0 勝利）
      - `"[-2,-8]"` = 1R 目に削り負け、2R 目に Perfect 負け（0-2 敗北）
      - `"[1,-2,-7]"` = 1R 目に通常勝ち、2R 目に削り負け、3R 目に CA 負け（1-2 敗北）
    - **仕様変更**: 2025 年 12 月 29 日より、負けたラウンドに相手の勝ち方を記録するように改良
    - **注意**: `decideResultAndScore()` が計算する `round_score`（例: "2-1"）は **CSV 出力されない**
    - 根拠: [export_buckler_auto.js#L350-L363](tools/sf6-buckler-export/src/export_buckler_auto.js#L350-L363)
  - `replay_id`: リプレイ ID（9 文字の英数字
  - `round_score`: JSON 文字列（例: `"[8,1]"` = ラウンド結果コード配列）
  - `page`: 1-10（取得元ページ番号）

#### 2. 統合 CSV

- **パス**: `exported-csv/battlelog_consolidated.csv`
- **形式**: 上記と同一、重複排除済み・日時降順ソート済み
- **更新タイミング**: Ctrl+C 終了時 or 手動で `node src/consolidate_csv.js` 実行時

#### 3. アーカイブ CSV

- **パス**: `exported-csv/archived/battlelog_*.csv`
- **形式**: 統合前の元ファイル
- **削除ルール**: 30 日経過後自動削除

### 外部 API

なし（スクレイピングのみ、公式 API は未使用）

### データベース

なし（ファイルベース）

---

## エラーハンドリング（例外、リトライ、ログ、終了コード）

### エラー検出と対応

#### 1. ログイン切れ検出と再認証

- **検出条件**: page 1 取得後に `getNextData()` が `null` を返す ([L267](tools/sf6-buckler-export/src/export_buckler_auto.js#L267))
- **対応フロー**:
  1. エラーメッセージ表示: `"⚠️ __NEXT_DATA__ が取れません。ログイン切れの可能性があります。"` ([L268](tools/sf6-buckler-export/src/export_buckler_auto.js#L268))
  2. ビープ音出力: `process.stdout.write("\x07")` ([L270](tools/sf6-buckler-export/src/export_buckler_auto.js#L270))
  3. ユーザー操作待機: `"ブラウザで再ログインして Enter を押してください..."` メッセージ表示後 `waitForEnter()` 実行 ([L271-L272](tools/sf6-buckler-export/src/export_buckler_auto.js#L271-L272))
  4. セッション再保存: `context.storageState({ path: SESSION_FILE })` ([L274-L275](tools/sf6-buckler-export/src/export_buckler_auto.js#L274-L275))
  5. 再度 page 1 取得してリトライ ([L277-L279](tools/sf6-buckler-export/src/export_buckler_auto.js#L277-L279))
  6. それでも失敗した場合: `SCRAPE_INTERVAL` 分待機して次ループへスキップ ([L280-L285](tools/sf6-buckler-export/src/export_buckler_auto.js#L280-L285))
- **リトライ回数**: 1 回のみ（再試行後も失敗なら次ループまで待機）

#### 2. ページ単位のエラー（replay_list 空またはページ取得失敗）

- **検出条件**: 各ページの `replay_list` が空配列または null ([L318-L319](tools/sf6-buckler-export/src/export_buckler_auto.js#L318-L319))
- **対応**: `"  replay_list が空。スキップします。"` を表示して次ページへ continue ([L320-L321](tools/sf6-buckler-export/src/export_buckler_auto.js#L320-L321))
- **影響範囲**: 該当ページのみスキップ、他ページの処理は継続

#### 3. ループ全体のエラー（予期しない例外）

- **検出条件**: `while(true)` ループ内の `try-catch` で補足される全例外 ([L397-L407](tools/sf6-buckler-export/src/export_buckler_auto.js#L397-L407))
- **対応フロー**:
  1. エラーログ出力: `"❌ Loop {N} でエラー発生: {message}"` ([L398](tools/sf6-buckler-export/src/export_buckler_auto.js#L398))
  2. スタックトレース出力: `console.error("スタックトレース:", e.stack)` ([L399](tools/sf6-buckler-export/src/export_buckler_auto.js#L399))
  3. 待機メッセージ: `"{SCRAPE_INTERVAL}分後に再試行します..."` ([L400](tools/sf6-buckler-export/src/export_buckler_auto.js#L400))
  4. Keep-Alive 開始 ([L402](tools/sf6-buckler-export/src/export_buckler_auto.js#L402))
  5. `SCRAPE_INTERVAL` 分待機後に次ループで自動再試行 ([L403](tools/sf6-buckler-export/src/export_buckler_auto.js#L403))
- **リトライ**: 無限ループのため、Ctrl+C で明示的に停止するまで永続的に再試行

### リトライポリシー

- **全体ループ**: 無限ループ（Ctrl+C で明示的に停止するまで継続）
- **ログイン切れ**: 手動再ログイン待機 → 1 回自動リトライ → 失敗なら次ループまでスキップ
- **ページ単位失敗**: 該当ページスキップ、次ページへ即座に継続
- **Keep-Alive エラー**: エラーログ出力のみ、次回の定期実行で自動リトライ ([L226-L228](tools/sf6-buckler-export/src/export_buckler_auto.js#L226-L228))

### ログ出力

- **形式**: Console.log（標準出力）
- **レベル**:
  - 情報: `console.log()`
  - 警告: `console.error("⚠ ...")`
  - エラー: `console.error("❌ ...")`

### ログ出力

- **形式**: Console.log（標準出力）、Console.error（標準エラー出力）
- **レベル分類**:

  - 情報: `console.log()` - 正常な進行状況
  - 警告: `console.log("⚠ ...")`または`console.error("⚠️ ...")` - 注意が必要な状況
  - エラー: `console.error("❌ ...")` または `console.error("ERROR: ...")` - 処理失敗

- **主要ログメッセージ一覧**:
  - `"✓ セッション保存: {path}"` - 初回ログイン後のセッション保存成功 ([L261](tools/sf6-buckler-export/src/export_buckler_auto.js#L261))
  - `"✓ セッション復元成功"` - 既存セッションからのコンテキスト復元成功 ([L199](tools/sf6-buckler-export/src/export_buckler_auto.js#L199))
  - `"My identity: { myShortId: ..., myFighterId: ... }"` - 自プレイヤーの識別情報特定 ([L289](tools/sf6-buckler-export/src/export_buckler_auto.js#L289))
  - `"Fetching page {N}/{TOTAL}: {url}"` - 各ページのスクレイピング開始 ([L313](tools/sf6-buckler-export/src/export_buckler_auto.js#L313))
  - `"  replay_list が空。スキップします。"` - リプレイデータなしでページスキップ ([L320](tools/sf6-buckler-export/src/export_buckler_auto.js#L320))
  - `"✓ Done: {csvPath}"` - CSV ファイル出力完了 ([L378](tools/sf6-buckler-export/src/export_buckler_auto.js#L378))
  - `"✓ セッション更新: {path}"` - ループ完了後のセッション更新 ([L381](tools/sf6-buckler-export/src/export_buckler_auto.js#L381))
  - `"[KeepAlive] ページアクセスしてセッション延命中..."` - セッション延命のページアクセス ([L223](tools/sf6-buckler-export/src/export_buckler_auto.js#L223))
  - `"⚠️ __NEXT_DATA__ が取れません。ログイン切れの可能性があります。"` - ログイン切れ検出 ([L268](tools/sf6-buckler-export/src/export_buckler_auto.js#L268))
  - `"ERROR: 再試行しても __NEXT_DATA__ が取れません。次のループへスキップします。"` - 再ログイン失敗時 ([L282](tools/sf6-buckler-export/src/export_buckler_auto.js#L282))
  - `"❌ Loop {N} でエラー発生: {message}"` - ループ内での例外発生 ([L398](tools/sf6-buckler-export/src/export_buckler_auto.js#L398))
  - `"⚠ プログラムを停止します..."` - Ctrl+C による終了開始 ([L209](tools/sf6-buckler-export/src/export_buckler_auto.js#L209))
  - `"✓ CSV統合完了"` - consolidate_csv.js 実行成功 ([L176](tools/sf6-buckler-export/src/export_buckler_auto.js#L176))

### 終了コード

| コード | 意味     | トリガー            |
| ------ | -------- | ------------------- |
| `0`    | 正常終了 | Ctrl+C → 統合完了後 |
| `1`    | 異常終了 | 未補足例外発生時    |

- 根拠: [export_buckler_auto.js](tools/sf6-buckler-export/src/export_buckler_auto.js#L214) `process.exit(0);`

---

## テスト/品質（テストの場所、実行方法、注意点）

### テストコード

- **場所**: [test/](tools/sf6-buckler-export/test) フォルダ
- **状態**: **空（未実装）**
- **根拠**: ディレクトリリスト確認結果
- **今後の予定**: ユニットテスト（Jest 等）・E2E テスト（Playwright Test）の実装を検討中

### package.json のテストスクリプト

```json
"scripts": {
  "test": "echo \"Error: no test specified\" && exit 1"
}
```

- **実行方法**: `npm test`
- **結果**: エラーメッセージ表示（テスト未実装を明示）
- **根拠**: [package.json](tools/sf6-buckler-export/package.json#L5)

### 品質保証手段（現状）

1. **手動テスト**: export.bat 実行による動作確認
2. **デバッグ出力**: `_debug_nextdata/` に取得 JSON 保存（開発時利用想定）
3. **データ検証**: CSV の目視確認

### 注意点

- **Playwright のインストール**: 初回実行前に `npx playwright install chromium` が必須（自動では実行されない）
  - インストール確認: `node_modules\.bin\playwright --version` でバージョン表示
- **ヘッドレスモード**: `headless: false` 固定（バックグラウンド実行不可）
  - 根拠: [export_buckler_auto.js#L193-L195](tools/sf6-buckler-export/src/export_buckler_auto.js#L193-L195)
- **SID 変更忘れ**: デフォルトの SID のままだと他人のデータ取得になる（必ず自分の SID に変更）
- **セッションファイル管理**: `buckler-session.json` は各ループで自動更新されるため、手動編集不要
  - 更新タイミング: 初回ログイン後、ログイン切れ再認証後、各ループ完了後
  - 根拠: [export_buckler_auto.js#L261, L278, L385](tools/sf6-buckler-export/src/export_buckler_auto.js)

---

## 拡張ポイント（追加実装時に触る場所、ガイドライン）

### 1. 取得データ項目の追加

**変更箇所**: [export_buckler_auto.js](tools/sf6-buckler-export/src/export_buckler_auto.js#L296-L305)

```javascript
const header = [
  "battle_time_jst",
  "battle_type",
  "my_character",
  "opp_character",
  "my_mr",
  "opp_mr",
  "result",
  "round_score",
  "replay_id",
  "page",
  // ← ここに項目追加
].join(",");
```

- 対応データの抽出: `replay` オブジェクトや `player*_info` から追加フィールドを取得
- CSV 行生成部分も同期修正（[L363-L374](tools/sf6-buckler-export/src/export_buckler_auto.js#L363-L374)）

### 2. カジュアル/ルームマッチ対応

**変更箇所**: `BASE_URL` の変更

```javascript
// 現在: /battlelog/rank
// カジュアル: /battlelog/casual
// ルーム: /battlelog/custom
```

- 複数バトルタイプ対応: ループで各 URL を処理するロジック追加

### 3. 自動ログイン機能（Puppeteer Cookie 注入等）

**変更箇所**: `main()` 関数の初回処理部分

- `page.goto()` 前に Cookie/LocalStorage を設定
- Buckler の認証フロー解析が必要（CAPCOM ID 連携）

### 4. 通知機能（Discord Webhook 等）

**追加箇所**:

- スクレイピング完了後に通知送信
- エラー発生時のアラート送信
- 推奨: 新規モジュール `src/notification.js` を作成

### 5. データ分析機能

**追加箇所**: 新規スクリプト `src/analyze.js`

- `battlelog_consolidated.csv` を読み込み
- 勝率・キャラ別成績・時間帯別分析等
- グラフ生成（Chart.js 等との連携）

### 6. メンテナンスツール（既存）

**update_consolidated_with_new_spec.js**（2025 年 12 月 29 日追加）

- **用途**: 旧仕様の統合 CSV を新仕様（round_score 拡張版）に更新
- **実行**: `node src/update_consolidated_with_new_spec.js`
- **機能**:
  - 新仕様 CSV から `result` と `round_score` を読み込み
  - 統合 CSV 内の同じ `replay_id` のデータを更新
  - バックアップ自動作成（`.backup`ファイル）
- **根拠**: round_score 仕様変更（負けラウンドに相手の勝ち方を記録）に対応

**verify_csv_update.js**（2025 年 12 月 29 日追加）

- **用途**: 統合 CSV と新仕様 CSV の整合性検証
- **実行**: `node src/verify_csv_update.js`
- **検証項目**:
  - result（WIN/LOSE）の一致
  - round_score（ラウンド結果配列）の一致
  - result と round_score の論理整合性（勝敗数の矛盾チェック）

### ガイドライン

- **関数分割**: 各関数は単一責任を維持（`decideResultAndScore` 等を参考）
- **エラーハンドリング**: try-catch で包み、ログ出力 + ユーザーアクション促進
- **設定外部化**: 将来的に `config.json` への移行を推奨
- **TypeScript 化**: 型安全性向上のため検討余地あり

---

## FAQ（ハマりどころ）

### Q1: ブラウザが自動で動くが、データが取得できない

**A**: ログインセッションが切れている可能性があります。

- **対処**: ブラウザ上で手動ログインし直し、Enter キーを押してください
- **根本対策**: `KEEP_ALIVE_INTERVAL` を短く設定（30 分等）

### Q2: SID の見つけ方がわからない

**A**: Buckler の自分のプロフィールページの URL を確認してください。

```
https://www.streetfighter.com/6/buckler/ja-jp/profile/1146188535/...
                                                        ^^^^^^^^^^
                                                        ここがSID
```

### Q3: CSV の `round_score` 列に配列が入っている

**A**: これは仕様です。列名は `round_score` ですが、実際には自分の `round_results` 配列の JSON 文字列が格納されます。

- **例**: `"[8,1]"` = 自分が 1R 目にコード 8 で勝ち、2R 目にコード 1 で勝利
- **注意**: `decideResultAndScore()` が計算するスコア（例: "2-1"）は CSV に出力されません
- **対処**: もし "2-1" 形式のスコアが必要な場合は、コードを修正して `round_score` 変数も出力するように変更する必要があります
- **根拠**: [export_buckler_auto.js#L350-L363](tools/sf6-buckler-export/src/export_buckler_auto.js#L350-L363)

### Q4: `npm install` でエラーが出る

**A**: Node.js のバージョンまたはネットワークの問題が考えられます。

- **対処法**:
  1. Node.js v14 以降がインストールされているか確認: `node --version`
  2. npm キャッシュをクリア: `npm cache clean --force`
  3. `node_modules` と `package-lock.json` を削除して再インストール
  4. Playwright のブラウザバイナリを手動インストール: `npx playwright install chromium`

### Q5: Ctrl+C で止めたのに CSV 統合されない

**A**: SIGINT ハンドラが正しく動作していない可能性があります。

- **確認**: ターミナルに `"⚠ プログラムを停止します..."` と `"✓ CSV統合完了"` のログが表示されたか確認
- **対処**: 手動で統合スクリプトを実行
  ```bash
  cd C:\ai-script\tools\sf6-buckler-export
  node src\consolidate_csv.js
  ```
- **原因**: 一部のターミナル環境（Git Bash 等）では SIGINT が正しく伝播しない場合がある
- **推奨**: PowerShell または cmd.exe での実行

### Q6: アーカイブが溜まりすぎて容量を圧迫

- **推奨**: PowerShell または cmd.exe での実行

### Q6: アーカイブが溜まりすぎて容量を圧迫

**A**: `ARCHIVE_DAYS` を短く設定してください。

- **変更**: [consolidate_csv.js#L14](tools/sf6-buckler-export/src/consolidate_csv.js#L14) `const ARCHIVE_DAYS = 7;` 等に変更
- **効果**: 設定日数を過ぎたアーカイブファイルが自動削除されます

---

## プロジェクト方針と設計判断

### スコープと位置づけ

- **プロジェクトの性質**: 独立したプロジェクトとして管理
  - メインプロジェクト（YouTube Live Bot）とは別の独立ツール
  - `c:\ai-script\tools\` 配下に配置されているが、論理的には独立
- **アカウント対応**: 単一アカウント専用
  - マルチアカウント対応は想定しない
  - SID をハードコーディングで問題なし
- **データ連携**: 他ツールとの連携を検討中
  - 現時点では独立動作のみ
  - 将来的に他の分析ツール等と連携する可能性あり

### 設定・パラメータ方針

- **ページ数**: `TOTAL_PAGES = 10` 固定
  - 動的取得は不要（`total_page` フィールドは利用しない）
- **ブラウザ**: Chromium 固定
  - Edge 等の他ブラウザ対応は不要
  - `channel: "msedge"` のコメントアウトコードは無視して OK

### データ品質に関する既知の課題

#### battle_time_jst の時刻ソース

- **現在の実装**: `uploaded_at`（アップロード時刻）を使用
- **望ましい仕様**: 実際の対戦時刻（`played_at` や `battle_at`）を使用
- **現状認識**: 現在も対戦時刻が取得できている想定だが、要確認
- **改善タスク**: `__NEXT_DATA__` に `played_at` / `battle_at` フィールドがあれば優先利用に変更

### メンテナンス・クリーンアップ

- **削除可能なファイル**: `CSV`（ルート直下）
  - ツール作成当初に AI が生成したが未使用
  - 削除しても動作に影響なし
- **デバッグ用データ**: `exported-csv/_debug_nextdata/`
  - 開発当初に取得データを確認するために手動保存した参考資料
  - 自動保存されない（コード内に処理なし）
  - 保持しても OK、削除しても OK

### テスト戦略（検討中）

- **ユニットテスト**: Jest 等の導入を検討中
- **E2E テスト**: Playwright Test の実装を検討中
- **現状**: [test/](tools/sf6-buckler-export/test) フォルダは空

- **パス**: `c:\ai-script\tools\sf6-buckler-export\`
- **質問**:
  - これはメインプロジェクト（YouTube Live Bot）のサブツールですか？
  - 独立したプロジェクトとして管理すべきですか？
  - 他のツールとのデータ連携は想定していますか？
