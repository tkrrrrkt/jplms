# Technology Stack

## Architecture

Moodle 4.x をLMSエンジンとして採用。教育要件の9割を標準機能でカバーし、独自要件のみLocalプラグインとして開発する「Plugin-First」アーキテクチャ。

Single-tenant構成。BFF層やAPI Gateway は不要。フロントエンドはMoodle標準のMustacheテンプレート + 必要最小限のJavaScript。

## Core Technologies

- **LMS Engine**: Moodle 4.x (Latest Stable)
- **Language**: PHP 8.2 推奨（8.1〜8.3対応、型宣言必須）
- **Database**: MySQL 8.0 (or MariaDB 10.11+), charset: `utf8mb4_unicode_ci`
- **Web Server**: Nginx + PHP-FPM（LEMPスタック）
- **OS**: Linux (Ubuntu 22.04 LTS)
- **Cache**: Redis 7.x（セッション + MUCキャッシュ、別インスタンス推奨）

## Infrastructure Requirements

### Minimum VPS Spec（数百ユーザー想定）
- 4 vCPU / 8GB RAM / 80GB NVMe SSD
- Vimeo埋め込みのため動画配信負荷はVimeo CDNが吸収

### Redis構成（必須）
- **ポート6379**: セッション用（`noeviction`、AOF永続化）
- **ポート6380**: MUCキャッシュ用（`allkeys-lru`、永続化不要）
- セッション用とMUCキャッシュ用は必ずインスタンスを分離する

### PHP-FPM
- `pm = dynamic`, `pm.max_children` = (PHP用RAM) ÷ (プロセスあたり約100MB)
- `pm.max_requests = 1000`（メモリリーク防止）
- `memory_limit = 512M`, `max_execution_time = 300`

### OPcache（必須）
- `opcache.memory_consumption = 256`（プラグイン多数のため）
- `opcache.max_accelerated_files = 20000`
- `opcache.save_comments = 1`（Moodle必須）
- `opcache.enable_cli = 1`（Cron高速化）

### Cron
- **systemd timer推奨**（crontab非推奨）
- **1分間隔の実行が必須**（Moodle公式要件）
- `Type=oneshot` で重複実行防止

### Nginx最適化
- X-Accel-Redirect（ファイル配信をPHPからNginxにオフロード）
- FastCGIバッファ拡張（`fastcgi_buffers 256 16k`）
- 静的アセット30日キャッシュ

## Frontend Stack

- **Theme**: Lambda (Premium) + `theme_lambda_child` (子テーマでカスタマイズ)
- **Template**: Mustache (Moodle Standard) + `renderable`/`templatable` インターフェース
- **CSS**: Bootstrap 5 + SCSS overrides in child theme
- **JS (AMD/ESM)**:
  - **Page Visibility API** — タブの可視/非可視状態を検知。学習時間計測の核心
  - **BroadcastChannel API** — 同一ブラウザ内の複数タブ排除（パラレル受講防止）
  - **Vimeo Player SDK** — 再生/一時停止/シーク/速度変更イベントのフック
  - **navigator.sendBeacon** — ページ離脱時のデータ送信（Heartbeat最終送信）
  - **Moodle AJAX API** (`core/ajax`) — Heartbeat定期送信
- **Fonts**: Noto Sans JP / Noto Sans SC

## External Integrations

### Payment: Stripe（段階的アプローチ）
- **MVP (Phase 1)**: `paygw_stripe` + `enrol_fee`（標準プラグイン、コード不要）
  - Moodle Payment APIに準拠。インストール＋APIキー設定のみ
  - JCB対応（日本アカウントで自動有効化）、3Dセキュア自動処理
- **Phase 2**: Custom Webhook（Pattern C）に移行
  - Stripe Checkout → `checkout.session.completed` Webhook → Moodle API
  - LP→決済→即時登録のシームレスフロー実現
  - ユーザーの事前アカウント登録不要（最高UX）
- **共通**: Webhook署名検証（HMAC-SHA256）、冪等性確保（event.id重複チェック）

### Video: Vimeo
- oEmbed/Player SDK、ドメインレベルプライバシー制限
- `mod_videotime` プラグインの採用検討（Pro版: 視聴率トラッキング、早送り防止、レジューム再生）

### Live Class: Zoom / Google Meet
- LTI or URL resource (Phase 1ではURL埋め込み)

## Development Standards

