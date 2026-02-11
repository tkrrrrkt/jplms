# Moodle 4.x アーキテクチャと開発ベストプラクティスに関する包括的技術レポート

## 1. はじめに：Moodle 4.x におけるパラダイムシフトとアーキテクトの責務

Moodle 4.x シリーズ（特に最新の Stable リリース）への移行は、単なるバージョンアップ以上の意味を持っています。これは、学習管理システム（LMS）としてのユーザー体験（UX）の根本的な再定義であり、開発者にとっては、過去20年間に蓄積された「技術的負債」と決別し、現代的なPHP開発手法へと完全に移行するための転換点です。シニア・ソリューションアーキテクトとしてこのプロジェクトを指揮するにあたり、最も重要な認識は「Everything is a Plugin（すべてはプラグインである）」というMoodleの基本哲学を、現代的なオブジェクト指向設計（OOP）と厳格なセキュリティ基準の中で再解釈することにあります。

本レポートは、公式ドキュメント、開発者Wiki、およびコミュニティでの議論に基づき、Moodle 4.x 環境における堅牢で保守性の高いシステム構築のための指針を網羅的に解説します。特に、プラグインアーキテクチャの選定、データベース操作の安全性、そして「Frankenstyle」と呼ばれる独自のコーディング規約の遵守について、実践的なコード例を交えて詳述します。

---

## 2. Moodleプラグインアーキテクチャのベストプラクティス (Moodle 4.x)

Moodleの強力な拡張性は、そのモジュラー構造に起因します。しかし、自由度が高いゆえに、不適切なプラグインタイプの選択や、非効率なコード配置がプロジェクトの長期的な保守性を損なうケースが後を絶ちません。Moodle 4.x では、特にナビゲーションとUIコンポーネントの扱いが大きく変更されており、これに合わせたアーキテクチャ設計が不可欠です。

### 2.1 アーキテクチャ選定：Localプラグイン vs Blockプラグイン

Moodle 4.x のUX刷新において最も顕著な変化の一つは、ブロック（Block）の扱いに関するものです。以前のバージョンでは、画面の両サイドに常に表示される情報源としてブロックが多用されましたが、4.x では「ドロワー（Drawer）」インターフェースが採用され、ブロックはデフォルトで隠される傾向にあります。この変更は、機能の実装場所としてのプラグインタイプの選択に重大な影響を与えます 。

#### 2.1.1 判断基準と設計思想

開発者は、「ユーザーインターフェースが必要か」「機能は特定のコンテキスト（コース、カテゴリ）に依存するか」を基準にプラグインタイプを選定する必要があります。

- **Localプラグイン (`local`)**:
    
    - **役割**: システム全体に影響するバックエンド処理、API統合、イベントリスナー、管理ツールの拡張に適しています。UIを持たない、あるいは管理画面のみにUIを持つ機能の実装に最適です 。
        
    - **4.xでの重要性**: ブロックの視認性が低下した現在、バックグラウンドタスクや全サイト共通のロジックは迷わず `local` プラグインとして実装すべきです。
        
    - **実行順序**: インストールやアップグレードプロセスにおいて、Localプラグインは常に最後に実行されることが保証されています。これにより、他のコアコンポーネントへの依存関係を安全に解決できます 。
        
- **Blockプラグイン (`block`)**:
    
    - **役割**: 特定のコースやダッシュボードに関連する補助情報の表示。
        
    - **4.xでの制約**: ユーザーが意図的にドロワーを開かない限り視認されないため、重要な通知や必須の操作フローをブロック内に配置することはアンチパターンとなります。
        

#### 2.1.2 アーキテクチャ実装比較：バックグラウンド同期機能

**シナリオ**: 外部の人事システムからユーザー情報を1時間ごとに同期する機能を実装する。

**【悪いコード例】Blockプラグインとして実装**

`blocks/hrsync` を作成し、ブロックの表示処理の中に同期ロジックを混入させる、あるいはブロックの存在を前提としたCronタスクを設定する。

