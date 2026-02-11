# Moodle 4.x/5.x ハイパフォーマンス・アーキテクチャ設計および運用最適化レポート：AWS・Linux VPS環境における動画中心型LMSの構築

## エグゼクティブサマリー

本レポートは、アクティブユーザー数数百名規模、特に動画コンテンツ（Vimeo埋め込み）を主体とする学習管理システム（LMS）であるMoodle 4.x（および最新のアーキテクチャ変更を含む5.x系列）のインフラストラクチャ設計とパフォーマンス最適化に関する包括的な技術文書である。想定されるワークロードは、日常的な学習活動に加え、一斉試験や課題提出に伴うスパイクアクセスを含むものであり、これに対し安定した応答速度と高い可用性を維持するための「AWSクラウドネイティブ構成」および「Linux VPS構成」の双方におけるベストプラクティスを詳述する。

従来のLAMPスタック（Linux, Apache, MySQL, PHP）から、より高効率な**LEMPスタック（Linux, Nginx, MariaDB/MySQL, PHP-FPM）**への移行を前提とし、サーバーサイドのカーネルチューニングから、PHPのJIT（Just-In-Time）コンパイル、Redisによる高度なキャッシュ戦略、そしてデータベースのInnoDBエンジン最適化に至るまで、フルスタックでのチューニング手法を網羅する。特に、Moodle 4.5以降および5.1で導入されたディレクトリ構造の刷新（`/public`ディレクトリの導入）に伴うセキュリティとウェブサーバー設定の変更点についても深く掘り下げ、将来的なアップグレードパスを保証する設計指針を提示する。

---

## 1. 要件定義とキャパシティプランニング

インフラストラクチャの選定に先立ち、対象となる「数百名のアクティブユーザー」という規模を、具体的なシステムリソース要件へと変換するプロセスが不可欠である。Moodleにおける「アクティブユーザー」と「同時接続ユーザー（Concurrency）」は明確に区別されるべき指標であり、リソース枯渇の主因は後者にある。

### 1.1 ワークロード特性の分析

「アクティブユーザー数百名」という要件を、システム工学的な観点から以下の2つのシナリオに分解して定義する。

1. **定常状態（Steady State）**:
    
    - 動画視聴（Vimeo埋め込み）が主体の学習活動。
        
    - 動画自体は外部CDN（Vimeo）から配信されるため、Moodleサーバーへの帯域負荷は限定的である。
        
    - サーバー負荷の中心は、LMSとしての進捗管理（トラッキング）、ページ遷移、フォーラム投稿などの軽量なトランザクション処理となる。
        
    - 同時接続率はアクティブユーザーの10%〜20%程度（20〜60名）と推測される。
        
2. **ピーク状態（Peak State）**:
    
    - 一斉試験（Quiz）の開始時や課題提出の締切直前。
        
    - このシナリオでは、アクティブユーザーの80%〜90%（150〜300名以上）が数分以内に同時にリクエストを送信する可能性がある。
        
    - Moodleのクイズモジュールはデータベースへの書き込み負荷が高く、かつPHPによる動的ページ生成コストも最大化するため、このピーク時を基準としたサイジングが必須となる。
        

### 1.2 リソース算出モデル（PHPプロセスのメモリ消費）

Moodleのパフォーマンスにおける最大のボトルネックは、Webサーバー（Nginx/Apache）ではなく、PHPアプリケーションサーバーのメモリ容量である。静的サイトとは異なり、Moodleの1リクエストはPHPプロセスによって処理され、その実行には相当量のメモリを要する。

**PHPプロセスのメモリ消費量見積もり:**

- 軽量なページ（テキスト、メニュー表示など）: 30MB 〜 50MB
    
- 重量級のページ（クイズ実行、評定表、バックアップ処理）: 60MB 〜 100MB以上
    

安全率を見込み、1プロセスあたり平均 **60MB** のメモリを消費すると仮定する。この数値を基に、必要なRAM容量を算出する。

|**同時接続数 (Concurrency)**|**必要RAM (PHPのみ)**|**OS・DB・キャッシュ用余力**|**推奨総RAM容量**|
|---|---|---|---|
|**50名** (定常時)|$50 \times 60\text{MB} = 3\text{GB}$|2GB 〜 4GB|**8GB**|
|**100名** (中負荷)|$100 \times 60\text{MB} = 6\text{GB}$|4GB 〜 6GB|**12GB 〜 16GB**|
|**200名** (スパイク時)|$200 \times 60\text{MB} = 12\text{GB}$|4GB 〜 8GB|**16GB 〜 32GB**|

