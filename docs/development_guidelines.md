# 開発ガイドライン (Development Guidelines)

本プロジェクトは、生成AI（Claude Code / Cursor）を活用した「仕様駆動開発（SDD）」を採用します。

本ドキュメントは、MoodleベースのLMS構築における開発標準、セキュリティ基準、およびワークフローを定義します。

## 1. 開発ワークフロー (SDD Workflow)

本プロジェクトでは **「Spec-Code-Verify」** ループを回します。いきなり実装コードを書くことは禁止です。

1. **仕様策定 (Spec):**
    
    - `.kiro/specs/` ディレクトリにMarkdown形式で仕様書を作成・更新する。
        
    - **SSoT (Single Source of Truth):** 実装中に迷ったら必ず仕様書に戻る。仕様書にない機能は実装しない。
        
2. **インターフェース定義 (Type/Interface):**
    
    - ロジックを書く前に、ディレクトリ構造、`db/install.xml`、空のクラスファイル、`version.php`を作成する。
        
3. **実装 (Code):**
    
    - `claude` コマンドを使用し、仕様書に基づいたコードを生成させる。
        
4. **検証 (Verify):**
    
    - 実装を確認し、不備があれば「コードを直す」のではなく「仕様書を修正」して再生成する。
        

## 2. ディレクトリ構成と責務

Moodle標準のディレクトリ汚染を防ぐため、独自コードは以下の場所に限定します。

```
moodle_root/
├── theme/
│   └── lambda/            # 親テーマ（購入品・編集不可）
│   └── lambda_child/      # [Dev] デザインカスタマイズ（CSS/SCSS, Mustache）
├── local/
│   └── timetrack/         # [Dev] 420時間計測・不正防止・進捗管理ロジック
├── .kiro/
│   └── specs/             # [Doc] 仕様書格納ディレクトリ（SSoT）
│       ├── 01_system_architecture.md  # 全体アーキテクチャ
│       └── ...
└── CLAUDE.md              # [Conf] プロジェクト設定・AIルール
```

## 3. コーディング規約 (Moodle Best Practices)

Moodleの標準規約 (Frankenstyle) に準拠し、セキュリティと保守性を担保します。

### 3.1 命名規則

- **プラグイン名:** `local_pluginname` (全て小文字、アンダースコア区切り)
    
- **クラス名:** `local_pluginname\classname` (オートローディング対応)
    
- **関数名:** `local_pluginname_functionname` (グローバル関数の場合)
    
- **変数名:** `$snake_case` (キャメルケース禁止)
    

### 3.2 データベース操作 (Security)

- **グローバルオブジェクト:** `global $DB;` を使用する。
    
- **SQLインジェクション対策:** 必ずプレースホルダを使用する。
    
    - ❌ `WHERE id = $id`
        
    - ⭕ `WHERE id = :id`, `['id' => $id]`
        
- **推奨メソッド:**
    
    - `$DB->get_record('table', ['id' => 1])`
        
    - `$DB->get_records('table', ['course' => 2])`
        
    - `$DB->insert_record('table', $dataobject)`
        
    - `$DB->update_record('table', $dataobject)`
        

### 3.3 入力処理とセキュリティ

- **パラメータ取得:** `$_GET`, `$_POST` は**厳禁**。必ず以下の関数を使う。
    
    - `required_param($name, PARAM_INT)`: 必須パラメータ（型指定必須）
        
    - `optional_param($name, $default, PARAM_TEXT)`: 任意パラメータ
        
- **必須チェック:** ページの先頭で必ず実行する。
    
    - `require_login()`: ログイン必須
        
    - `require_login($course)`: コースアクセス権確認
        
    - `require_sesskey()`: POST送信時のCSRF対策（フォーム処理時）
        

### 3.4 権限チェック (Capabilities)

- MoodleのRoleシステムを利用する。ハードコードで `if ($user->id == 1)` のような特権判定をしてはいけない。
    
- `has_capability('local/plugin:view', $context)` を使用して分岐する。
    

### 3.5 多言語対応

- 文字列のハードコードは禁止。
    
- `get_string('string_id', 'local_pluginname')` を使用する。
    
- 言語ファイル:
    
    - `lang/en/local_pluginname.php`: 英語（ベース）
        
    - `lang/ja/local_pluginname.php`: 日本語
        

## 4. バージョン管理とGit運用

- **`.gitignore` 設定:**
    
    - Moodleコアファイルはコミットしない（`config.php` を除く）。
        
    - `local/timetrack/` などの独自プラグインディレクトリのみを管理対象とする。