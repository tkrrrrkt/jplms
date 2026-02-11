# Moodle 4.x パフォーマンス最適化とインフラ構成ガイド

**数百名規模・Vimeo埋め込み主体のMoodle 4.xサイトを高速かつ安定的に運用するためには、PHP-FPM／OPcacheの適正チューニング、RedisによるMUCキャッシュとセッションのオフロード、1分間隔のCron確実実行、そしてInnoDB中心のDB最適化が不可欠である。** Vimeo埋め込み構成では動画配信負荷はVimeo側CDNが吸収するため、Moodleサーバーはページレンダリングとコース管理処理に集中できる。以下、各レイヤーの具体的な設定値・構成例・算出根拠を網羅する。

---

## 1. PHPバージョン互換性とMoodle 4.xの対応マトリクス

Moodle 4.x系ではPHP 8.x系への移行が段階的に進み、**Moodle 4.5 LTS（現行LTS）ではPHP 8.1が最低要件、PHP 8.2〜8.3が推奨**となっている。64-bitのPHPのみサポート（4.1以降）。

|Moodleバージョン|最低PHP|最大PHP|備考|
|---|---|---|---|
|4.0|7.3|8.0|PHP 8.0は4.0.2から|
|4.1 LTS|7.4|8.1|64-bit必須化|
|4.2|**8.0**|8.2|sodium拡張が必須化|
|4.3|8.0|8.2|DBプレフィックス10文字制限|
|4.4|**8.1**|8.3|PHP 8.3サポート導入|
|4.5 LTS|8.1|8.3|現行LTS|

新規構築では**PHP 8.2**を推奨する。8.1〜8.3をカバーする安定バージョンであり、OPcacheのデフォルト値もMoodleの推奨に合致する。PHP 8.4はMoodle 5.0以降の対応予定であり、4.x系では使用不可。

### 必須・推奨PHP拡張モジュール

Moodle 4.2以降の必須拡張は **ctype, curl, dom, fileinfo, gd, iconv, intl, json, mbstring, openssl, simplexml, sodium, xml, xmlreader, zip, zlib** とDB拡張（mysqli/pgsql）。パフォーマンスに直接寄与する追加拡張は以下の通り。

|拡張|効果|備考|
|---|---|---|
|**OPcache**|PHPバイトコードキャッシュ。本番環境で**必須**|PHP標準同梱|
|**redis**|Redis MUCストア・セッションハンドラに必要|phpredis拡張|
|**igbinary**|バイナリシリアライザ。Redisメモリ使用量**約50%削減**、ページ表示**10-30%高速化**|phpredis側でもigbinaryサポートを有効にしてビルドが必要|
|**apcu**|高速ローカルメモリキャッシュ。MUCの第1層に最適|サイズ制限あり|
|**exif**|画像メタデータ解析（Moodle 4.0から推奨）||

なお、**xmlrpc拡張はMoodle 4.1で不要**になった（MDL-76052）。PHP 8.0以降で標準バンドルからも削除されており、無視してよい。

---

## 2. Nginx + PHP-FPM の推奨設定

### pm.max_children の算出方法

`pm.max_children` はサーバー安定性の要となる設定であり、以下の計算式で決定する。

```
pm.max_children = (PHP に割当可能なRAM) ÷ (1プロセスあたりの平均メモリ使用量)
```

**実測手順：**

```bash
ps --no-headers -o "rss,cmd" -C php-fpm | awk '{sum+=$1; cnt++} END {print sum/cnt/1024 " MB/process"}'
```

**8GB RAMサーバーでの計算例：**

- OS/Nginx/Redis/MariaDB用に約2GB確保 → PHP用に**6GB**
- Moodle PHPプロセスの典型値：**80〜128MB**（平均100MB想定）
- 理論最大値：6000 ÷ 100 = 60
- 安全マージン80%適用 → **pm.max_children = 48**

### PHP-FPMプール設定（8〜16GB RAM、数百ユーザー想定）

