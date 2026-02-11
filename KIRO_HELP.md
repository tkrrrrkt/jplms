# Kiro Spec-Driven Development ヘルプ

Kiro-style Spec Driven Development (SDD) のコマンドリファレンスです。

## 目次

- [概要](#概要)
- [ワークフロー](#ワークフロー)
- [コマンド一覧](#コマンド一覧)
  - [Phase 0: Steering（プロジェクト設定）](#phase-0-steeringプロジェクト設定)
  - [Phase 1: Specification（仕様定義）](#phase-1-specification仕様定義)
  - [Phase 2: Implementation（実装）](#phase-2-implementation実装)
  - [Status & Validation（ステータス確認・検証）](#status--validationステータス確認検証)
- [よくある質問](#よくある質問)

---

## 概要

Kiro SDDは、AI-DLC（AI Development Life Cycle）における仕様駆動開発の実装です。3段階の承認ワークフロー（要件 → 設計 → タスク → 実装）を通じて、体系的な開発を支援します。

### ディレクトリ構造

```
.kiro/
├── steering/          # プロジェクト全体のルールとコンテキスト
│   ├── product.md     # プロダクト情報
│   ├── tech.md        # 技術スタック
│   ├── structure.md   # プロジェクト構造
│   └── *.md           # カスタムステアリング
└── specs/             # 機能ごとの仕様
    └── <feature-name>/
        ├── spec.json      # メタデータ
        ├── requirements.md # 要件定義
        ├── design.md      # 技術設計
        ├── tasks.md       # 実装タスク
        └── research.md    # 調査ログ（オプション）
```

### 基本原則

- **段階的承認**: 各フェーズで人間のレビューが必要（`-y`フラグで自動承認可能）
- **仕様駆動**: 要件 → 設計 → タスク → 実装の順序を厳守
- **プロジェクトメモリ**: `.kiro/steering/`がプロジェクト全体の知識として機能

---

## ワークフロー

### 最小ワークフロー

```
Phase 0 (オプション): プロジェクト設定
  ├─ /kiro:steering              # ステアリング生成/更新
  └─ /kiro:steering-custom       # カスタムステアリング作成

Phase 1: 仕様定義
  ├─ /kiro:spec-init "説明"      # 仕様の初期化
  ├─ /kiro:spec-requirements <feature>  # 要件定義
  ├─ /kiro:validate-gap <feature>      # ギャップ分析（オプション）
  ├─ /kiro:spec-design <feature> [-y]  # 技術設計
  ├─ /kiro:validate-design <feature>   # 設計レビュー（オプション）
  └─ /kiro:spec-tasks <feature> [-y]   # 実装タスク生成

Phase 2: 実装
  ├─ /kiro:spec-impl <feature> [tasks]  # 実装実行
  └─ /kiro:validate-impl <feature>       # 実装検証（オプション）

ステータス確認（いつでも使用可能）
  └─ /kiro:spec-status <feature>  # 進捗確認
```

---

## コマンド一覧

### Phase 0: Steering（プロジェクト設定）

#### `/kiro:steering`

プロジェクト全体のステアリング（プロジェクトメモリ）を管理します。

**機能**:
- **Bootstrap Mode**: `.kiro/steering/`が空またはコアファイル（product.md, tech.md, structure.md）が不足している場合、コードベースから自動生成
- **Sync Mode**: 既存のステアリングをコードベースと同期し、ドリフトを検出

**使用例**:
```
/kiro:steering
```

---

#### `/kiro:steering-custom`

ドメイン固有のカスタムステアリングドキュメントを作成します。

**利用可能なテンプレート**:
- `api-standards.md` - REST/GraphQL規約、エラーハンドリング
- `testing.md` - テスト組織、モック、カバレッジ
- `security.md` - 認証パターン、入力検証、シークレット
- `database.md` - スキーマ設計、マイグレーション、クエリパターン
- `error-handling.md` - エラータイプ、ロギング、リトライ戦略
- `authentication.md` - 認証フロー、権限、セッション管理

**使用例**:
```
/kiro:steering-custom
```

---

### Phase 1: Specification（仕様定義）

#### `/kiro:spec-init "プロジェクト説明"`

新しい仕様を初期化します。

**使用例**:
```
/kiro:spec-init "コース管理機能の実装"
```

---

#### `/kiro:spec-requirements <feature-name>`

要件定義ドキュメントを生成します。

**使用例**:
```
/kiro:spec-requirements course-management
```

---

#### `/kiro:validate-gap <feature-name>`

既存コードベースと要件の間の実装ギャップを分析します（オプション）。

---

#### `/kiro:spec-design <feature-name> [-y]`

技術設計ドキュメントを生成します。

**使用例**:
```
/kiro:spec-design course-management
/kiro:spec-design course-management -y  # 要件を自動承認して続行
```

---

#### `/kiro:validate-design <feature-name>`

技術設計の品質レビューと検証を実行します（オプション）。

---

#### `/kiro:spec-tasks <feature-name> [-y] [--sequential]`

実装タスクを生成します。

**使用例**:
```
/kiro:spec-tasks course-management
/kiro:spec-tasks course-management -y --sequential
```

---

### Phase 2: Implementation（実装）

#### `/kiro:spec-impl <feature-name> [task-numbers]`

TDD手法を使用して実装タスクを実行します。

**使用例**:
```
/kiro:spec-impl course-management 1.1       # 単一タスク
/kiro:spec-impl course-management 1.1,1.2   # 複数タスク
/kiro:spec-impl course-management            # すべての保留タスク（非推奨）
```

---

#### `/kiro:validate-impl [feature-name] [task-numbers]`

実装が要件、設計、タスクに整合していることを検証します（オプション）。

---

### Status & Validation（ステータス確認・検証）

#### `/kiro:spec-status <feature-name>`

仕様のステータスと進捗を表示します。

**使用例**:
```
/kiro:spec-status course-management
```

---

## よくある質問

### Q: `-y`フラグはいつ使用すべきですか？
A: 意図的な高速化のために使用します。通常は各フェーズで人間のレビューが必要です。

### Q: 既存のコードベースで作業する場合、どのコマンドから始めますか？
A: `/kiro:validate-gap`を要件定義後に実行することを推奨します。

### Q: 実装中にコンテキストをクリアする必要があるのはなぜですか？
A: コンテキストの肥大化を防ぎ、各タスクに適切に焦点を当てるためです。

### Q: ステアリングと仕様の違いは何ですか？
A: **Steering** はプロジェクト全体のルール。**Specs** は個々の機能の開発プロセスを形式化します。

---

## 関連リソース

- **プロジェクト設定**: `.kiro/steering/`
- **仕様**: `.kiro/specs/<feature-name>/`
- **ステータス確認**: `/kiro:spec-status <feature-name>`