**結論:** ユーザー数が数百名規模であり、かつ一斉アクセスが発生しうる教育機関や企業の研修環境においては、**16GB RAM** を搭載したサーバーが最低限のベースラインとなる。予算が許すならば **32GB** を確保することで、データベース（InnoDB Buffer Pool）やRedisキャッシュにより多くのメモリを割り当て、ディスクI/Oを極小化することが可能となる。

---

## 2. インフラストラクチャ・アーキテクチャ設計

提示された要件に基づき、AWSを利用したスケーラブルな構成案と、Linux VPSを利用したコストパフォーマンス重視の構成案の2つを詳細に設計する。

### 2.1 AWSクラウドネイティブ構成（高可用性・拡張性重視）

AWSを採用する最大のメリットは、各レイヤー（Web、DB、Cache、Storage）をマネージドサービスとして分離（Decoupling）できる点にある。これにより、単一障害点（SPOF）を排除し、負荷に応じて柔軟にリソースを変更できる。

#### 2.1.1 コンピュート層（Amazon EC2 / Auto Scaling）

Webサーバー層には、コストパフォーマンスに優れたARMアーキテクチャの採用を強く推奨する。

- **インスタンスタイプ**: **t4g.medium** (定常時) または **c6g.large** / **m6g.large** (高負荷時)。
    
    - **根拠**: AWS Graviton2プロセッサ（ARM64）を搭載した「g」シリーズは、同等のx86（Intel/AMD）インスタンスと比較して、PHPアプリケーションの実行において最大40%優れたコストパフォーマンスを発揮する。特にPHPはシングルスレッド性能が応答速度に直結するため、コンピューティング最適化された**c6g**シリーズがMoodleには適している。
        
- **スケーリング戦略**: Auto Scaling Groupを設定し、CPU使用率（例: 60%）をトリガーにインスタンス数を増減させる。ただし、MoodleのAuto Scalingには共有ストレージと外部データベースが必須となる。
    

#### 2.1.2 データベース層（Amazon RDS for Aurora）

- **エンジン**: **Amazon Aurora (MySQL Compatible)** または **Aurora (PostgreSQL Compatible)**。
    
- **サイジング**: **db.r6g.large** などのメモリ最適化インスタンス。Moodleのデータベース性能は、データセット（特に頻繁にアクセスされるテーブル）がいかにメモリ上に乗っているか（Buffer Pool率）に依存するため、CPUよりもメモリ容量を優先すべきである。
    

#### 2.1.3 キャッシュ層（Amazon ElastiCache for Redis）

Moodleのパフォーマンスチューニングにおいて最も費用対効果が高いのがRedisの導入である。

- **構成**: **Redis (Cluster Mode Disabled)** プライマリ＋レプリカ構成。
    
- **用途**: Moodle Universal Cache (MUC) のアプリケーションキャッシュおよびセッションストアとして利用する。EC2ローカルにRedisを立てるのではなく、ElastiCacheを利用することで、Webサーバーがスケールした際もセッション情報やキャッシュを一貫して共有できる。
    

#### 2.1.4 ストレージ層（EFS & S3）

- **Moodledata (共有ファイル)**: **Amazon EFS (Elastic File System)** を使用。Webサーバー群からマウントし、教材ファイルや一時ファイルを共有する。パフォーマンスモードは「General Purpose」、スループットモードは「Bursting」で開始し、遅延が見られる場合は「Provisioned」への切り替えを検討する。
    
- **バックアップ・静的アセット**: **Amazon S3**。コースバックアップファイルやログの長期保存先として利用する。
    

### 2.2 Linux VPS構成（コスト効率・シンプルさ重視）

予算制約がある場合や、管理の複雑さを避けたい場合は、高性能な単一VPS（Monolithic構成）が適している。近年のNVMe SSD搭載VPSはI/O性能が非常に高く、適切にチューニングすればAWSの分散構成よりも低遅延（Latency）を実現できる場合がある。

- **スペック推奨**: 4 vCPU / 16GB RAM / 100GB NVMe SSD 以上。
    
- **OS**: **Ubuntu 22.04 LTS** または **Ubuntu 24.04 LTS**。Debian系はドキュメントが豊富であり、Moodleコミュニティでのサポートも厚い。
    
