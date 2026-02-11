# 全体概要仕様書 (System Architecture Document)

- **Project:** Japan LMS MVP
- **Version:** 1.2.0
- **Status:** Draft
- **Last Updated:** 2026-02-11
- **Client:** 日本イングレサ株式会社（代表取締役: 劉 志友）

## 1. プロジェクト概要

### 1.1 背景・目的

外国人労働者の増加に伴う日本語教師不足を解消するため、日本語教師育成プラットフォームを構築する。

中国での成功モデル（TESOL: tesolchina.cn）をベースに、日本独自の資格要件（420時間学習）に対応したLMSを、Moodleを活用して短期間・低コスト（MVP）で立ち上げる。

クライアントは中国でLMS運営ノウハウを持ち、日本市場向けに「日本語教師育成向けLMS」を段階開発する意向。

### 1.2 参考モデル (TESOL China: tesolchina.cn)

中国版TESOLプラットフォームの学習フローを日本版の設計基盤とする。

**中国版TESOLの6ステップフロー:**

```
1. 缴费购买账号    →  2. 学习           →  3. 提交作业
   (決済・アカウント     (動画・教材学習       (教案・試講動画
    購入)                 + 単元テスト)          アップロード)
        ↓                      ↓                      ↓
4. 考试              →  5. 成绩查询       →  6. 证书获取
   (試験申込・受験)       (成績照会)            (証書取得)
```

**中国版の主要仕様（日本版設計の参考値）:**

| 項目 | 中国版TESOL仕様 | 日本版への適用方針 |
|------|---------------|----------------|
| コース構造 | 全20単元、順次アンロック | 同様（単元数は日本語教師カリキュラムに準拠） |
| 単元テスト合格基準 | 正答率70%以上で次単元アンロック | 同様（Moodle Quiz + 活動完了条件で実現） |
| 単元内コンテンツ | 教材（スライド/テキスト）+ 動画（複数本/単元） | 同様（Vimeo埋め込み + Moodle Page/Book） |
| 課題提出物 | 教案（doc）+ 試講動画（mp4） | 同様（Moodle Assignment で実現） |
| 成績計算 | 課題60点 + 試験40点 = 合計100点、60点以上で合格 | 同様の配点体系を採用 |
| 合格条件 | 各項目が満点の60%以上かつ合計60点以上 | 同様 |
| 学習時間表示 | ヘッダーに累計学習時間を常時表示 | 同様（420時間の進捗バーとして強化） |
| 個人情報 | 氏名、年齢、性別、証件番号、写真、メール、電話 | Moodle標準プロフィール + カスタムフィールド |
| 証書 | 物理証書 + オンライン検証（検証番号付き） | MVP: PDF自動発行、Phase 2: オンライン検証 |
| 試験 | オフライン統一試験（試験センター手配） | MVP: オンライン試験（Moodle Quiz）、Phase 2: オフライン対応検討 |

### 1.3 スコープ (MVP)

- **対象ユーザー:** 日本語教師を目指す学習者（主に在日中国人）、講師、管理者。
- **予算:** 120〜150万円（サーバー・テーマ費含む）
- **方針:** 最小構成で立ち上げ → 運用状況と事業進捗を見ながら段階投資・拡張

**主要機能:**

1. 会員登録・コース購入（MVP: paygw_stripe + enrol_fee による即時受講開始）
2. 動画学習・資料閲覧（単元別ロック機能・順次学習、70%合格基準）
3. 小テスト・課題提出（教案アップロード + 試講動画アップロード + 講師添削・採点）
4. 学習進捗管理（420時間要件の厳密な計測・13層不正防止・累計時間表示）
5. 成績管理（課題60点 + 試験40点 = 合計100点、合格基準60点）
6. 修了証発行（条件達成時のPDF自動発行）
7. 法的準拠（特定商取引法表記ページ）

## 2. 学習フロー詳細 (User Journey)

### 2.1 受講者の学習フロー（中国版TESOLモデル準拠）

