# Moodle 4.x × Stripe決済：コース自動登録の最適解

**`paygw_stripe` + コアの `enrol_fee` を組み合わせるのが最も堅実かつ将来性の高い実装パターンである。** Moodle 3.11で導入されたPayment APIにより、決済ゲートウェイと登録処理が分離設計され、Stripeでの決済完了後にStudentロールでの即時コース登録が標準機能として実現できる。カスタム開発は原則不要だが、要件によってはWebhook連携の独自実装も選択肢に入る。日本市場向けにはJCB対応・インボイス制度・特定商取引法への対応が必須となる。

---

## Payment APIのアーキテクチャが鍵を握る

Moodle 3.11（2021年5月）で導入された**Payment API**は、決済処理と登録処理を明確に分離する設計思想に基づいている。旧来の `enrol_paypal` のように決済と登録を一体化するモノリシックな設計から脱却し、**決済ゲートウェイプラグイン（`paygw_*`）** と**登録プラグイン（`enrol_*`）** を疎結合に連携させる。

この仕組みの中核は `service_provider` インターフェースにある。登録プラグインは `get_payable()` で価格・通貨・決済アカウントを返し、決済成功時に `deliver_order()` が呼ばれてユーザーをコースに登録する。具体的なデータフローは以下の通りである。

```
[ユーザー] → enrol_fee「受講料を支払う」ボタンをクリック
    ↓
[core_payment] ゲートウェイ選択モーダル表示
    ↓
[paygw_stripe] Stripe Checkout（ホスト型決済ページ）へリダイレクト
    ↓
[Stripe] 決済処理（JCB / Visa / Mastercard / 3Dセキュア対応）
    ↓
[paygw_stripe] process.php コールバック + Webhook で決済確認
    ↓
[core_payment helper] → enrol_fee::deliver_order() 呼び出し
    ↓
[enrol_fee] Studentロール（roleid=5）でコースに即時登録
    ↓
[ユーザー] コースページへリダイレクト（受講開始）
```

**コアに同梱されるのは `paygw_paypal` のみ**であり、Stripe連携にはサードパーティプラグインの導入が必要となる。

---

## 主要プラグイン3パターンの比較と推奨

Stripe連携を実現するプラグインは複数存在するが、実運用に耐えるのは3つのパターンに絞られる。

### パターン1：`paygw_stripe` + `enrol_fee`（推奨）

Alex Morris氏（Catalyst IT所属）が開発・保守する **`paygw_stripe`** は、Moodle Payment APIに準拠した正統派のStripeゲートウェイプラグインである。最新版v1.30（2025年9月リリース）は**Moodle 4.1〜5.1に対応**し、安定版（Stable）としてリリースされている。

|項目|詳細|
|---|---|
|GitHub|`alexmorrisnz/moodle-paygw_stripe`（★9 / Fork 17 / Commits 135）|
|登録サイト数|128サイト|
|対応通貨|**106通貨以上**|
|決済方式|**Stripe Checkout（ホスト型）** — PCI DSS準拠が容易|
|主要機能|サブスクリプション、クーポン/プロモコード、Stripe Tax自動税計算、Webhook自動管理|
|対応決済手段|クレジットカード（JCB含む）、Alipay、Sofort、TWINT、Bancontact等|
|ライセンス|GPL v3+|

`enrol_fee`はMoodleコアに組み込まれた「受講料を支払って登録」プラグインで、Payment APIに対応する任意のゲートウェイと連携する。**この組み合わせが、追加開発なしでStripe決済→自動登録を実現する最もシンプルで堅実なパターンである。**

既知の注意点として、Webhook関連のエラー（「No such webhook endpoint」）が報告されており、`paygw_stripe_webhooks` テーブルの該当行を削除して再生成する対処が必要になる場合がある。またMoodle 4.4環境で決済は成功するが登録に失敗する403エラーの報告もある。

### パターン2：`paygw_stripe` + `enrol_gwpayments`（拡張要件向け）