- **ディスク構成**:
    
    - I/Oの競合を避けるため、可能であればデータベース領域（`/var/lib/mysql`）とWebルート・Moodledata領域を別のパーティション、あるいは別のブロックストレージボリュームとして切り出すことが望ましい。
        

---

## 3. オペレーティングシステム（Linux Kernel）の最適化

デフォルトのLinuxカーネル設定は汎用的な用途向けであり、Webサーバーとしての高負荷には最適化されていない。数百の同時接続を捌くためには、TCPスタックとファイルディスクリプタの制限緩和が不可欠である。

### 3.1 ネットワークスタックのチューニング (`sysctl.conf`)

多数のショートlivedなHTTP接続を効率的に処理し、TIME_WAIT状態のコネクションによるポート枯渇を防ぐための設定を行う。以下の設定を `/etc/sysctl.conf` に追記し、`sysctl -p` で適用する。

Ini, TOML

```
# ファイルオープン制限の緩和（システム全体）
fs.file-max = 500000

# TCP接続の再利用と高速リサイクル
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_fin_timeout = 15

# バックログキューの拡張（スパイクアクセス対策）
# 接続要求が急増した際にパケットドロップを防ぐ
net.core.somaxconn = 65535
net.core.netdev_max_backlog = 65535
net.ipv4.tcp_max_syn_backlog = 65535

# ポート範囲の拡大
net.ipv4.ip_local_port_range = 1024 65535

# TCPウィンドウサイズとバッファの最適化（通信効率向上）
net.ipv4.tcp_window_scaling = 1
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
```

### 3.2 リソース制限の緩和 (`limits.conf`)

NginxやPHP-FPMプロセスが多数のファイルを開けるよう、ユーザーレベルのリソース制限（ulimit）を引き上げる。`/etc/security/limits.conf` に以下を設定する。

- ```
      soft    nofile  65535
    ```
    
- ```
      hard    nofile  65535
    ```
    

root soft nofile 65535

root hard nofile 65535

www-data soft nofile 65535

www-data hard nofile 65535

---

## 4. Webサーバーアーキテクチャ（Nginx）の最適化

Moodle運用において、Apache（preforkモード）はメモリ消費が激しく、同時接続数が増えると急激にパフォーマンスが低下する傾向がある。対してNginxはイベント駆動型アーキテクチャを採用しており、少量のメモリで大量の同時接続を処理できるため、Moodle 4.xの運用には**Nginx + PHP-FPM**の構成（LEMPスタック）が推奨される。

### 4.1 FastCGIバッファリングの調整（重要）

Moodleのパフォーマンス問題で頻発するのが、NginxのFastCGIバッファ不足によるディスクI/Oの発生である。デフォルト設定ではバッファが小さすぎるため、PHPが生成した大きなHTMLレスポンス（コース画面など）がメモリに入りきらず、一時ファイルとしてディスクに書き出されてしまう。これを防ぐため、レスポンスがすべてメモリ上に収まるようバッファサイズを拡張する。

**推奨設定 (`nginx.conf` または `sites-available/moodle`):**

Nginx

```
location ~ [^/]\.php(/|$) {
    #... (fastcgi_pass 等の設定)

    # バッファサイズの拡張
    fastcgi_buffers 16 32k;
    fastcgi_buffer_size 64k;
    fastcgi_busy_buffers_size 128k;
    
    # バッファあふれ時のディスク書き込み制限（I/O負荷軽減）
    fastcgi_temp_file_write_size 256k;

    # タイムアウト設定の延長
    # バックアップやコースリストアなどの長時間処理対策
    fastcgi_read_timeout 600s; 
    fastcgi_connect_timeout 60s;
    fastcgi_send_timeout 600s;
}
```

### 4.2 X-Sendfile (X-Accel-Redirect) の導入

Moodleにおけるファイルダウンロード（教材PDFや動画ファイルなど）の処理を劇的に軽量化する技術である。通常、Moodle上のファイルはPHPを経由して配信されるため、ダウンロード中はPHPプロセスが占有されメモリを消費し続ける。**X-Sendfile**を有効にすると、PHPは権限チェックのみを行い、実際のデータ転送はNginxに委譲して即座にプロセスを解放する。

**Nginx設定:**

Nginx

```
# Moodleデータディレクトリへの内部エイリアス
# internalディレクティブにより、外部からの直接アクセスを遮断
location /dataroot/ {
    internal;
    alias /var/www/moodledata/; # 末尾のスラッシュが必須
}
```

**Moodle `config.php` 設定:**