- **問題点**:
    
    - **UIとロジックの混同**: UIコンポーネントであるブロックに、本来バックエンドで完結すべき同期ロジックが含まれています。
        
    - **管理の複雑化**: 管理者は機能を利用するために、どこかのページにブロックを配置しなければならず、UXを損ねます。
        
    - **パフォーマンス**: ブロックが表示されるたびに不要な初期化処理が走るリスクがあります。
        

**【良いコード例】Localプラグインとして実装**

`local/hrsync` を作成し、MoodleのTask APIを利用して実装する。

- **ファイル構成**:
    
    - `local/hrsync/db/tasks.php`: スケジュールタスクの定義
        
    - `local/hrsync/classes/task/sync_users.php`: 実行ロジック本体
        
    - `local/hrsync/version.php`: バージョン管理
        
- **実装例 (`local/hrsync/db/tasks.php`)**:
    
    PHP
    
    ```
    defined('MOODLE_INTERNAL') |
    
    ```
    

| die();

````
$tasks = [
        'classname' => 'local_hrsync\task\sync_users',
        'blocking' => 0,
        'minute' => '0',
        'hour' => '*',
        'day' => '*',
        'month' => '*',
        'dayofweek' => '*',
    ];
```
*参照ドキュメント*: [Plugin types - Local plugins](https://moodledev.io/docs/5.0/apis/plugintypes/local) 
````

### 2.2 モダンなディレクトリ構造とオートローディング

Moodle 2.6以降導入され、4.xで完全に標準となったのが「自動クラスローディング（Automatic Class Loading）」です。かつてのMoodle開発では、すべての関数を巨大な `lib.php` に詰め込むのが一般的でしたが、これは現在では明確なアンチパターンとされています 。

#### 2.2.1 `lib.php` の役割縮小と `classes/` の活用

**概念**:

`lib.php` は、Moodleコアが特定のタイミング（フックポイント）で呼び出す必要がある「コールバック関数」のみを定義する場所として残されています。それ以外のビジネスロジック、データ処理、ヘルパー関数はすべて `classes/` ディレクトリ配下に配置し、名前空間（Namespace）を利用してオートロードさせる必要があります。

- **メリット**:
    
    - **メモリ効率**: `lib.php` はプラグインが有効な場合、頻繁に読み込まれますが、クラスファイルは実際に使用される瞬間までメモリにロードされません。
        
    - **可読性と保守性**: 1ファイル1クラスの原則により、コードの所在が明確になります。
        

#### 2.2.2 実装比較：レポート生成ロジック

**【悪いコード例】肥大化した `lib.php` (Legacy Anti-Pattern)**

ファイル: `local/analytics/lib.php`

PHP

```
<?php
// すべてのロジックがこのファイルに詰め込まれている
function local_analytics_generate_report($courseid) {
    global $DB;
    // 300行に及ぶSQL構築とデータ処理...
}

function local_analytics_send_notification($userid) {
    // 100行のメール送信処理...
}

function local_analytics_extend_navigation($nav) {
    // ナビゲーション拡張
}
```

_解説_: このファイルは、ナビゲーション拡張のためだけに読み込まれたとしても、レポート生成や通知送信の関数定義までメモリを消費します。

**【良いコード例】名前空間とオートローディングの活用 (Modern Best Practice)**

ファイル: `local/analytics/lib.php` (コールバックのみ)

PHP

```
<?php
defined('MOODLE_INTERNAL') |

| die();

/**
 * Navigation extension callback.
 */
function local_analytics_extend_navigation_course($navigation, $course, $context) {
    // ロジックはクラスに委譲
    \local_analytics\navigation::extend_course($navigation, $course, $context);
}
```

ファイル: `local/analytics/classes/report/generator.php` (ビジネスロジック)

PHP

```
<?php
namespace local_analytics\report;

defined('MOODLE_INTERNAL') |

| die();