```ini
; /etc/php/8.2/fpm/pool.d/moodle.conf
[moodle]
user = www-data
group = www-data
listen = /run/php/php8.2-fpm.sock
listen.owner = www-data
listen.group = www-data
listen.mode = 0660

pm = dynamic
pm.max_children = 48              ; RAM÷プロセスサイズで算出（上記参照）
pm.start_servers = 12             ; max_children の約25%
pm.min_spare_servers = 6          ; 最低限のアイドルワーカー
pm.max_spare_servers = 18         ; アイドルワーカー上限
pm.max_requests = 1000            ; メモリリーク防止のため定期リサイクル
pm.process_idle_timeout = 10s

; モニタリング
pm.status_path = /fpm-status
ping.path = /fpm-ping

; スロークエリログ
slowlog = /var/log/php-fpm/moodle-slow.log
request_slowlog_timeout = 5s
request_terminate_timeout = 300s

; PHP設定（プール単位で上書き）
php_admin_value[memory_limit] = 512M
php_admin_value[max_execution_time] = 300
php_admin_value[max_input_vars] = 5000
php_admin_value[upload_max_filesize] = 256M
php_admin_value[post_max_size] = 256M
```

### OPcache設定

Moodle公式ドキュメント推奨値をベースに、プラグイン多数導入を想定して拡張した設定：

```ini
; /etc/php/8.2/mods-available/opcache.ini
opcache.enable = 1
opcache.enable_cli = 1                    ; CLIクーロン高速化
opcache.memory_consumption = 256          ; プラグイン多数なら256-512MB
opcache.interned_strings_buffer = 16      ; Moodleは文字列が多いため16-32MB
opcache.max_accelerated_files = 20000     ; Moodleコアだけで数千ファイル
opcache.revalidate_freq = 60              ; 60秒ごとにタイムスタンプ確認
opcache.validate_timestamps = 1           ; デプロイ時にopcache_reset()するなら0も可
opcache.use_cwd = 1                       ; Moodle必須
opcache.save_comments = 1                 ; PHPDocアノテーション使用のため必須
opcache.enable_file_override = 0          ; Moodle公式推奨
```

**Moodle公式の最低ライン**（docs.moodle.org/en/OPcache）は `memory_consumption=128`, `max_accelerated_files=10000` だが、プラグインを多数導入する場合は上記の拡張値を推奨。`opcache_get_status()` でキャッシュヒット率とメモリ使用率を定期監視し、`cache_full` が `true` なら `memory_consumption` を増やす。

### Nginx設定

```nginx
# /etc/nginx/sites-available/moodle
upstream php-fpm {
    server unix:/run/php/php8.2-fpm.sock;
    keepalive 16;
}

server {
    listen 443 ssl http2;
    server_name moodle.example.com;

    ssl_certificate     /etc/ssl/certs/moodle.pem;
    ssl_certificate_key /etc/ssl/private/moodle.key;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_session_cache   shared:SSL:10m;

    root /var/www/moodle;
    index index.php;
    client_max_body_size 256M;

    # 静的アセットのキャッシュ（Vimeo埋め込みサイトでも重要）
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|woff|woff2|ttf|svg)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # メインルーティング
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    # PHP処理（slash arguments対応）
    location ~ [^/]\.php(/|$) {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass php-fpm;
        fastcgi_keep_conn on;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO       $fastcgi_path_info;
        fastcgi_read_timeout  300;
        fastcgi_send_timeout  300;
        fastcgi_buffer_size   128k;
        fastcgi_buffers       256 16k;
        fastcgi_busy_buffers_size 256k;
    }

    # X-Accel-Redirect（PHPからNginxへファイル配信をオフロード）
    location /dataroot/ {
        internal;
        alias /var/moodledata/;
    }

    # セキュリティ
    location ~ /\.git   { deny all; }
    location ~ /\.ht    { deny all; }
}

server {
    listen 80;
    server_name moodle.example.com;
    return 301 https://$host$request_uri;
}
```

**X-Accel-Redirect**はファイル配信をPHPプロセスからNginxに委譲する重要な最適化で、config.phpに以下を追加して有効化する：

```php
$CFG->xsendfile = 'X-Accel-Redirect';
$CFG->xsendfilealiases = array('/dataroot/' => $CFG->dataroot);
```

---

## 3. Redisキャッシュ戦略とセッションハンドリング

### MUCの3つのキャッシュ層とバックエンド選定

Moodle Universal Cache（MUC）は**Application/Session/Request**の3層構造を持つ。各層の特性と推奨バックエンドは明確に異なる。

|キャッシュ層|スコープ|推奨バックエンド|理由|
|---|---|---|---|
|**Application**|全ユーザー共有・永続|**Redis**（APCuとの二段構成が理想）|大量のキャッシュデータを高速に共有|
|**Session**|ユーザー単位・セッション存続期間|**Redis**|DBセッションの負荷軽減|
|**Request**|リクエスト単位・1リクエスト限り|**Static（PHPメモリ）**|Redis不適合。ネットワーク往復のオーバーヘッドが逆効果|