PHP

```
$CFG->xsendfile = 'X-Accel-Redirect';
$CFG->xsendfilealiases = array(
    '/dataroot/' => $CFG->dataroot
);
```

この設定により、数百名が一斉に資料をダウンロードするような状況でも、PHPリソースが枯渇することを防げる。

### 4.3 Moodle 4.5/5.1 以降の公開ディレクトリ構造への対応

Moodle 5.1（および4.5以降）では、セキュリティ強化のためにWebルートの構造が変更されている。従来はMoodleのインストールディレクトリ全体が公開されていたが、新仕様では`/public`ディレクトリのみを公開し、システムコアファイルや`config.php`（の実体）をWebルート外に置くことが推奨されている。

**Nginx `root` ディレクティブの変更:**

Nginx

```
server {
    listen 80;
    server_name moodle.example.com;
    
    # 旧設定: root /var/www/moodle;
    # 新設定: /public をルートに指定
    root /var/www/moodle/public;
    
    index index.php;
    
    #...
}
```

この変更により、ブラウザからシステムファイルへの直接アクセス攻撃を構造的に防ぐことが可能となる。

---

## 5. PHPランタイムの最適化（PHP-FPM & JIT）

Moodleの動作速度を決定づけるエンジン部分である。PHP 8.1, 8.2, 8.3の利用を前提とし、プロセス管理とOpCacheのチューニングを行う。

### 5.1 プロセスマネージャ（PM）の戦略と算出

PHP-FPMのプロセス管理モードには `static`, `dynamic`, `ondemand` がある。

- **Static（静的）**: プロセス数を固定する。メモリ消費が予測しやすく、プロセス生成のオーバーヘッドがないため、メモリに余裕がある専用サーバー（VPS含む）では**最強のパフォーマンス**を発揮する。
    
- **Dynamic（動的）**: 負荷に応じてプロセスを増減させる。メモリリソースが限られている場合や、他のサービスと同居している場合に推奨される。
    

**`pm.max_children` の算出式（再掲）:**

$$\text{max\_children} = \frac{\text{利用可能メモリ (Total - OS/DB)}}{\text{1プロセスあたりの平均メモリ (約60MB)}}$$

**設定例（16GB RAMサーバーの場合）:**

OSとDB、Redis用に4GB〜6GBを残し、残り10GB〜12GBをPHPに割り当てると仮定する。

$10,240\text{MB} \div 60\text{MB} \approx 170$ プロセス。

**`/etc/php/8.x/fpm/pool.d/www.conf`:**

Ini, TOML

```
[www]
; 専用サーバーならstatic推奨
pm = dynamic 
pm.max_children = 170      ; 算出値に基づき設定
pm.start_servers = 40
pm.min_spare_servers = 20
pm.max_spare_servers = 60

; メモリリーク対策：一定回数処理したらプロセスを再起動
pm.max_requests = 1000

; 長時間処理の許容（コースバックアップ等）
request_terminate_timeout = 600s
```

### 5.2 OpCacheとJIT (Just-In-Time) のチューニング

Moodleは数万のPHPファイルから構成される巨大なアプリケーションであり、ディスクからPHPファイルを読み込んでコンパイルするコストが高い。OpCacheですべてのスクリプトをメモリに常駐させることが必須である。

**`php.ini` 推奨設定:**

Ini, TOML

```
[opcache]
opcache.enable = 1
; Moodleのコードベースは巨大なため、デフォルト(128)では不足する可能性が高い
opcache.memory_consumption = 512
; ファイル数の上限を引き上げる（重要）
; 推奨値は素数。Moodleのファイル数は多いため最大値を拡張
opcache.max_accelerated_files = 32531 

; 本番環境では0（無効）にすることでファイルシステムのstat呼び出しを削減し高速化
; ただしコード更新時にはキャッシュクリアが必要
opcache.validate_timestamps = 0 
opcache.revalidate_freq = 0

; Moodleに必須の設定
opcache.save_comments = 1
opcache.use_cwd = 1

; CLI版PHP（Cronジョブ）でもOpCacheを有効化
opcache.enable_cli = 1

; JITコンパイラ設定（PHP 8.x）
; CPU負荷の高い処理（複雑な計算など）に効果がある
opcache.jit_buffer_size = 100M
opcache.jit = 1255 ; Tracing JIT
```

---

## 6. キャッシュ戦略（Redis & MUC）