```
[決済・登録]
  │  Stripe決済完了 → Moodleコース自動登録
  ▼
[個人情報登録]
  │  初回ログイン時にプロフィール補完（氏名、写真等）
  ▼
[順次学習: Unit 1 → Unit N]
  │  各Unitの構成:
  │    ├── 教材閲覧（テキスト/スライド）
  │    ├── 動画視聴（Vimeo埋め込み、複数本）
  │    └── 単元テスト（正答率70%以上で次Unitアンロック）
  │
  │  ※ 学習中は常時Heartbeat送信（30秒間隔） → 420時間累計
  │  ※ ヘッダーに累計学習時間を表示
  │  ※ 不正防止: タブ可視検知、アイドル検知、複数タブ排除、早送り防止
  ▼
[課題提出]（全Unit完了後）
  │  ├── 教案ドキュメント（doc/docx）アップロード
  │  └── 試講動画（mp4）アップロード
  ▼
[講師添削・採点]
  │  講師が教案と動画を評価（配点: 60点満点）
  │  ※ 採点基準は10項目のルーブリック
  ▼
[最終試験]
  │  オンライン試験（配点: 40点満点）
  │  ※ MVP: Moodle Quizで実施
  ▼
[成績判定]
  │  合計 = 課題成績(60) + 試験成績(40) = 100点満点
  │  合格条件: 合計60点以上、かつ各項目が満点の60%以上
  ▼
[修了証発行]
     条件達成 → PDF修了証の自動生成・ダウンロード
```

### 2.2 講師のワークフロー

1. 管理画面で担当受講者の提出課題一覧を確認
2. 教案ドキュメントをレビュー・採点（ルーブリック10項目）
3. 試講動画を視聴・評価
4. コメント・フィードバックを記入
5. 点数を確定（60点満点）

### 2.3 管理者のワークフロー

1. 受講者の学習進捗・420時間達成状況のモニタリング
2. コース・受講者・講師の管理
3. 売上・決済状況の確認
4. 不正検知ログの監査

## 3. システムアーキテクチャ

### 3.1 技術スタック

- **LMS Engine:** Moodle 4.x (Latest Stable)
- **Language:** PHP 8.2 推奨（8.1〜8.3対応）
- **OS/Server:** Linux (Ubuntu 22.04 LTS), Nginx + PHP-FPM, MySQL 8.0
- **Cache:** Redis 7.x（セッション用 + MUCキャッシュ用、インスタンス分離）
- **Theme:** Lambda (Premium Theme) + Child Theme (`theme_lambda_child`)
- **External Services:**
    - **Video:** Vimeo (Privacy domain restriction enabled)
    - **Payment:** MVP: paygw_stripe + enrol_fee / Phase 2: Stripe Checkout + Custom Webhook
    - **Live:** Zoom / Google Meet (via LTI or URL embedding)

### 3.2 システム構成図 (Conceptual)

```
graph TD
    User[受講者] -->|HTTPS| Web[Web Server (Nginx)]
    Web -->|PHP-FPM| App[Moodle LMS Core]

    subgraph "Moodle Application"
        App --> Theme[Theme: Lambda Child]
        App --> Plugin1[Local Plugin: Timetrack]
        App --> StdMod[Standard Mods: Quiz/Assign]
        App --> StdPay[Standard: paygw_stripe + enrol_fee]
    end

    subgraph "Data Store"
        App --> DB[(MySQL Database)]
        App --> Redis[(Redis Cache)]
        App --> MData[MoodleData (Files)]
    end

    subgraph "External Services"
        Plugin1 -.-> Vimeo[Vimeo API (Video)]
        StdPay -.-> Stripe[Stripe API (Payment)]
    end
```

## 4. データモデル概要 (Key Data Structures)

Moodle標準テーブルに加え、`local_timetrack` プラグインで以下のデータを管理する。

### 4.1 3段階データパイプライン

```
[Browser Heartbeat 30秒間隔]
    ↓ INSERT only（UPDATEなし、ロック競合回避）
[mdl_local_timetrack_heartbeat]（rawテーブル、高速INSERT専用）
    ↓ Cron: 5分間隔で aggregate_time タスク
[mdl_local_timetrack_daily]（日次サマリー、UPSERT）
[mdl_local_timetrack_total]（累積合計、ダッシュボード用）
    ↓ Cron: 毎日3:30 AM で cleanup_heartbeats タスク
[30日経過した処理済みHeartbeatを削除]
```

### 4.2 Heartbeat テーブル (`mdl_local_timetrack_heartbeat`)

生のHeartbeatデータを一時保管する高速INSERTテーブル。

| **Field** | **Type** | **Description** |
|---|---|---|
| `id` | BIGINT | PK, AUTO_INCREMENT |
| `userid` | BIGINT | Moodle User ID (FK to mdl_user) |
| `courseid` | BIGINT | Course ID (FK to mdl_course) |
| `cmid` | BIGINT | Course Module ID (Video/Page) |
| `activity_type` | VARCHAR(20) | 'video', 'page', 'quiz' 等 |
| `page_visible` | TINYINT(1) | タブ可視状態 (1=visible, 0=hidden) |
| `is_active` | TINYINT(1) | ユーザーアクティブ状態 |
| `token` | VARCHAR(64) | HMAC署名トークン（改ざん防止） |
| `ipaddress` | VARCHAR(45) | 不正検知用IPアドレス |
| `useragent` | VARCHAR(255) | User Agent |
| `processed` | TINYINT(1) | 集計処理済みフラグ (0/1) |
| `timecreated` | BIGINT | 記録日時 (Unix Timestamp) |