**注意：** MUCの「Session cache」とPHPセッションハンドラ（`$CFG->session_handler_class`）は別物である。前者はキャッシュデータの有効期間がセッションと連動する、後者はPHPセッションデータ自体の格納先を指す。

### Redisセッションハンドラの設定（config.php）

DBセッションからRedisに切り替えることで、セッションロック取得が**500〜2000ms → 80〜110ms**に短縮され、ページレスポンスが劇的に改善する。`mdl_sessions`テーブルへの書き込み負荷も大幅に減少する。

```php
// ===== Redisセッションハンドラ =====
$CFG->session_handler_class = '\core\session\redis';
$CFG->session_redis_host = '127.0.0.1';
$CFG->session_redis_port = 6379;
$CFG->session_redis_database = 0;
$CFG->session_redis_auth = 'your_strong_password';
$CFG->session_redis_prefix = 'mdl_sess_';
$CFG->session_redis_acquire_lock_timeout = 120;   // ロック待ち最大秒数
$CFG->session_redis_lock_expire = 7200;            // ロック有効期限
$CFG->session_redis_lock_retry = 100;              // ロック再試行間隔(ms)
$CFG->session_redis_serializer_use_igbinary = true; // igbinary推奨
$CFG->session_redis_compressor = 'zstd';           // zstd or gzip or none

// ===== リードオンリーセッション（Moodle 3.9+） =====
$CFG->enable_read_only_sessions = true;
// ※ 読み取り専用ページではセッションロック不要となり大幅高速化
```

### MUC Redisストアの設定

管理UIから設定する方法と、config.phpで強制設定する方法がある。マルチノード環境や構成管理の観点では、Catalystの**tool_forcedcache**プラグインによるconfig.php管理が推奨される。

```php
// ===== MUC強制キャッシュ設定（tool_forcedcacheプラグイン使用） =====
$CFG->alternative_cache_factory_class = 'tool_forcedcache_cache_factory';
$CFG->tool_forcedcache_config_array = [
    'stores' => [
        'APCu' => [
            'type' => 'apcu',
            'config' => ['prefix' => 'apcu_'],
        ],
        'redis' => [
            'type' => 'redis',
            'config' => [
                'server' => '127.0.0.1:6380',       // セッション用と別ポート推奨
                'prefix' => 'mdl_muc_',
                'password' => 'your_strong_password',
                'serializer' => 1,                    // 1=igbinary
                'compressor' => 2,                    // 2=zstd
            ],
        ],
        'local_file' => [
            'type' => 'file',
            'config' => ['path' => '/tmp/muc', 'autocreate' => 1],
        ],
    ],
    'rules' => [
        'application' => [
            // 頻繁アクセスの小キャッシュ → APCu+Redis二段構成
            ['conditions' => ['name' => 'core/string'],
             'stores' => ['APCu', 'redis']],
            ['conditions' => ['name' => 'core/langmenu'],
             'stores' => ['APCu', 'redis']],
            ['conditions' => ['name' => 'core/plugin_functions'],
             'stores' => ['APCu', 'redis']],
            // 巨大キャッシュ → ファイルベース（Redisメモリを圧迫させない）
            ['conditions' => ['name' => 'core/coursemodinfo'],
             'stores' => ['local_file']],
            ['conditions' => ['name' => 'core/htmlpurifier'],
             'stores' => ['local_file']],
            // デフォルト
            ['conditions' => ['canuselocalstore' => true],
             'stores' => ['local_file', 'redis']],
        ],
    ],
];
```

### Redisサーバー設定のベストプラクティス

**セッション用とMUCキャッシュ用でRedisインスタンスを分離する**ことを強く推奨する。理由は3つ：evictionポリシーが異なる、Moodleのキャッシュパージがセッションを破壊するリスクがある、メモリ監視が容易になる。

```conf
# === セッション用Redis（ポート6379） ===
maxmemory 256mb
maxmemory-policy noeviction        # セッションは絶対に追い出さない
appendonly yes                      # AOF永続化でデータ保護
appendfsync everysec
save 900 1
save 300 100

# === MUCキャッシュ用Redis（ポート6380） ===
maxmemory 512mb
maxmemory-policy allkeys-lru       # メモリ上限到達時にLRUで自動追い出し
appendonly no                       # キャッシュは再生成可能なので永続化不要
save ""
```