class generator {
    /**
     * Generates the course report.
     *
     * @param int $courseid
     * @return array
     */
    public static function generate(int $courseid): array {
        global $DB;
        // 複雑なデータ処理はここでのみ定義・実行される
        return $DB->get_records('local_analytics_data', ['courseid' => $courseid]);
    }
}
```

_参照ドキュメント_: [Automatic class loading](https://docs.moodle.org/dev/Automatic_class_loading)

---

## 3. データベース操作とセキュリティ (DML & Security)

Moodleは、データベース抽象化レイヤー（DML API）を提供しており、開発者は生のSQL関数（`mysql_query` や `PDO` の直接利用）を使用することは許されません。これにより、MySQL, MariaDB, PostgreSQL, Oracle, MSSQLといった異なるデータベースバックエンド間での互換性が保たれ、SQLインジェクションなどのセキュリティリスクが排除されます 。

### 3.1 DML (Data Manipulation Language) API の適正利用

すべてのデータベース操作は、グローバルオブジェクト `$DB` を介して行われます。Moodle 4.x 開発においては、適切なメソッドの使い分けがパフォーマンスとコードの安全性に直結します。

#### 3.1.1 レコード取得メソッドの使い分け

|**メソッド**|**用途**|**特徴・注意点**|
|---|---|---|
|`get_record`|単一行の取得|条件に一致するレコードが**1件のみ**であることを期待する。複数見つかった場合はエラーとなる。第4引数 `$strictness` で挙動制御可能。|
|`get_records`|複数行の取得|結果を配列（IDをキーとする）で返す。メモリ消費に注意。大量データには不向き。|
|`get_recordset`|大量データの取得|**重要**: イテレータを返すため、数万件のデータでもメモリを圧迫しない。処理後に必ず `$rs->close()` が必要。|
|`get_field`|単一カラムの値|特定のフィールド値だけが必要な場合に高速。|
|`record_exists`|存在確認|データを取得せず、存在有無だけを確認する（`SELECT 1` 相当）。|

#### 3.1.2 SQLインジェクション対策とプレースホルダ

Moodleセキュリティの要は、SQL文への変数の直接埋め込みを禁止し、必ずプレースホルダを使用することです。

**【悪いコード例】変数の直接埋め込み (Vulnerable)**

PHP

```
$courseid = optional_param('id', 0, PARAM_INT);
$status = 'active';

// 危険: 変数を直接SQL文字列に結合している
// SQLインジェクションの脆弱性あり
$sql = "SELECT * FROM mdl_local_log WHERE courseid = $courseid AND status = '$status'";
$logs = $DB->get_records_sql($sql);
```

**【良いコード例】名前付きプレースホルダの利用 (Secure)**

PHP

```
$courseid = required_param('id', PARAM_INT); // 入力バリデーション
$status = 'active';

// 安全: 波括弧 {} でテーブルプレフィックスを自動解決
// 安全: :name 形式のプレースホルダを使用
$sql = "SELECT * FROM {local_log} WHERE courseid = :courseid AND status = :status";
$params = [
    'courseid' => $courseid,
    'status' => $status
];

$logs = $DB->get_records_sql($sql, $params);
```

_解説_:

1. **`{tablename}`構文**: `mdl_` などのプレフィックスをハードコードせず、`{local_log}` と記述することで、インストール環境に合わせたプレフィックスに自動変換されます 。
    
2. **プレースホルダ**: 値はドライバレベルでエスケープされ、インジェクションを防ぎます。`?`（疑問符）プレースホルダも使用可能ですが、可読性と保守性の観点から名前付きプレースホルダ（`:name`）が推奨されます 。
    

_参照ドキュメント_:([https://moodledev.io/docs/4.5/apis/core/dml](https://moodledev.io/docs/4.5/apis/core/dml))

### 3.2 トランザクション管理

データの整合性を保つため、複数の書き込み操作（INSERT, UPDATE, DELETE）を行う場合は、必ずトランザクションを利用します。Moodleは「委譲トランザクション（Delegated Transactions）」をサポートしており、ネストされたトランザクション呼び出しを適切に処理します 。

**【良いコード例】トランザクションの実装パターン**

PHP

```
global $DB;

// トランザクション開始
$transaction = $DB->start_delegated_transaction();