ファイルシステムベースのキャッシュ（デフォルト）はディスクI/Oを発生させ、ロック競合の原因となる。Redisを用いたインメモリキャッシュへの移行は、数百名規模のMoodle運用において**最も効果的なパフォーマンス改善策**の一つである。

### 6.1 Moodle Universal Cache (MUC) の構成

Moodle管理画面（`サイト管理 > プラグイン > キャッシュ > 設定`）からRedisストアを追加し、以下のキャッシュ定義にマッピングする。

1. **アプリケーションキャッシュ**: 言語文字列、データベーススキーマ、設定情報など。Redisに移行することでページ生成速度が向上する。
    
2. **セッションキャッシュ**: ユーザーのログイン状態。詳細は後述。
    

**Redis設定のポイント:**

- **Serializer**: 可能であれば **igbinary** を使用する。標準のPHPシリアライザよりもメモリ効率が良く、高速である。
    
- **Compression**: **zstd** 圧縮を有効にする。CPU負荷はわずかに増えるが、Redisのメモリ消費量を大幅に削減でき、ネットワーク転送量も減るため全体的なスループットが向上する。
    

### 6.2 セッションハンドリングとロック競合の回避

Moodleはセッション整合性を保つため、リクエスト処理中にセッションファイルをロックする。これにより、ユーザーがブラウザで複数のタブを開いた際（例：クイズを開きながら資料を見る）、それらが直列に処理され「読み込みが遅い」と感じる原因となる（セッションロック問題）。

**対策1: Redisセッションドライバの使用**

DBやファイルベースのセッションよりもロックの取得・解放が高速である。`config.php` に以下を設定する。

PHP

```
$CFG->session_handler_class = '\core\session\redis';
$CFG->session_redis_host = '127.0.0.1'; // AWSならElastiCacheのエンドポイント
$CFG->session_redis_port = 6379;
$CFG->session_redis_prefix = 'mdl_sess_';
$CFG->session_redis_acquire_lock_timeout = 120;
$CFG->session_redis_lock_expire = 7200;
$CFG->session_redis_serializer_use_igbinary = true; // igbinaryモジュールが必要
$CFG->session_redis_compressor = 'zstd'; // zstdモジュールが必要
```

**対策2: 読み取り専用セッション（Read-Only Sessions）の有効化** セッションへの書き込みが不要なページではロックを取得しないようにする設定。並列処理能力が向上する。

PHP

```
$CFG->enable_read_only_sessions = true;
```

---

## 7. データベース最適化（InnoDB Tuning）

Moodleのデータストアには **MariaDB** または **MySQL** を使用する。ストレージエンジンは **InnoDB** 一択である。

### 7.1 InnoDB Buffer Pool Sizing

データベースチューニングで最も重要なパラメータである。データセット（頻繁にアクセスされるテーブルとインデックス）がすべてメモリ上に載っている状態が理想的である。

- **推奨値**: DB専用サーバーであれば搭載メモリの70〜80%。Webサーバーと同居のVPSであれば、空きメモリの50%程度（スワップ発生を避けるため）。
    
    - 例: 16GB RAMのVPSで、Web/PHPに10GB使用する場合、DBには4GB程度を割り当てる。
        
        `innodb_buffer_pool_size = 4G`
        

### 7.2 I/O関連設定

書き込み性能とデータ整合性のトレードオフを調整する。

- `innodb_flush_log_at_trx_commit = 2`: デフォルトの「1」はトランザクションごとにディスク同期を行うため安全だが遅い。「2」に設定すると、OSクラッシュ時に最大1秒間のデータを失うリスクと引き換えに、書き込み性能が大幅に向上する。動画主体の学習サイトであれば許容範囲であることが多い。
    

---

## 8. 動画コンテンツの配信最適化（Vimeo連携）

要件にある「動画コンテンツ主体（Vimeo埋め込み）」は、Moodleサーバー自体の負荷軽減という観点からは非常に優れたアーキテクチャである。動画トラフィック（帯域幅、ストリーミング処理）を全てVimeoのCDNにオフロードできるからである。

### 8.1 埋め込みとトラッキングの戦略

単にURLを埋め込むだけでなく、学習進捗を管理（完了トラッキング）するための工夫が必要である。

- **Vimeo URLリソース**: Moodle標準の機能。URLを入力するだけで自動的に埋め込まれるが、視聴完了（最後まで見たか）のトラッキングはできない。
    