**メモリサイジングの目安：** セッション用は `同時接続ユーザー数 × 平均セッションサイズ(約2-5KB) × 1.2(オーバーヘッド)` で算出。数百ユーザーなら**128〜256MB**で十分。MUCキャッシュ用は`INFO memory`コマンドで`used_memory`を監視し、`evicted_keys`が増加していれば`maxmemory`を拡大する。

### APCuの位置づけ

APCuはプロセスローカルの超高速メモリキャッシュであり、Redisへのネットワーク往復すら不要な第1層キャッシュとして機能する。ただし容量が限定的（128-256MB程度）でサーバー間共有不可のため、**少量・高頻度アクセスのキャッシュ定義のみ**に適用する。

```ini
; APCu設定
apc.enabled = 1
apc.shm_size = 128M
apc.ttl = 7200
apc.enable_cli = 0
```

---

## 4. Cronタスク管理と障害対策

### 1分間隔の実行が必須である理由

Moodle公式ドキュメントは明確に「**1分ごとの実行を推奨**」と記載している。Cron停止はメール通知の遅延、コース完了判定の未処理、ゴミ箱の非同期削除の停止など、広範な機能障害を引き起こす。Moodle 4.2以降はデフォルトで**keep-alive 3分**が設定されており、cronプロセスは起動後3分間タスクをポーリングし続ける。

### crontab方式

```bash
# www-dataユーザーのcrontab
* * * * * /usr/bin/php /var/www/moodle/admin/cli/cron.php >/dev/null 2>&1

# 重複実行防止版（flock使用）
* * * * * /usr/bin/flock -n /tmp/moodle-cron.lock /usr/bin/php /var/www/moodle/admin/cli/cron.php >/dev/null 2>&1

# アドホックタスク専用ワーカーの追加（高負荷サイト向け）
* * * * * /usr/bin/php /var/www/moodle/admin/cli/adhoc_task.php --execute --keep-alive=59
```

### systemd timer方式

```ini
# /etc/systemd/system/moodle-cron.service
[Unit]
Description=Moodle Cron Job
After=network.target mariadb.service

[Service]
Type=oneshot
User=www-data
ExecStart=/usr/bin/php /var/www/moodle/admin/cli/cron.php
TimeoutStartSec=600
StandardOutput=null
StandardError=journal
```

```ini
# /etc/systemd/system/moodle-cron.timer
[Unit]
Description=Run Moodle cron every minute

[Timer]
OnCalendar=*:0/1
AccuracySec=1s
Persistent=true

[Install]
WantedBy=timers.target
```

**systemd timerの優位点：** `Type=oneshot`による重複実行防止が組み込み、`journalctl`との統合ログ、`Persistent=true`による未実行分の自動キャッチアップ、`CPUQuota`/`MemoryMax`によるリソース制御が可能。crontabはシンプルだが、これらの機能をすべて手動で実装する必要がある。

### Cronロック問題の診断と解消

Cronロックはプロセス強制終了（OOM killer、サーバー再起動）やNFS環境でのファイルロック不整合で発生する。

```bash
# ファイルロックのクリア
rm -rf /path/to/moodledata/lock/*

# DBロックのクリア
mysql -e "TRUNCATE TABLE mdl_lock_db;" moodle

# ロックファクトリをDB方式に変更（NFS環境で推奨）
# config.php に追加：
$CFG->lock_factory = "\\core\\lock\\db_record_lock_factory";
```

監視には **Site Admin → Server → Scheduled task log** でFailDelayが増加しているタスクを確認するほか、Catalyst社の**tool_lockstats**プラグインでリアルタイム監視が可能。

---

## 5. データベース最適化

### MariaDB/MySQL推奨設定（8〜16GB RAM想定）

```ini
[mysqld]
# === 文字セット（Moodle 4.x必須） ===
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

# === InnoDB（最重要） ===
innodb_buffer_pool_size = 4G         # 専用DBサーバー:RAM×70-80%、共用:RAM×50%
innodb_log_file_size = 512M          # 1時間分の書き込み量を格納
innodb_flush_log_at_trx_commit = 2   # OSキャッシュ経由。ACID完全準拠なら1
innodb_flush_method = O_DIRECT       # ダブルバッファリング回避
innodb_file_per_table = 1            # Moodle必須

# === クエリキャッシュ ===
query_cache_type = 0                  # 無効推奨。MySQL 8.0では削除済み
query_cache_size = 0                  # Moodleの書き込み頻度ではキャッシュ無効化コスト大

# === 接続 ===
max_connections = 200
wait_timeout = 600

# === 一時テーブル ===
tmp_table_size = 128M
max_heap_table_size = 128M

# === その他 ===
max_allowed_packet = 64M
table_open_cache = 4000
slow_query_log = 1
long_query_time = 2
```

