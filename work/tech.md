# Technology Stack & Guidelines

## 1. Core Technology

- **LMS Engine:** Moodle 4.x (Latest Stable Release)
    
    - _理由:_ 教育要件の9割を標準機能でカバーし、開発コストを抑制するため。
        
- **Language:** PHP 8.1+
    
    - _制約:_ 型宣言（Type Hinting）を可能な限り使用する。
        
- **Database:** MySQL 8.0 (or MariaDB 10.6+)
    
    - _文字コード:_ `utf8mb4_unicode_ci` (多言語対応必須)
        
- **Web Server:** Nginx
    
    - _設定:_ 動画配信ではなくLMSのレスポンス高速化にチューニング。
        

## 2. Frontend & Theme

- **Theme:** Lambda (Premium Theme)
    
    - _運用:_ 親テーマは直接編集せず、必ず `theme_lambda_child` を作成してカスタマイズする。
        
- **Stack:** Mustache Templates (Moodle Standard), jQuery (Legacy support), Bootstrap 5.
    
- **Languages:**
    
    - UI Strings: `lang/en/` (English Key) and `lang/ja/` (Japanese Display).
        
    - 中国語対応はMoodle標準言語パック + `lang/zh_cn/` で対応。
        

## 3. External Integrations

- **Payment:** Stripe API (Checkout Session mode)
    
    - _Method:_ Webhook (`checkout.session.completed`) processing via Custom Plugin.
        
- **Video:** Vimeo API / oEmbed
    
    - _Security:_ Domain-level privacy restriction enabled on Vimeo side.
        
- **Live Class:** Zoom / Google Meet (LTI or simple URL resource).
    

## 4. Development Constraints (The Commandments)

1. **NO Core Hacking:** Moodleのコアファイル（`/lib`, `/course` 等）は絶対に変更しない。
    
2. **Plugin Architecture:** 独自機能は全て `/local/` 以下のプラグインとして実装する。
    
3. **Security First:**
    
    - 生SQL禁止。必ずグローバル `$DB` オブジェクトとプレースホルダを使用する。
        
    - 入力値は必ず `required_param()` / `optional_param()` で取得し、型検証を行う。
        
    - 権限チェック (`require_login`, `require_capability`) を徹底する。
        

## 5. Coding Standards

- **Style:** Moodle Coding Style (Frankenstyle)
    
- **Doc:** PHPDoc is mandatory for all classes and functions.