- **高機能プラグインの活用**: **VideoTime** や **SuperVideo** といったプラグインの導入を強く推奨する。
    
    - **機能**: Vimeo Player APIと連携し、「視聴率（%）」を取得できる。
        
    - **完了条件**: 「90%以上視聴したら完了とする」といった条件設定が可能になり、成績表（Gradebook）と連動できる。
        
    - **再開機能**: 学生が途中で止めた場合、次回アクセス時に続きから再生できる。
        

### 8.2 注意点

これらのプラグインは、視聴進捗を保存するために定期的にAjaxリクエストをMoodleサーバーに送信する。数百名が同時に動画を視聴すると、この「ハートビート」リクエストがサーバー負荷となる可能性がある。

対策として、Nginxの `keepalive_timeout` を適切に設定し、Ajaxリクエストによるコネクション確立のオーバーヘッドを減らすこと、およびPHP-FPMのプロセス数に余裕を持たせることが重要である。

---

## 9. 定期処理（Cron）の管理と最適化

MoodleにおいてCronは「心臓」であり、フォーラムのメール通知、完了トラッキングの集計、ログのローテーションなどあらゆるバックグラウンド処理を担う。数百名規模のサイトでは、デフォルトの**1分間隔**での実行が必須である。

### 9.1 Systemd Timer による実行（推奨）

従来の `crontab` ではなく、Linuxの `systemd` タイマーを使用することで、実行ログの管理が容易になり、リソース制限（CPU/メモリ）をかけやすくなる上、処理が重なり合ってサーバーがダウンするリスクを制御できる。

**サービス定義 (`/etc/systemd/system/moodle-cron.service`):**

Ini, TOML

```
[Unit]
Description=Moodle Cron Job


Type=oneshot
User=www-data
# 実行コマンド (パスは環境に合わせて変更)
ExecStart=/usr/bin/php /var/www/moodle/admin/cli/cron.php
# 処理がスタックした場合の保護
TimeoutStartSec=300
```

**タイマー定義 (`/etc/systemd/system/moodle-cron.timer`):**

Ini, TOML

```
[Unit]
Description=Run Moodle Cron every minute


OnBootSec=1min
OnUnitActiveSec=1min
Unit=moodle-cron.service

[Install]
WantedBy=timers.target
```

### 9.2 Ad-hocタスクの並列実行

Moodleのバックグラウンドタスク（Ad-hoc task）は、デフォルトでは直列に近い動作をするが、設定により並列度を上げることができる。動画の変換処理やメール送信が詰まらないよう、並列数を増やす。

**`config.php`:**

PHP

```
// Ad-hocタスクの同時実行数上限（デフォルト3 -> 10〜20へ拡張）
$CFG->task_adhoc_concurrency_limit = 10;
```

---

## 10. 監視とメンテナンス

構築後の安定運用には、継続的なモニタリングが不可欠である。

### 10.1 死活監視とCron監視

サーバーが起動していても、Cronが停止していればMoodleは機能不全（メールが飛ばない、完了にならない）に陥る。

- **Healthchecks.io** などの外部サービスを利用し、Cronスクリプトの最後にPingを送信させることで、Cronの停止を即座に検知する仕組みを導入する。
    

### 10.2 ログ管理

WebサーバーのアクセスログおよびMoodleのアプリケーションログは肥大化しやすい。

- **Log Rotation**: `logrotate` を設定し、日次で圧縮、一定期間（例: 30日）で削除する。
    
- **Moodleログストア**: サイト管理から標準ログの保持期間を設定する（例: 365日）。無制限に保存するとデータベース容量を圧迫し、パフォーマンス低下の原因となる。
    

---

## 結論

アクティブユーザー数百名規模、動画主体のMoodle 4.x/5.x環境を構築する場合、**AWS c6g.large** 以上のインスタンス、あるいは **16GB RAM** を搭載したLinux VPSが推奨される。

ハードウェア選定以上に重要なのが、**ソフトウェアスタックの最適化**である。

1. **Nginx + PHP-FPM** 構成への移行と、FastCGIバッファおよびX-Sendfileの適切な設定。
    
2. **OpCache** の徹底的なチューニング（ファイル数上限の緩和）。
    
3. **Redis** によるセッションおよびアプリケーションキャッシュのオフロード。
    
4. **InnoDB** のメモリ割り当て最適化。
    

これらを適切に実施することで、ハードウェアリソースを最大限に引き出し、試験時などのスパイクアクセスにも耐えうる、高速で安定した学習環境を提供することが可能となる。