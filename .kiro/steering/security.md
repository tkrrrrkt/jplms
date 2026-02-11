# Security Standards

## Authentication & Authorization

### Page Entry Pattern（全ページスクリプト必須）
```php
require_once(__DIR__ . '/../../config.php');
$id = required_param('id', PARAM_INT);
$course = $DB->get_record('course', ['id' => $id], '*', MUST_EXIST);

// 1. ログイン + コースアクセス権（エンロール）確認
require_login($course);

// 2. コンテキスト特定
$context = context_course::instance($course->id);

// 3. 具体的な操作権限の確認
require_capability('local/timetrack:view', $context);

// 4. ページ設定
$PAGE->set_url('/local/timetrack/index.php', ['id' => $id]);
$PAGE->set_context($context);
```

### 権限設計ルール
- **ロールIDではなくCapabilityで判定**（`has_capability()` / `require_capability()`）
- `db/access.php` で定義、変更時は `version.php` のバージョンバンプ必須
- `has_capability()` = UI表示制御（ボタンの表示/非表示）
- `require_capability()` = アクション実行ゲート（ハードブロック）
- Risk bitmask: RISK_SPAM / RISK_PERSONAL / RISK_XSS / RISK_CONFIG / RISK_DATALOSS

## Input Validation

### 入力パラメータ（`$_GET`/`$_POST` 直接アクセス禁止）
```php
$id     = required_param('id', PARAM_INT);       // DB ID
$name   = optional_param('name', '', PARAM_TEXT); // プレーンテキスト
$action = optional_param('action', '', PARAM_ALPHA); // アクション文字列
$url    = optional_param('link', '', PARAM_URL);  // 外部URL
// PARAM_RAW は原則禁止。出力時に format_text() で処理
```

### CSRF保護（全状態変更操作に必須）
```php
// フォーム: Moodle Forms APIが自動処理
// 手動アクションリンク:
$url = new moodle_url('/local/timetrack/action.php', [
    'action' => 'delete', 'id' => $item->id, 'sesskey' => sesskey(),
]);
// 処理側:
require_sesskey(); // これなしでの状態変更は脆弱性
```

## Output Escaping（XSS防止）

| 関数 | 用途 | 例 |
|------|------|-----|
| `s($text)` | 属性値・プレーンテキスト | `<input value="<?= s($title) ?>">` |
| `format_string($text)` | 短文（活動名、見出し） | multilangフィルタ適用 |
| `format_text($text, $format)` | リッチコンテンツ（投稿、説明文） | HTMLクリーニング適用 |

- **`noclean => true` はユーザー入力に対して絶対に使用しない**
- PHP内での直接HTML生成（`echo "<h1>$var</h1>"`）は禁止 → Mustacheテンプレート使用

## Stripe Webhook Security

### 必須チェックリスト
1. **署名検証**: `Stripe\Webhook::constructEvent()` で HMAC-SHA256 を検証
   - 生のリクエストボディ（`php://input`）を使用（フレームワークパース前に処理）
2. **冪等性**: `event.id` または `checkout_session.id` をDBに記録し重複処理を防止
3. **タイムスタンプ検証**: デフォルト300秒の許容範囲でリプレイ攻撃を防止
4. **即時レスポンス**: HTTP 200をすぐに返却（Stripeリトライ回避）
5. **CSRF不要**: サーバー間通信のため `sesskey` 検証は不要。Stripe署名で真正性を担保

### シークレット管理
- APIキー・Webhookシークレットをコードに埋め込まない
- `config.php` または環境変数で管理
- テスト環境と本番環境でキーを分離

## 420時間計測の不正防止（多層防御）

| レイヤー | 技術 | 目的 |
|---------|------|------|
| タブ可視検知 | Page Visibility API | 非表示タブでの「ながら学習」排除 |
| アイドル検知 | mousemove/keydown/scroll + 5分タイムアウト | 「ゾンビセッション」排除 |
| 複数タブ排除 | BroadcastChannel API | 同一ブラウザ内のパラレル受講防止 |
| 同時ログイン制限 | `limitconcurrentlogins=1` + auth_uniquelogin | 別ブラウザでの二重計上防止 |
| 早送り防止 | Vimeo SDK `seeking`/`seeked` イベント | 未視聴区間スキップの物理的阻止 |
| 倍速再生対策 | `playbackratechange` → 強制1.0x or 時間補正 | 時間短縮の排除 |
| ページ離脱 | navigator.sendBeacon | 最終区間のデータ損失防止 |
| トークン検証 | HMAC署名ローテーション + ワンタイムトークン | Heartbeat改ざん・リプレイ防止 |
| ボット検知 | Heartbeatジッター分析 + navigator.webdriver | 自動化ツール排除 |
| レート制限 | 1ユーザーあたり最大3 Heartbeat/分 | 不正データ排除 |
| 日次上限 | 1日最大8時間（設定可能） | 異常値排除 |
| 理解度チェック | 定期ポップアップ + 単元テスト | 流し見対策（技術的完全防止が困難なため制度的対策） |
| 監査証跡 | IPアドレス + User Agent + セッションID記録 | 事後検証 |

## Vimeo Security

- **ドメイン制限**: Vimeo設定でMoodleサイトのドメインのみ埋め込み許可
- **直リンク禁止**: Vimeoのプライバシー設定で動画URLの直接アクセスを遮断
- **ダウンロード禁止**: Vimeo側で設定

## File Security

- **Moodledata**: Webルート外に配置（`/var/moodledata`）
- **X-Accel-Redirect**: ファイル配信はNginxに委譲（PHPプロセス解放）
- `$CFG->directorypermissions = 02770`（デフォルト02777より厳格に）
- コードディレクトリ: `root:www-data`, `755`（www-dataは読み取りのみ）

---
_Security is non-negotiable. Every page script follows the require_login → require_capability pattern._
