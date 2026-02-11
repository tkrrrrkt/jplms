# Project Structure

## Organization Philosophy

**Plugin-First** — Moodleコアは一切変更しない。独自機能は全て `/local/` プラグインとして隔離する。テーマカスタマイズは子テーマ (`theme_lambda_child`) に限定する。

この原則により、Moodleのメジャーアップグレード時にもカスタム機能が影響を受けない。

## Directory Patterns

### Custom Plugins
**Location**: `/local/{plugin_name}/`
**Purpose**: ビジネスロジック、独自データモデル、管理画面、外部API連携
**Naming**: `local_timetrack` (Frankenstyle)
**Internal Layout**:
```
local/{plugin_name}/
├── db/
│   ├── install.xml       # DB schema definition (XMLDB)
│   ├── upgrade.php       # Schema migration
│   ├── access.php        # Capability definitions
│   └── events.php        # Event observer registrations
├── classes/              # Autoloaded PHP classes
│   ├── observer.php      # Event observers
│   └── external/         # Web service definitions (if needed)
├── lang/
│   ├── en/               # English strings (base key)
│   ├── ja/               # Japanese strings (display)
│   └── zh_cn/            # Chinese strings
├── amd/src/              # AMD JavaScript modules
├── templates/            # Mustache templates
├── version.php           # Plugin version & dependencies
├── lib.php               # Moodle hook callbacks
└── settings.php          # Admin settings page
```

### Child Theme
**Location**: `/theme/lambda_child/`
**Purpose**: CSS/SCSS overrides, layout adjustments, custom header/footer
**Rule**: Parent theme `theme/lambda/` is vendor-provided and MUST NOT be edited
**Internal Layout**:
```
theme/lambda_child/
├── config.php            # Theme config (parent: lambda)
├── scss/                 # Custom SCSS overrides
├── templates/            # Mustache template overrides
├── lang/                 # Theme-specific strings
├── pix/                  # Custom images/icons
└── version.php
```

### Specifications (CCSDD)
**Location**: `.kiro/specs/{feature-name}/`
**Purpose**: Feature-level SSoT documents (requirements, design, tasks)
**Rule**: One directory per feature. Never place files directly in `.kiro/specs/`
**Layout**:
```
.kiro/specs/{feature-name}/
├── spec.json             # Metadata & phase tracking
├── requirements.md       # EARS-format requirements
├── design.md             # Mermaid diagrams + architecture
├── tasks.md              # Implementation tasks
└── research.md           # (Optional) Design decisions
```

### 仕様書（業務仕様管理）
**Location**: `.kiro/specs/仕様書/`
**Purpose**: 業務仕様の管理台帳。機能単位のドキュメントとCCSDD specの索引。
**Rule**: 機能IDは `{カテゴリ}{連番}_{機能名}.md` 形式。機能一覧.mdを常に最新に保つ。

**カテゴリID体系**:
- `A`: マスタ管理（登録・一覧・編集）
- `B`: 学習機能（動画・テスト・課題・進捗）
- `C`: 決済・登録（Stripe・アクセス制御）
- `D`: 評価・成績（採点・合否判定）
- `E`: 証明書（修了証発行・検証）
- `F`: 管理・監査（モニタリング・ログ）

**Layout**:
```
.kiro/specs/仕様書/
├── 仕様概要.md           # システム仕様の概要（随時更新）
├── 機能一覧.md           # 全機能のマスターリスト（テーブル形式）
├── A01_コース管理.md     # 機能単位の詳細仕様
├── B01_動画視聴.md
├── B05_学習時間計測.md
├── C01_Stripe決済.md
└── ...
```

**機能一覧.mdの必須カラム**: ID / 機能名 / 概要 / 実装方式 / CCSDD Spec / Priority / Status

**CCSDD specとの連携**:
- Custom Plugin実装が必要な機能はCCSDD specで開発プロセスを管理
- 機能一覧.mdの「CCSDD Spec」列にfeature-nameを記載して相互参照
- 例: `B05_学習時間計測.md` ↔ `.kiro/specs/timetrack/`

### Project Documentation
**Location**: `docs/`
**Purpose**: Reference materials, architecture overview, development guidelines
**Note**: These are inputs for steering, NOT the SSoT for development

## Naming Conventions

- **Plugin names**: `local_pluginname` — all lowercase, underscores (Frankenstyle)
- **Class names**: `local_pluginname\classname` — namespaced, autoloaded from `classes/`
- **Global functions**: `local_pluginname_functionname()` — plugin prefix required
- **Variables**: `$snake_case` — camelCase is prohibited
- **DB tables**: `mdl_local_pluginname_tablename` — prefixed by Moodle
- **Language strings**: `get_string('string_key', 'local_pluginname')`
- **Capabilities**: `local/pluginname:action` — e.g., `local/timetrack:view`
- **Files**: `lowercase_with_underscores.php` — following Moodle standard

## Include / Require Patterns

```php
// Moodle bootstrap (required at top of every page script)
require_once(__DIR__ . '/../../config.php');

// Class autoloading (preferred over require_once for classes)
// Classes in local/timetrack/classes/ are autoloaded as:
//   local_timetrack\classname

// Library includes (only when autoloading not available)
require_once($CFG->dirroot . '/local/timetrack/lib.php');
```

## Code Organization Principles

1. **One concern per file** — Avoid monolithic classes. Split by responsibility.
2. **DB schema in install.xml** — Never create tables via raw SQL. Use XMLDB editor.
3. **Events for cross-plugin communication** — Use Moodle event system, not direct calls.
4. **Capabilities for authorization** — Define in `db/access.php`, check with `has_capability()`.
5. **Strings for all user-facing text** — Define in `lang/`, retrieve with `get_string()`.

---
_Document patterns, not file trees. New files following patterns shouldn't require updates_