`innodb_buffer_pool_size` は**最も効果の大きい単一設定値**である。MoodleDocs公式も「MySQL性能改善で最初にやるべきことはInnoDB Buffer Poolの適正化」と明記している。`innodb_buffer_pool_reads`（ディスク読み取り）が `innodb_buffer_pool_read_requests`（リクエスト総数）の**1%未満**であればサイズは適正。

**クエリキャッシュ**はMySQL 8.0で完全に削除され、MariaDBでも利用可能だがMoodleの書き込み頻度（セッション更新、ログ書き込み）ではキャッシュ無効化のmutex競合が性能劣化を招くため**無効を推奨**する。

### PostgreSQL推奨設定（16GB RAM想定）

```ini
shared_buffers = 4GB                  # RAM × 25%
effective_cache_size = 12GB           # RAM × 50-75%（プランナへのヒント）
work_mem = 20MB                       # RAM × 0.25 ÷ max_connections
maintenance_work_mem = 512MB          # VACUUM/CREATE INDEX用
max_connections = 200
wal_buffers = 64MB
checkpoint_completion_target = 0.9
random_page_cost = 1.1                # SSD使用時
effective_io_concurrency = 200        # SSD使用時
```

PostgreSQL使用時は**PgBouncer**によるコネクションプーリングが強く推奨される（Moodle Cloudでも採用）。ただし**session poolingモードのみ対応**で、transaction poolingはMoodleの`WITH HOLD`カーソル使用により非互換（MDL-60174）。MySQL/MariaDBでは**ProxySQL**がread/write splittingやクエリキャッシュ機能を提供する。

---

## 6. インフラ構成例

### AWS構成（数百ユーザー、本番推奨）

```
┌──────────────────────────────────────────────────────────────┐
│                        Route 53 (DNS)                        │
└──────────────────────────┬───────────────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────────────┐
│                    CloudFront CDN                             │
│          静的アセット(CSS/JS/画像)キャッシュ + SSL(ACM)        │
│          ObjectFSプリサインドURLでS3ファイル直接配信           │
└──────────────────────────┬───────────────────────────────────┘
                           │
┌──────────────────────────▼───────────────────────────────────┐
│               Application Load Balancer (ALB)                │
│             HTTPS終端 / パブリックサブネット / Multi-AZ       │
└─────────────┬────────────────────────────────┬───────────────┘
              │                                │
┌─────────────▼──────────────┐  ┌──────────────▼──────────────┐
│  EC2 (Moodle App) - AZ-a   │  │  EC2 (Moodle App) - AZ-b   │
│  t3.large → m5.xlarge      │  │  Auto Scaling Group         │
│  Nginx + PHP-FPM 8.2       │  │  プライベートサブネット      │
│  プライベートサブネット     │  │                             │
└──┬──────────┬──────────┬───┘  └──┬──────────┬──────────┬────┘
   │          │          │         │          │          │
┌──▼──────┐ ┌▼──────────▼─────────▼──┐  ┌────▼──────────────┐
│   S3    │ │  ElastiCache Redis     │  │  RDS Aurora MySQL  │
│ + tool_ │ │  cache.t3.medium       │  │  db.t3.medium      │
│ objectfs│ │  セッション+MUCキャッシュ│  │  Multi-AZ          │
│(filedir)│ │  プライベートサブネット  │  │  プライベートサブネット│
└─────────┘ └────────────────────────┘  └────────────────────┘
```

**推奨インスタンスタイプと根拠：**

- **EC2**: t3.large（2vCPU/8GB）で開始。バースト可能でコスト効率が高い。CPU utilization 70%超が継続するならm5.xlarge（4vCPU/16GB）へスケールアップ
- **RDS**: db.t3.medium（2vCPU/4GB）。InnoDB buffer pool ≒ 3GBで数百ユーザーに十分。Multi-AZ必須
- **ElastiCache**: cache.t3.medium（3.09GB）。セッション用とMUC用を分離する場合は2ノード
- **S3**: tool_objectfsプラグインでfiledirをS3にオフロード。**プリサインドURL**でCloudFront経由の直接配信が可能で、PHPプロセスを経由しない

**ALB背後でのconfig.php設定：**