Sebsoft BV開発の **`enrol_gwpayments`**（165サイト導入）は、`enrol_fee`の上位互換として**Moodle内でクーポン管理・コホート制限・アクティビティ単位の課金**を実現する。Payment APIに準拠するため `paygw_stripe` とシームレスに連携できる。Moodleのクーポン機能をStripe Dashboardに依存せず管理したい場合に有効な選択肢である。

### パターン3：`enrol_stripepayment`（レガシー・非推奨）

DualCube開発の `enrol_stripepayment` は **1,369サイト** と最大の導入実績を持つが、**Payment APIを使わない独自実装**である点がアーキテクチャ上の弱点である。サイト全体のH2要素を非表示にするCSS汚染バグ、Moodle 4.3.5+でのクラッシュが報告されている。サブスクリプション機能は有料の「Stripe Pro」アップグレードが必要。Catalyst IT（`paygw_stripe`メンテナの所属企業）のスタッフも、Moodle 3.10以降では `paygw_stripe` への移行を推奨している。**新規構築では選択すべきでない。**

---

## カスタム実装が必要になるケース

`paygw_stripe` + `enrol_fee` で要件の大半はカバーできるが、以下のケースではカスタム開発が合理的となる。

- 既存の外部ECサイトやLPからの決済導線が必要
- 複数コースの一括購入（ショッピングカート機能）
- Moodle外の会員管理システムとの連携
- 独自の領収書・請求書フォーマットの自動生成

### 推奨されるカスタム実装のデータフロー

```
[外部サイト/Moodleカスタムページ]
    │
    ├─ ① Stripe Checkout Session作成
    │    metadata: { moodle_userid, courseid, roleid }
    │    success_url: https://moodle.example.com/local/stripehook/success.php
    │
    ├─ ② ユーザー → Stripe Checkout（決済）
    │
    ├─ ③ Stripe → Webhook POST: checkout.session.completed
    │    送信先: https://moodle.example.com/local/stripehook/webhook.php
    │
    └─ ④ webhook.php 内部処理:
         ├─ Stripe署名検証（HMAC-SHA256）
         ├─ 冪等性チェック（event.id をDBで重複確認）
         ├─ metadataからuserid/courseidを取得
         ├─ Moodle内部APIで即時登録:
         │    $enrol = $DB->get_record('enrol', 
         │        ['courseid' => $courseid, 'enrol' => 'manual']);
         │    $plugin = enrol_get_plugin('manual');
         │    $plugin->enrol_user($enrol, $userid, $roleid);
         └─ HTTP 200を即座に返却
```

**ローカルプラグイン方式（`local/stripehook/`）が推奨される。** Moodle内部の登録APIを直接呼び出せるため、Web Service API経由よりもシンプルかつ安全である。Moodleフォーラムでも「プラグイン内ではWeb Servicesは不要、3行のコードで登録できる」と確認されている。

外部サーバーからWeb Service APIを使う場合は、`enrol_manual_enrol_users` 関数を REST プロトコルで呼び出す。この際、**Web Serviceユーザーにシステムレベルで `moodle/course:view` 権限を付与しないと `requireloginerror` が発生する**という落とし穴がある。

### セキュリティ実装の必須チェックリスト

- **Webhook署名検証**：`Stripe\Webhook::constructEvent()` で HMAC-SHA256 を検証。生のリクエストボディ（`php://input`）を使用し、フレームワークによるパース前に処理すること
- **冪等性の確保**：`event.id` または `checkout_session.id` をDBテーブルに記録し、重複処理を防止。Stripeは同一イベントを複数回配信する可能性がある
- **タイムスタンプ検証**：デフォルト300秒（5分）の許容範囲でリプレイ攻撃を防止
- **即時レスポンス**：HTTP 200をすぐに返却し、Stripeのリトライ（最大3日間、指数バックオフ）を回避
- **シークレット管理**：APIキー・Webhookシークレットをコードに埋め込まず、環境変数または `config.php` で管理
- **HTTPS必須**：本番環境のWebhookエンドポイントはSSL/TLS必須
- **CSRF不要**：Webhook はサーバー間通信のため `sesskey` 検証は不要。代わりにStripe署名で真正性を担保

