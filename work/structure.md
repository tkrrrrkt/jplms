# Project Structure & Architecture

## 1. Directory Map

Standard Moodle 4.x structure with isolated custom developments.

```
moodle_root/
├── config.php                 # [Config] Database & Site definition
├── theme/
│   ├── lambda/                # [Vendor] Parent Theme (DO NOT EDIT)
│   └── lambda_child/          # [Custom] Child Theme (CSS/SCSS, Layouts)
├── local/
│   └── timetrack/             # [Custom] 420-Hour Tracking & Anti-fraud Logic
│       ├── db/                # DB Schema (install.xml), Events
│       ├── lang/              # UI Strings (en, ja, zh_cn)
│       ├── classes/           # Logic Classes (Observer, Aggregator)
│       ├── amd/src/           # AMD JS Modules (activity_tracker, vimeo_tracker)
│       ├── templates/         # Mustache Templates
│       ├── version.php        # Plugin Meta
│       └── lib.php            # Moodle Hooks
├── .kiro/
│   ├── steering/              # [Meta] Project Context (This file location)
│   └── specs/                 # [SSoT] Specification Documents
└── CLAUDE.md                  # [Meta] AI Agent Rules
```

## 2. Custom Plugin Responsibilities

### `local_timetrack`

- **目的:** 420時間学習要件の厳密な記録と13層不正防止。

- **機能:**

    - フロントエンドでのHeartbeat送信（30秒間隔、Page Visibility + BroadcastChannel + Vimeo SDK統合）。

    - 4テーブルDB設計（heartbeat/daily/total/video）への記録。

    - 3段階データパイプライン（raw INSERT → Cron集計 → 日次/累計サマリ）。

    - 管理者向けレポート画面・監査証跡の提供。

    - 不正検知（アイドル検知、複数タブ排除、早送り防止、HMAC検証、ボット検知）。

### Stripe決済（段階的アプローチ）

- **MVP (Phase 1):** `paygw_stripe` + `enrol_fee` 標準プラグイン（コード不要）。

- **Phase 2:** Custom Webhook方式（Stripe Checkout → `checkout.session.completed` → Moodle API）。
        

### `theme_lambda_child`

- **目的:** ブランドイメージの確立と多言語UIの最適化。
    
- **機能:**
    
    - LambdaテーマのCSSオーバーライド（フォント、配色）。
        
    - ヘッダー/フッターへのカスタムHTML追加（言語切り替えボタン等）。