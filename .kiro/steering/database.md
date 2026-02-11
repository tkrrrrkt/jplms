# Database Standards

## Engine & Configuration

- **Engine**: InnoDB 一択（MyISAMは使用禁止）
- **Charset**: `utf8mb4_unicode_ci`（Moodle 4.x必須）
- **接続プレフィックス**: `mdl_`（config.phpで設定、コード内ではハードコードしない）

### 本番環境の推奨設定（8〜16GB RAM、数百ユーザー想定）
```ini
innodb_buffer_pool_size = 4G       # 同居構成: RAM×50%、専用DB: RAM×70-80%
innodb_log_file_size = 512M
innodb_flush_log_at_trx_commit = 2 # 学習ログの性質上、OS経由フラッシュで許容
innodb_flush_method = O_DIRECT
innodb_file_per_table = 1          # Moodle必須
max_connections = 200
slow_query_log = 1
long_query_time = 2
```

## Schema Design Rules

### テーブル命名
- `{local_pluginname_tablename}` 形式（Frankenstyle準拠）
- Moodle 4.3以降: テーブル名53文字、カラム名63文字まで
- コード内では `{tablename}` 構文必須。`mdl_` プレフィックスをハードコードしない

### Schema定義
- **全テーブルは `db/install.xml` で定義**（XMLDB Editor使用）
- raw SQL による CREATE TABLE は禁止
- スキーマ変更は `db/upgrade.php` で冪等に実装（`field_exists()` チェック必須）

### 標準カラム
- `id` (BIGINT, PK, AUTO_INCREMENT) — 全テーブル必須
- `timecreated` (BIGINT, Unix Timestamp) — 作成日時
- `timemodified` (BIGINT, Unix Timestamp) — 更新日時
- `userid` (BIGINT, FK to mdl_user) — ユーザー参照時

### インデックス設計
- 書き込み頻度の高いテーブル（Heartbeat等）はインデックスを最小限にする
- レポート用テーブルは読み取り最適化インデックスを設置
- 複合インデックスの順序: 選択性の高いカラムを先頭に

## local_timetrack のデータパイプライン

### 3段階パイプライン設計
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

### テーブル構成（4テーブル）

| テーブル | 用途 | 書き込み頻度 | 読み取り頻度 |
|---------|------|-------------|-------------|
| `heartbeat` | 生データ一時保管 | 極高（30秒/人） | 低（Cronのみ） |
| `daily` | 日次サマリー | 中（5分間隔Cron） | 中（レポート） |
| `total` | 累積合計 | 中（5分間隔Cron） | 高（ダッシュボード） |
| `video` | 動画視聴セグメント | 中（15秒間隔） | 中（進捗表示） |

### 負荷見積もり
- 同時100人学習: 200 INSERT/分（Heartbeat + Video合計）
- 1日8時間運用: 約96,000行/日（rawテーブル）
- 30日でクリーンアップ: rawテーブルは常時約300万行以下

## DML API ベストプラクティス

### 大量データ処理
```php
// MUST use get_recordset for bulk processing
$rs = $DB->get_recordset_select('local_timetrack_heartbeat',
    'processed = 0 AND timecreated < :cutoff',
    ['cutoff' => time() - 300]);
foreach ($rs as $row) {
    // Process one row at a time — memory efficient
}
$rs->close(); // CRITICAL: 必ず閉じる

// NEVER: get_records for large datasets（全行メモリにロード）
```

### SQL安全ルール
```php
// IN句: get_in_or_equal() 必須（implodeでIDを結合しない）
[$insql, $params] = $DB->get_in_or_equal($userids, SQL_PARAMS_NAMED, 'uid');
$sql = "SELECT * FROM {user} WHERE id {$insql}";

// LIKE: sql_like() + sql_like_escape() 必須
$likesql = $DB->sql_like('fullname', ':search', false);
$params = ['search' => '%' . $DB->sql_like_escape($search) . '%'];

// プレースホルダ: 名前付き (:name) を推奨。同名の再利用は禁止
```

### Moodle標準テーブルの扱い
- Moodle標準テーブル（mdl_user, mdl_course等）は**読み取りのみ**
- 標準テーブルへの書き込みは**Moodle API経由**で行う（直接INSERTしない）
- `mdl_logstore_standard_log` には依存しない（パフォーマンス問題の原因）

---
_Define data patterns, not every column. Detailed schemas belong in CCSDD design.md_