try {
    // ステップ1: 親レコードの作成
    $parent = new stdClass();
    $parent->name = 'Parent Item';
    $parent->timecreated = time();
    $parentid = $DB->insert_record('local_parent', $parent);

    // ステップ2: 子レコードの作成（親IDに依存）
    $child = new stdClass();
    $child->parentid = $parentid;
    $child->data = 'Child Data';
    $DB->insert_record('local_child', $child);

    // すべて成功した場合のみコミット
    $transaction->allow_commit();

} catch (Exception $e) {
    // 例外発生時は自動的にロールバックされるが、
    // 明示的なロールバック呼び出し推奨（例外の再スローを含む）
    $transaction->rollback($e);
}
```

_参照ドキュメント_:([https://moodledev.io/docs/4.5/apis/core/dml/delegated-transactions](https://moodledev.io/docs/4.5/apis/core/dml/delegated-transactions))

### 3.3 コンテキストとケーパビリティによるアクセス制御

Moodleのセキュリティモデルの中核は、**Context（コンテキスト）**、**Role（ロール）**、**Capability（ケーパビリティ/権限）**の3要素です。コード内では、「ユーザーが特定のロールを持っているか」を確認するのではなく、「ユーザーが現在のコンテキストで特定の操作を行う権限（ケーパビリティ）を持っているか」を確認します 。

#### 3.3.1 必須の初期化フロー

すべてのページスクリプト（`index.php` や `view.php`）は、以下の手順で初期化されなければなりません。

1. **設定ファイルの読み込み**: `require_once('../../config.php');`
    
2. **パラメータ取得**: `required_param` / `optional_param`
    
3. **ログイン確認**: `require_login()`
    
4. **コンテキスト取得**: `context_course::instance()` や `context_module::instance()`
    
5. **権限確認**: `require_capability()`
    

**【悪いコード例】セキュリティチェックの欠如**

PHP

```
require_once('../../config.php');
$id = required_param('id', PARAM_INT);

// BAD: ログインチェックがない。ゲストや未ログインユーザーもアクセス可能。
// BAD: コースへのアクセス権限（エンロール状況など）をチェックしていない。
// BAD: 特定の権限チェックがない。

$data = $DB->get_record('local_mydata', ['id' => $id]);
echo $data->secret_content;
```

**【良いコード例】堅牢なアクセス制御**

PHP

```
require_once('../../config.php');
$id = required_param('id', PARAM_INT); // コースID

// コースの存在確認
$course = $DB->get_record('course', ['id' => $id], '*', MUST_EXIST);

// 1. 基本的なログインとコースアクセス権（エンロール）の確認
require_login($course);

// 2. コンテキストの特定
$context = context_course::instance($course->id);

// 3. 具体的な操作権限の確認
// capabilityは db/access.php で定義されている必要がある
require_capability('local/myplugin:viewsecret', $context);

// 4. ページ設定（ログ出力やナビゲーションに影響）
$PAGE->set_url('/local/myplugin/index.php', ['id' => $id]);
$PAGE->set_context($context);
$PAGE->set_title($course->fullname);

// 出力開始
echo $OUTPUT->header();
//...
```

_参照ドキュメント_: [Access API](https://moodledev.io/docs/5.0/apis/subsystems/access)

---

## 4. コーディング規約 (Frankenstyle) と品質保証

Moodle開発コミュニティは、大規模なコードベースの一貫性を保つため、非常に厳格なコーディング規約を持っています。これを「Frankenstyle」と呼びます。Frankenstyleは、プラグイン名、クラス名、CSSクラス、関数名など、あらゆる識別子の命名規則を支配します 。

### 4.1 Frankenstyle 命名規則

Moodleのプラグイン名は「プラグインタイプ」と「プラグイン名」の組み合わせで構成されます。この命名規則は、グローバル空間での名前の衝突を防ぐために絶対的なルールとして機能します。

- **基本フォーマット**: `[plugintype]_[pluginname]`
    
- **例**:
    
    - Activity Module (mod) + Quiz = `mod_quiz`
        
    - Block (block) + Course Overview = `block_course_overview`
        
    - Local (local) + My Tool = `local_mytool`
        

#### 4.1.1 識別子のルール

|**対象**|**ルール**|**例**|**備考**|
|---|---|---|---|
|**クラス名**|名前空間を使用|`\mod_quiz\output\renderer`|`classes/output/renderer.php` に配置|
|**関数名**|Frankenstyleプレフィックス|`local_mytool_cron()`|`lib.php` 内の関数に必須|
|**定数**|大文字プレフィックス|`LOCAL_MYTOOL_MAX_ITEMS`|グローバル定数の場合|
|**DBテーブル**|プレフィックス除外|`mytool_log`|`{mytool_log}` として参照 (mdl_local_mytool_logとはしない例外あり)|
|**言語文字列**|コンポーネント名|`$string['pluginname']`|`lang/en/local_mytool.php`|

**【悪いコード例】一般的なPHPの命名**

PHP

```
// 名前空間なし、プレフィックスなし
class ReportGenerator {... }