---

## 日本国内での利用に必須の3つの対応

### JCBカード：追加設定不要で即時利用可能

**日本に所在するStripeアカウントでは、JCBカードは有効化直後から自動的に利用可能**である。Visa・Mastercardと同様にデフォルトで有効化されており、追加審査や設定は不要。Stripe Checkoutを使用する場合、JCBは自動的に対応決済手段として表示される。JCBは国内で**1億3,500万枚以上**発行されており、日本市場では対応必須の決済手段である。また、経済産業省が義務化した **3Dセキュア2.0**（EMV 3-D Secure）もStripe Checkoutが自動的に処理する。

### インボイス制度（適格請求書等保存方式）への対応

2023年10月に施行された**適格請求書等保存方式**（いわゆるインボイス制度）に対応するには、以下の手順が必要である。

まず、税務署に**適格請求書発行事業者**として登録し、「T＋13桁」の登録番号を取得する。次に、Stripe Dashboardの設定画面で事業者番号を登録する。設定 → カスタマーメール → 「支払い成功時」のメール送信を有効にすることで、登録番号を含む受領書が顧客に自動送信される。

**B2B取引で正式な適格請求書が必要な場合**は、Stripe Invoicing機能の利用を検討する。Stripe Invoicingは適格請求書の必須6項目（発行事業者名・登録番号・取引日・商品/サービスの内容・税率ごとの金額・買い手の名前）をカバーできる。なお、2029年9月までの経過措置期間中は、未登録事業者からの仕入れでも部分的な仕入税額控除が認められる（2026年9月まで80%、2029年9月まで50%）。

### 特定商取引法に基づく表記

オンラインコースの販売は**通信販売**に該当し、特定商取引法の表示義務が適用される。違反した場合は**100万円以下の罰金**および業務停止命令の対象となる。

**Moodleサイトでの実装方法として、専用の固定ページを作成しサイトフッターからリンクする**のが日本のEC慣習に沿った標準的な配置である。Moodleのカスタムページ機能または静的ページプラグインで「特定商取引法に基づく表記」ページを作成し、全ページのフッターに常時リンクを表示する。加えて、決済直前の最終確認画面からもリンクを設置すべきである。

必須表示項目には、販売業者名（法人名または個人の本名）、所在地、電話番号、代表者氏名、販売価格（税込）、支払方法・時期、商品引渡時期、返品・キャンセルポリシーが含まれる。特に**返品特約は省略不可**であり、デジタルコンテンツであっても明示が求められる。

なお、オンライン語学講座や学習塾に該当するコースで**2ヶ月超かつ5万円超**の場合は「特定継続的役務提供」に分類され、概要書面・契約書面の交付義務と**8日間のクーリングオフ期間**が追加で適用される。2023年6月からは書面の電子交付も認められている。

---

## 結論：新規構築での最適解と実装ステップ

新規のMoodle 4.x環境でStripe決済とコース自動登録を実現するには、**`paygw_stripe`（v1.30）+ コア `enrol_fee`** の組み合わせが最適解である。この選択はMoodle公式のPayment APIアーキテクチャに準拠し、カスタムコード不要で要件を満たせる。クーポンやコホート制限が必要なら `enrol_gwpayments` に置き換える。

実装手順は、①Stripeアカウント開設・JCB確認・インボイス登録番号設定 → ②`paygw_stripe` プラグインのインストールと有効化 → ③Moodle管理画面で決済アカウント作成・Stripe APIキー設定 → ④対象コースに「受講料を支払って登録」を追加し価格設定 → ⑤特定商取引法表記ページ作成・フッターリンク設置 → ⑥テスト環境でStripeテストモードによる決済→登録の動作確認、となる。

カスタム開発は既存ECサイトとの統合や独自の領収書生成が必要な場合に限定し、その場合もWebhook署名検証と冪等性の確保を必ず実装する。**決済プラットフォームの選択よりも、日本固有の法的要件（特定商取引法表記・インボイス制度・3Dセキュア義務化）への対応漏れが実務上のリスクとなりやすい**ことを念頭に置くべきである。