### 4.3 Daily テーブル (`mdl_local_timetrack_daily`)

日次サマリー。Cronで5分間隔のUPSERT。

| **Field** | **Type** | **Description** |
|---|---|---|
| `id` | BIGINT | PK |
| `userid` | BIGINT | User ID |
| `courseid` | BIGINT | Course ID |
| `date` | INT | 日付 (YYYYMMDD形式の整数) |
| `total_seconds` | BIGINT | 当日の累計学習秒数 |
| `video_seconds` | BIGINT | 当日の動画視聴秒数 |
| `heartbeat_count` | INT | 当日のHeartbeat数 |
| `timecreated` | BIGINT | 作成日時 |
| `timemodified` | BIGINT | 更新日時 |

### 4.4 Total テーブル (`mdl_local_timetrack_total`)

累積合計。ダッシュボード表示用。

| **Field** | **Type** | **Description** |
|---|---|---|
| `id` | BIGINT | PK |
| `userid` | BIGINT | User ID |
| `courseid` | BIGINT | Course ID |
| `total_seconds` | BIGINT | 累計学習時間（秒） |
| `video_seconds` | BIGINT | 累計動画視聴時間（秒） |
| `is_certified` | TINYINT(1) | 420時間達成フラグ (0/1) |
| `timecreated` | BIGINT | 作成日時 |
| `timemodified` | BIGINT | 最終更新日時 |

### 4.5 Video テーブル (`mdl_local_timetrack_video`)

動画視聴セグメントの詳細記録。

| **Field** | **Type** | **Description** |
|---|---|---|
| `id` | BIGINT | PK |
| `userid` | BIGINT | User ID |
| `courseid` | BIGINT | Course ID |
| `cmid` | BIGINT | Course Module ID |
| `vimeo_id` | VARCHAR(20) | Vimeo動画ID |
| `segment_start` | INT | セグメント開始秒 |
| `segment_end` | INT | セグメント終了秒 |
| `playback_rate` | DECIMAL(3,2) | 再生速度 (1.00=通常) |
| `timecreated` | BIGINT | 記録日時 |

## 5. 機能要件 (Functional Requirements)

### 5.1 学習進捗管理 (Study Tracking) - **Priority: Critical**

- **要件:**
    - 学習者が動画を再生している間、または教材ページを開いている間のみ時間を計測する。
    - 別のタブを開いたり、ブラウザを最小化している間は計測を停止する（Page Visibility API）。
    - アイドル状態（5分間操作なし）では計測を停止する。
    - 複数タブでの同時学習を排除する（BroadcastChannel API）。
    - ヘッダー領域に累計学習時間をリアルタイム表示する（中国版の「已学习小时XX」に相当）。
- **実装方針:**
    - **Frontend:** JavaScriptでPage Visibility API + BroadcastChannel API + Vimeo Player SDK + アイドル検知を統合。条件を満たす場合のみ、30秒ごとにAJAXで「Heartbeat」を送信。
    - **Backend:** `local_timetrack`プラグインのWebサービスがHeartbeatを受信し、`mdl_local_timetrack_heartbeat`にINSERT。
    - **Aggregation:** Cronタスクが5分間隔でrawデータをdaily/totalに集計。

### 5.2 順次学習 (Sequential Learning) - **Priority: High**

- **要件:**
    - コースは複数の単元（Unit）で構成される（中国版は20単元）。
    - 各単元は「教材閲覧 + 動画視聴 + 単元テスト」で構成される。
    - 単元テストの正答率が70%以上の場合のみ、次の単元がアンロックされる。
    - 初回ログイン時はUnit 1のみアクセス可能。
- **実装方針:**
    - Moodle標準の「活動完了条件 (Activity Completion)」+「コース制限 (Restrict Access)」で実現。
    - Quiz活動に「成績70%以上」の完了条件を設定。

### 5.3 課題提出・添削 (Assignment & Grading) - **Priority: High**

- **要件:**
    - 全単元の学習・テスト完了後に課題提出が可能になる。
    - 受講者は以下2点をアップロードする:
        - **教案ドキュメント** (doc/docx形式)
        - **試講動画** (mp4形式、20分以上)
    - 講師が10項目のルーブリックで採点する（60点満点）。
    - 採点結果は提出後5営業日以内に公開される。
- **実装方針:**
    - Moodle標準の「課題 (Assignment)」活動を使用。
    - ルーブリック（Rubric）による構造化された採点をMoodle標準機能で実現。
    - ファイルサイズ上限の設定（動画ファイル対応）。