// 一般的な関数名
function get_data() {... }

define('DEBUG_MODE', 1);
```

_解説_: これらはMoodleのコアや他のプラグインと衝突する可能性が極めて高く、致命的なエラーを引き起こします。

**【良いコード例】Frankenstyle準拠**

PHP

```
namespace local_mytool;

class report_generator {... } // local/mytool/classes/report_generator.php

function local_mytool_get_data() {... } // lib.php内であれば

define('LOCAL_MYTOOL_DEBUG_MODE', 1);
```

### 4.2 Output API と Mustacheテンプレート

Moodle 4.x では、HTMLをPHPコード内で直接生成すること（`echo` や文字連結）は強く非推奨とされています。代わりに、**Output API** と **Mustacheテンプレート** を使用して、ロジックとプレゼンテーションを分離します 。

#### 4.2.1 Templatable インターフェース

表示用データを提供するクラスは `renderable` および `templatable` インターフェースを実装する必要があります。

**実装ステップ**:

1. **クラス定義**: `export_for_template` メソッドを実装し、テンプレートに渡すデータ構造（コンテキスト）を返します。
    
2. **テンプレート作成**: `templates/` ディレクトリに `.mustache` ファイルを作成します。
    
3. **レンダリング**: `$OUTPUT->render_from_template()` を呼び出します。
    

**【良いコード例】Templatableクラスの実装**

_ファイル: `local/myplugin/classes/output/dashboard_card.php`_

PHP

```
namespace local_myplugin\output;

use renderable;
use templatable;
use renderer_base;
use stdClass;

class dashboard_card implements renderable, templatable {
    /** @var string タイトル */
    protected $title;
    /** @var int スコア */
    protected $score;

    public function __construct(string $title, int $score) {
        $this->title = $title;
        $this->score = $score;
    }