```php
$CFG->wwwroot   = 'https://moodle.example.com';
$CFG->sslproxy  = true;    // TLS終端がALBの場合に必須
$CFG->localcachedir = '/var/local/cache';  // ノードローカル（NFSに置かない）
```

**コスト最適化：** Reserved InstancesまたはSavings Plansで30-40%削減。S3はEFS（$0.30/GB）の約1/13のコスト（$0.023/GB）。Aurora Serverless v2は負荷変動が大きい教育機関に適合する。

### シンプルVPS構成（単一サーバー）

```
┌─────────────────────────────────────────────────────────┐
│              単一VPSサーバー (Ubuntu 24.04 LTS)          │
│              推奨: 4vCPU / 8GB RAM / 80GB SSD           │
│                                                          │
│  ┌────────────────────────────────────────────────────┐  │
│  │           Nginx (443/80, Let's Encrypt)            │  │
│  └──────────────────────┬─────────────────────────────┘  │
│                         │ unix socket                     │
│  ┌──────────────────────▼─────────────────────────────┐  │
│  │              PHP-FPM 8.2 + OPcache                 │  │
│  │              /var/www/moodle (コード)               │  │
│  └───┬──────────────┬────────────────────────────┬────┘  │
│      │              │                            │       │
│  ┌───▼────────┐ ┌───▼────────────┐  ┌────────────▼───┐  │
│  │ MariaDB    │ │ Redis 7.x      │  │ Moodledata     │  │
│  │ 10.11      │ │ :6379(Session) │  │ /var/www/      │  │
│  │ :3306      │ │ :6380(MUC)     │  │ moodledata     │  │
│  │ buffer_pool│ │ 256MB+512MB    │  │ (別ボリューム) │  │
│  │ = 3-4GB    │ │                │  │                │  │
│  └────────────┘ └────────────────┘  └────────────────┘  │
│                                                          │
│  Cron: systemd timer 1分間隔                             │
│  Backup: mysqldump + rsync (日次)                        │
└─────────────────────────────────────────────────────────┘
```

**最低スペック目安：** 数百ユーザーでVimeo埋め込み主体であれば**4vCPU/8GB RAM**が推奨最低ライン。動画ファイル配信がVimeo側CDNに完全にオフロードされるため、Moodleサーバーの帯域・ストレージ要件は大幅に軽い。ストレージは**Moodledataを別ボリュームに分離**し、ディスクフル時のOS巻き添えを防止する。

### Moodledataディレクトリのベストプラクティス

Moodledataは`$CFG->dataroot`で定義されるMoodleの全書き込みデータ格納先であり、filedir（アップロードファイル）、cache、sessions、temp等を含む。

```bash
# パーミッション設定
# Moodleコード → rootが所有、www-dataは読み取りのみ
chown -R root:www-data /var/www/moodle
chmod -R 755 /var/www/moodle

# Moodledata → www-dataがフルアクセス
chown -R www-data:www-data /var/moodledata
chmod -R 0770 /var/moodledata
```

```php
// config.php
$CFG->dataroot = '/var/moodledata';
$CFG->directorypermissions = 02770;  // デフォルト02777より厳格に
```

**重要：** Moodledataは**Webルートの外**に配置する（`/var/www/moodle`がWebルートなら、`/var/moodledata`に配置）。クラスタ構成でNFS共有する場合は`$CFG->preventfilelocking = true;`を設定し、`$CFG->localcachedir`をローカルSSDに向ける。

---

## まとめと優先度の高い施策

数百ユーザー規模のVimeo埋め込み主体Moodleで最も効果の高い施策を優先順に示す。**第一にRedisセッションハンドラへの移行**でページレスポンスを即座に改善できる。第二に**InnoDB Buffer Poolの適正化**（RAM×50-80%）でDB起因のボトルネックを解消する。第三に**OPcache有効化**（memory_consumption=256MB以上）でPHPコンパイルコストをゼロにする。これら3点だけで体感速度は劇的に変わる。

その上で、MUCのApplication cacheをRedisに移行し、APCuとの二段構成で高頻度キャッシュをさらに高速化する。Cronの1分間隔実行と監視は基本中の基本であり、systemd timerによるジャーナル統合とリソース制御が運用品質を高める。インフラ面では、VPS単体構成で十分に対応可能な規模だが、可用性が求められる場合はAWSのALB+EC2+RDS+ElastiCache+S3構成に移行し、tool_objectfsによるS3ファイルオフロードでストレージコストとファイル配信性能を同時に最適化できる。