### Data Access Pattern
```php
// ALWAYS use Moodle DML API. Raw SQL is PROHIBITED.
global $DB;
$record = $DB->get_record('table', ['id' => $id], '*', MUST_EXIST);
$records = $DB->get_records('table', ['course' => $courseid]);

// 大量データ処理: get_recordset + close() 必須
$rs = $DB->get_recordset('table', ['processed' => 0]);
foreach ($rs as $row) { /* process */ }
$rs->close(); // CRITICAL: 忘れるとDBリソースリーク

// テーブル参照: {tablename} 構文必須（mdl_プレフィックスをハードコードしない）
$sql = "SELECT * FROM {local_timetrack_heartbeat} WHERE userid = :uid";

// トランザクション
$transaction = $DB->start_delegated_transaction();
try {
    $DB->insert_record('table', $data);
    $transaction->allow_commit();
} catch (Exception $e) {
    $transaction->rollback($e);
}
```

### Input Handling Pattern
```php
// NEVER use $_GET, $_POST directly.
$id = required_param('id', PARAM_INT);
$name = optional_param('name', '', PARAM_TEXT);
// PARAM_RAW は原則禁止。出力時に format_text() で処理
```

### Security Pattern
```php
// Page entry: always authenticate and authorize
require_login($course);
require_sesskey();  // For POST/form processing
$context = context_course::instance($courseid);
require_capability('local/timetrack:view', $context);
```

### Output Pattern
```php
// Mustache + Templatable インターフェース（HTML直接出力は禁止）
$renderable = new \local_timetrack\output\dashboard($data);
echo $OUTPUT->render_from_template('local_timetrack/dashboard',
    $renderable->export_for_template($OUTPUT));

// 文字列エスケープ: s() / format_string() / format_text()
echo '<input value="' . s($title) . '" />';
```

### Multilingual Pattern
```php
// NEVER hardcode UI strings
$title = get_string('pluginname', 'local_timetrack');
// settings.php では new lang_string() を使用（遅延読み込み）
// Language files: lang/en/ (base key), lang/ja/ (display), lang/zh_cn/ (Chinese)
```

### Code Style
- **Standard**: Moodle Coding Style (Frankenstyle) + PSR-12準拠
- **Documentation**: PHPDoc mandatory for all classes and functions
- **Comments**: English
- **UI Strings**: Japanese (lang/ja/), with English (lang/en/) as base key
- **Lint**: `local_codechecker`（Moodle専用PHP_CodeSniffer）必須
- **Hooks API**: Moodle 4.4+ では PSR-14 Hooks API を優先（legacy callbacks との共存可）

## Development Environment

### Required Tools
- PHP 8.2, Composer
- MySQL 8.0 / MariaDB 10.11+
- Nginx, Redis 7.x
- Node.js (for Moodle Grunt tasks: SCSS compile, JS minify)
- `local_codechecker` plugin（コード品質チェック）

### Common Commands
```bash
# Moodle cache purge:
php admin/cli/purge_caches.php

# Plugin install/upgrade:
php admin/cli/upgrade.php

# SCSS compile (child theme):
npx grunt css  # from Moodle root

# CodeChecker:
php local/codechecker/cli/checker.php --standard=moodle local/timetrack/
```

## Key Technical Decisions

| Decision | Rationale |
|----------|-----------|
| Moodle 4.x over custom LMS | 教育機能の9割をカバー。開発コスト・期間を大幅に削減。 |
| Local Plugin architecture | コア非改変でMoodleアップグレード互換性を維持。 |
| Lambda Premium Theme | 成熟したレスポンシブテーマ。子テーマで安全にカスタマイズ可能。 |
| MVP: paygw_stripe + enrol_fee | コード不要で即時稼働。Phase 2でCustom Webhookに移行。 |
| Vimeo (not self-hosted) | ドメイン制限機能で動画の不正コピーを防止。CDN配信でパフォーマンス確保。 |
| Heartbeat方式の学習計測 | Page Visibility + Vimeo SDK + BroadcastChannel の三重条件で不正防止。 |
| Redis必須 | セッション500→80ms高速化。MUCキャッシュでページレスポンス改善。 |
| Plugin名: local_timetrack | 簡潔。4テーブル設計（heartbeat/daily/total/video）。 |
| PHP 8.2 | 8.1〜8.3カバーの安定版。OPcacheデフォルト値がMoodle推奨に合致。 |

---
_Document standards and patterns, not every dependency_