    /**
     * テンプレート用のデータをエクスポートする
     */
    public function export_for_template(renderer_base $output): stdClass {
        $data = new stdClass();
        $data->title = $this->title;
        $data->score = $this->score;
        // ロジックによる表示切り替えフラグ
        $data->is_passing = ($this->score >= 80);
        
        // 言語文字列の取得はテンプレート内で行うか、ここで解決するか選択可能
        // テンプレートヘルパー {{#str}} の利用が推奨される
        return $data;
    }
}
```

_ファイル: `local/myplugin/templates/dashboard_card.mustache`_

HTML

```
<div class="dashboard-card">
    <h3>{{title}}</h3>
    <div class="score-display">
        {{#str}} score, local_myplugin {{/str}}: {{score}}
    </div>
    
    {{#is_passing}}
        <span class="badge badge-success">{{#str}} passed, local_myplugin {{/str}}</span>
    {{/is_passing}}
    {{^is_passing}}
        <span class="badge badge-warning">{{#str}} failed, local_myplugin {{/str}}</span>
    {{/is_passing}}
</div>
```

_呼び出し側 (例: `index.php`)_

PHP

```
$card = new \local_myplugin\output\dashboard_card('Final Exam', 85);
echo $OUTPUT->render_from_template('local_myplugin/dashboard_card', $card->export_for_template($OUTPUT));
```

_参照ドキュメント_:([https://moodledev.io/docs/4.5/guides/templates](https://moodledev.io/docs/4.5/guides/templates))

### 4.3 コード品質チェックツール

Frankenstyleへの準拠を目視で確認するのは不可能です。Moodle開発では、以下のCIツールの導入が必須です。

1. **CodeChecker (`local_codechecker`)**:
    
    - Moodle専用の PHP_CodeSniffer ルールセット。
        
    - 命名規則、インデント、DocBlockの不足などを自動検出します 。
        
2. **Moodle Plugin CI**:
    
    - GitHub Actionsなどで実行される自動テストスイート。
        
    - PHPUnit（単体テスト）とBehat（振る舞い駆動テスト）を含みます。
        
3. **ESLint / Stylelint**:
    
    - JavaScript (AMD/ES Modules) と SCSS の品質管理に使用されます。
        

---

## 5. Moodle 4.x におけるナビゲーション拡張の深層

Moodle 4.0でのナビゲーション刷新は、プラグイン開発者にとって最大の変更点の一つです。「Boost」テーマにおけるフラットナビゲーションは廃止され、プライマリ（上部）とセカンダリ（コースヘッダー下部）のナビゲーション構造に移行しました 。

### 5.1 `extend_navigation` コールバックの実装

プラグインからメニューを追加する場合、従来のように任意の場所にノードを挿入することは難しくなりました。特にコースコンテキストでは、`_extend_navigation_course` コールバックを使用して、セカンダリメニューの「その他（More）」ドロップダウン等にリンクを追加するのが標準的な手法です 。

**【良いコード例】コースの「その他」メニューへのリンク追加**

_ファイル: `local/myplugin/lib.php`_

PHP

```
/**
 * Add link to course secondary navigation.
 *
 * @param navigation_node $parentnode
 * @param stdClass $course
 * @param context_course $context
 */
function local_myplugin_extend_navigation_course($parentnode, $course, $context) {
    // 権限チェック：閲覧権限がないユーザーにはリンクを表示しない
    if (!has_capability('local/myplugin:view', $context)) {
        return;
    }

    // URL定義
    $url = new moodle_url('/local/myplugin/index.php', ['id' => $course->id]);

    // ノード作成
    $node = navigation_node::create(
        get_string('pluginname', 'local_myplugin'), // 表示ラベル
        $url,
        navigation_node::TYPE_SETTING,
        null,
        'local_myplugin_node', // ユニークな識別子
        new pix_icon('i/report', '') // アイコン
    );

    // 親ノードに追加
    // Moodle 4.0 Boostテーマでは、これにより自動的にセカンダリメニュー（またはMoreメニュー）に配置される
    $parentnode->add_node($node);
}
```

_解説_: `navigation_node::TYPE_SETTING` を指定することで、Moodleのナビゲーションエンジンが適切な位置（通常はコース設定やツールに関連するエリア）に配置します。

---

## 6. まとめ：Moodle 4.x 開発のロードマップ

Moodle 4.x ベースのLMS開発プロジェクトにおいて、シニア・ソリューションアーキテクトが遵守・指導すべき重要事項は以下の通りです。

1. **構造の近代化**: `lib.php` への依存を排除し、名前空間付きのクラス設計（`classes/`）を徹底すること。
    
2. **UXとの調和**: Blockプラグインへの依存を減らし、LocalプラグインとLTI、あるいはコースモジュールとしての実装を優先すること。
    
3. **セキュリティ・ファースト**: `$DB` APIによるSQLインジェクション対策、Access APIによる厳密な権限管理、Output APIによるXSS対策をコードレビューの最重要項目とすること。
    
4. **標準への準拠**: Frankenstyle命名規則とMustacheテンプレートの利用を強制し、CodeCheckerによる自動化された品質管理を導入すること。
    

これらの指針に従うことで、Moodle 4.x の新機能を最大限に活用しつつ、将来のバージョンアップ（Moodle 5.0等）にも耐えうる、持続可能で高品質なLMSを構築することが可能です。

### 参照URL一覧

- [Moodle Plugin types - Local plugins](https://moodledev.io/docs/5.0/apis/plugintypes/local)
    
- [Moodle Automatic class loading](https://docs.moodle.org/dev/Automatic_class_loading)
    
- (https://moodledev.io/docs/4.5/apis/core/dml)
    
- [Moodle Access API](https://moodledev.io/docs/5.0/apis/subsystems/access)
    
- ([https://moodledev.io/docs/4.5/guides/templates](https://moodledev.io/docs/4.5/guides/templates))
    
- [Moodle Coding style - Frankenstyle](https://moodledev.io/general/development/policies/codingstyle/frankenstyle)