### 5.4 成績管理・合否判定 (Grading) - **Priority: High**

- **要件:**
    - 総合成績 = 課題成績（60点満点）+ 試験成績（40点満点）= 100点満点
    - 合格条件: 合計60点以上、かつ各項目が満点の60%以上
        - 課題: 36点以上（60点の60%）
        - 試験: 24点以上（40点の60%）
    - いずれか一方が基準未満の場合は不合格。
- **実装方針:**
    - Moodle標準の「成績表 (Gradebook)」で加重計算を設定。
    - 合否判定ロジックは `local_timetrack` プラグインで実装。

### 5.5 決済・自動登録 (Payment Integration) - **Priority: High**

- **要件:** ユーザーがStripeでコースを購入後、即座に該当コースへのアクセス権を付与する。
- **実装方針:**
    - **MVP (Phase 1):** `paygw_stripe` + `enrol_fee` 標準プラグインを使用（コード不要）。
        - Moodle Payment APIに準拠。インストール＋APIキー設定のみ。
        - JCB対応（日本アカウントで自動有効化）、3Dセキュア自動処理。
    - **Phase 2:** Custom Webhook方式に移行。
        - Stripe Checkout → `checkout.session.completed` Webhook → Moodle APIで即時登録。
        - ユーザーの事前アカウント登録不要（LP→決済→即時受講の最高UX）。
        - Webhook署名検証（HMAC-SHA256）、冪等性確保（event.id重複チェック）。

### 5.6 修了証発行 (Certification) - **Priority: Medium**

- **要件:**
    - 合格条件（成績 + 420時間）を全て満たした受講者に修了証を自動発行する。
    - PDF形式でダウンロード可能。
    - 証書には検証番号（Certificate Validation Number）を含める。
- **実装方針:**
    - Moodle標準の「カスタム証明書 (Custom Certificate)」活動を使用。
    - 発行条件は活動完了 + 成績条件 + 420時間達成フラグの組み合わせ。

### 5.7 UI/UXデザイン - **Priority: Medium**

- **要件:** 日本語・中国語の切り替えが容易で、スマホでの学習体験が良いこと。
- **実装方針:**
    - 親テーマとして `Lambda` を使用。
    - 子テーマ `theme_lambda_child` を作成し、カスタムCSSでフォント（Noto Sans JP/SC）や配色を調整。
    - ヘッダーに言語切り替えスイッチャーと累計学習時間を配置。

### 5.8 ライブ配信 (Live Class) - **Priority: Low (MVP)**

- **要件:** Zoom等のライブ授業を受講者に提供する。配信後のアーカイブ視聴も必要。
- **実装方針:**
    - MVP: URL活動としてZoom/Google Meetリンクを埋め込み。
    - アーカイブはVimeoにアップロード後、通常動画として視聴可能に。
    - Phase 2: LTI連携による統合的なライブ配信。

## 6. 非機能要件 (Non-Functional Requirements)

- **パフォーマンス:** 同時接続100名程度を想定。Nginx最適化、PHP OPcache、Redis MUCキャッシュ。
- **セキュリティ:**
    - 動画の直リンク禁止（Vimeoのドメイン制限機能を利用）。
    - ユーザーパスワードポリシーの強制（Moodle標準機能）。
    - 全ページHTTPS必須。
    - 13層不正防止（タブ可視、アイドル検知、複数タブ排除、早送り防止、HMAC検証等）。
    - 同時ログイン制限（`limitconcurrentlogins=1` + `auth_uniquelogin`）。
- **可用性:** 日次バックアップ（DBダンプ + MoodleData）。
- **多言語:** 日本語（主要）、中国語簡体字（受講者向け）、英語（ベースキー）。

## 7. 今後のロードマップ (Phasing)

1. **Phase 1 (MVP):** 基盤構築、動画配信、順次学習、単元テスト、課題提出・添削、420時間計測、決済（paygw_stripe）、修了証発行、特定商取引法表記。
2. **Phase 2:** Custom Webhook決済（事前登録不要UX）、就職支援掲示板機能、公的資格（登録日本語教員）制度とのAPI連携、オフライン試験対応、証書オンライン検証機能、インボイス制度対応。
3. **Phase 3:** AIによる自動添削補助機能、多言語チャットボット。

## 8. 未確定事項・リスク (Open Items)

- コンテンツ規模（コース数、動画時間、教材点数、テスト問題数）は未確定。
- 教案採点の10項目ルーブリックの日本語版基準は策定が必要。
- クライアント側の社長は日本語不可（通訳経由のコミュニケーション）。
