# Moodle学習時間計測と不正防止の包括的技術リサーチ

日本語教師養成課程の「420時間学習要件」をMoodleで厳密に管理するには、**既存プラグインだけでは不十分**であり、Heartbeat方式のカスタムプラグイン開発が必須となる。既存の無料プラグインはいずれも「動画流しっぱなし」「複数タブ同時視聴」「なりすまし」といった不正パターンに完全対応できておらず、Page Visibility API・Vimeo Player SDK・サーバーサイド検証を統合したカスタムローカルプラグイン（`local_timetrack`）の構築が最も現実的なアプローチである。文化庁の届出受理基準では1単位時間＝最低45分とされ、全50項目の必須教育内容をカバーする420単位時間の厳密な記録が求められるため、「過少計上（アンダーカウント）」方向の安全設計が重要となる。

---

## 1. 既存プラグインの全体像と限界

### block_dedication（Course Dedication）

Catalyst IT（Dan Marsden）がメンテナンスする最も広く使われている学習時間計測プラグインである。

- **リポジトリ**: https://github.com/catalyst/moodle-block_dedication
- **計測ロジック**: `mdl_logstore_standard_log`のログエントリ間隔から「セッション」を推定する**ログベース方式**。連続するクリック間の経過時間がセッションタイムアウト（設定可能）を超えなければ1セッションとみなし、セッション内の最初と最後のクリック間の経過時間を学習時間とする
- **処理方式**: スケジュールドタスク（Cron）でバッチ計算。リアルタイム計測ではない
- **データ保存**: 専用テーブルにセッションデータを格納。ReportBuilder対応
- **Moodle互換性**: 4.0+（コミュニティ報告では5.0でも動作）

**致命的な限界**: JavaScriptを一切使用しないため、**ページを開いたまま離席しても時間がカウントされる**（次のクリックまでの間隔がタイムアウト以内であれば）。動画再生中の実際の視聴状態は検知不可。Page Visibility APIの統合はGitHub Issue #70で計画されているが未実装。単一ページで完結するアクティビティ（PDF閲覧など）はログエントリが1つしか生成されず、**滞在時間がゼロ**として記録される。

### block_timestat（Timestat）

**唯一の無料リアルタイム計測プラグイン**として注目に値する。

- **リポジトリ**: https://github.com/jcorel/moodle-block_timestat
- **計測ロジック**: JavaScript（ScreenTimeモジュール）による**リアルタイム計測**。ブラウザタブがアクティブな場合のみ時間をカウントし、クリックやスクロールがない非アクティブ状態を検知して自動停止する
- **設定項目**: 最大非アクティブ時間、記録保存間隔がコース単位で設定可能
- **Moodle互換性**: 4.2+

**Pros**: タブアクティブ検知あり、非アクティブ検知あり、ユーザーへの視覚的タイマー表示  
**Cons**: ブロックを各ページに追加する必要がある（stickyブロック設定で回避可能だが）。SCORM等の別ウィンドウで開くアクティビティには非対応。Page Visibility APIを明示的に使用しているかは不明（フォーカスベースの検知）。動画の「再生中だが視聴していない」状態への対応は部分的（非アクティブタイムアウト後に停止）

### mod_attendanceregister（Attendance Register）

- **リポジトリ**: https://github.com/CinecaElearning/moodle-mod_attendanceregister
- **計測ロジック**: block_dedicationと同様のログベースセッション計算。追加機能として**オフラインセッションの自己申告**に対応
- **特長**: アクティビティ完了条件に「最低時間」を設定可能。コース横断トラッキング対応
- **Cons**: リアルタイム計測なし。Heartbeatなし。動画/タブ検知なし

### block_use_stats + report_trainingsessions

Valery Fremaux（ActiveProLearn）が開発した**職業訓練コンプライアンス向け**のプラグインセット。

- **リポジトリ**: https://github.com/vfremaux/moodle-block_use_stats
- **計測ロジック**: ログベースだが、**10分間隔のAJAXリクエスト（Notification Handler）**を持つ唯一のログベースプラグイン。テーマのレンダラーまたはフッターにコードを追加して全ページにHeartbeatを注入する
- **データ保存**: `block_use_stats_session`テーブル（userid, sessionstart, sessionend, courses）
- **Cons**: セットアップが複雑（テーマカスタマイズ必須）。Pro版が必要な機能多数。公式ディレクトリ上のリリースが古い

### IntelliBoard（商用）

最も高機能な学習時間計測を提供する**商用プラグイン**。

- **リポジトリ**: https://github.com/intelliboard/intelliboard
- **計測ロジック**: **30秒間隔のJavaScript Heartbeat** + マウスクリック・マウス移動・キーストロークによる**エンゲージメント検知**（60秒の非アクティブタイムアウト）。動画トラッキング機能あり（HTML5ビデオの再生時間を記録）
- **データ保存**: `local_intelliboard_tracking`テーブル。大規模サイト向けにMoodleDataファイルやMoodleキャッシュへの保存オプションあり
- **Cons**: **有料サブスクリプション必須**。外部SaaSコンポーネントあり。動画再生時間は「ユーザーが実際に見ているかに関わらず」記録される（Page Visibility API未対応）

### mod_videotime（Video Time）by bdecent GmbH

Moodle上でVimeo動画を埋め込むための専用アクティビティモジュール。

- **Pro版機能**: 視聴時間レポート、視聴率トラッキング、早送り防止、視聴時間/視聴率に基づくアクティビティ完了条件、レジューム再生
- **計測ロジック**: Vimeo Player SDKのイベントをフックして視聴セッションを記録
- **Cons**: Pro版は有料。汎用的な学習時間計測には非対応（動画のみ）

### プラグイン比較マトリクス

|プラグイン|無料|リアルタイム|エンゲージメント検知|タブ検知|Heartbeat|動画対応|コンプライアンス|
|---|---|---|---|---|---|---|---|
|block_dedication|✅|❌|❌|❌|❌|❌|△|
|block_timestat|✅|✅|✅（部分的）|✅（部分的）|✅|❌|△|
|mod_attendanceregister|✅|❌|❌|❌|❌|❌|△|
|block_use_stats|✅/有料|❌|✅（部分的）|❌|✅|❌|○|
|IntelliBoard|有料|✅|✅|❌|✅|✅（部分的）|◎|
|mod_videotime Pro|有料|✅|—|—|—|✅|△|

**結論**: 420時間要件の厳密な管理に**単独で対応できる既存プラグインは存在しない**。特に「動画流しっぱなし検知」と「複数タブ同時視聴の排除」は未解決の共通課題である。

---

## 2. カスタム実装の技術アーキテクチャ

### 全体設計思想

カスタムローカルプラグイン `local_timetrack` として実装し、以下の3層で学習時間を計測する。

1. **Activity Tracker**（全ページ共通）: Page Visibility API + ユーザーアクティビティ検知 + 30秒間隔Heartbeat
2. **Vimeo Tracker**（動画ページ専用）: Vimeo Player SDKイベント + 15秒間隔の視聴進捗同期
3. **Backend Aggregation**: 5分間隔のスケジュールドタスクで生データを日次サマリーに集約

### フロントエンド：Activity Tracker（AMD/ESMモジュール）

```javascript
/**
 * 学習時間トラッカー - Moodle AMDモジュール
 * @module local_timetrack/activity_tracker
 */
define(['core/ajax', 'core/notification'], function(Ajax, Notification) {

    const CONFIG = {
        HEARTBEAT_INTERVAL: 30000,  // 30秒間隔でHeartbeat送信
        IDLE_TIMEOUT: 300000,       // 5分間無操作でアイドル判定
        ACTIVITY_THROTTLE: 5000,    // アクティビティイベントは5秒に1回だけ処理
    };

    let state = {
        isPageVisible: !document.hidden,
        isUserActive: true,
        isIdle: false,
        lastActivityTime: Date.now(),
        activeSeconds: 0,
        lastHeartbeatTime: Date.now(),
        heartbeatTimer: null,
        idleTimer: null,
        courseId: 0,
        contextId: 0,
        sessKey: '',
    };

    /** Page Visibility API: タブの可視状態を監視 */
    function initVisibilityDetection() {
        document.addEventListener('visibilitychange', function() {
            const wasVisible = state.isPageVisible;
            state.isPageVisible = (document.visibilityState === 'visible');

            if (!state.isPageVisible && wasVisible) {
                // タブが非表示になった → 累積時間を記録してタイマー停止
                flushActiveTime();
                sendHeartbeat('tab_hidden');
            } else if (state.isPageVisible && !wasVisible) {
                // タブが再表示された → タイマー再開
                state.lastHeartbeatTime = Date.now();
                state.lastActivityTime = Date.now();
                state.isIdle = false;
            }
        });
    }

    /** ユーザーアクティビティ検知（デバウンス処理付き） */
    function initActivityDetection() {
        let lastThrottle = 0;
        const events = ['mousemove', 'keydown', 'scroll', 'click', 'touchstart'];

        function onActivity() {
            const now = Date.now();
            if (now - lastThrottle < CONFIG.ACTIVITY_THROTTLE) return;
            lastThrottle = now;

            state.lastActivityTime = now;
            if (state.isIdle) {
                state.isIdle = false;
                state.lastHeartbeatTime = now;
                sendHeartbeat('activity_resumed');
            }
        }

        events.forEach(function(evt) {
            document.addEventListener(evt, onActivity, {passive: true});
        });
    }

    /** アイドル判定タイマー */
    function initIdleDetection() {
        state.idleTimer = setInterval(function() {
            if (!state.isIdle && Date.now() - state.lastActivityTime > CONFIG.IDLE_TIMEOUT) {
                state.isIdle = true;
                flushActiveTime();
                sendHeartbeat('idle_start');
            }
        }, 10000);
    }

    /** アクティブ時間の累積計算 */
    function flushActiveTime() {
        if (state.isPageVisible && !state.isIdle) {
            const elapsed = Math.round((Date.now() - state.lastHeartbeatTime) / 1000);
            state.activeSeconds += Math.min(elapsed, 35); // 30秒 + 5秒許容
        }
        state.lastHeartbeatTime = Date.now();
    }

    /** Heartbeat送信 */
    function sendHeartbeat(eventType) {
        flushActiveTime();
        const seconds = state.activeSeconds;
        state.activeSeconds = 0;

        if (seconds <= 0 && eventType === 'periodic') return;

        Ajax.call([{
            methodname: 'local_timetrack_record_heartbeat',
            args: {
                courseid: state.courseId,
                activeseconds: Math.min(seconds, 35),
                eventtype: eventType || 'periodic',
            }
        }])[0].catch(function(err) {
            // 送信失敗時はlocalStorageに退避
            let pending = JSON.parse(localStorage.getItem('timetrack_pending') || '[]');
            pending.push({courseid: state.courseId, seconds: seconds, time: Date.now()});
            localStorage.setItem('timetrack_pending', JSON.stringify(pending));
        });
    }

    /** 定期Heartbeatタイマー開始 */
    function startHeartbeatTimer() {
        state.heartbeatTimer = setInterval(function() {
            if (state.isPageVisible && !state.isIdle) {
                sendHeartbeat('periodic');
            }
        }, CONFIG.HEARTBEAT_INTERVAL);
    }

    /** ページ離脱時のBeacon送信 */
    function initBeaconOnUnload() {
        document.addEventListener('visibilitychange', function() {
            if (document.visibilityState === 'hidden') {
                flushActiveTime();
                var data = JSON.stringify({
                    courseid: state.courseId,
                    activeseconds: Math.min(state.activeSeconds, 35),
                    eventtype: 'page_close',
                    sesskey: state.sessKey,
                });
                navigator.sendBeacon(
                    M.cfg.wwwroot + '/local/timetrack/beacon.php', data
                );
            }
        });
    }

    return {
        init: function(courseId, contextId, sessKey) {
            state.courseId = courseId;
            state.contextId = contextId;
            state.sessKey = sessKey;
            initVisibilityDetection();
            initActivityDetection();
            initIdleDetection();
            startHeartbeatTimer();
            initBeaconOnUnload();
        }
    };
});
```

### Vimeo Player SDK統合：動画視聴時間の厳密計測

Vimeo Player SDK（`@vimeo/player`）の主要イベントをフックし、**実際に再生中かつタブが可視状態の場合のみ**時間をカウントする。

```javascript
/**
 * Vimeo動画視聴時間トラッカー
 * @module local_timetrack/vimeo_tracker
 */
define(['core/ajax'], function(Ajax) {

    function VimeoTracker(iframeElement, courseId, cmId, videoId) {
        this.courseId = courseId;
        this.cmId = cmId;
        this.videoId = videoId;

        // 状態管理
        this.isPlaying = false;
        this.isBuffering = false;
        this.isPageVisible = !document.hidden;
        this.isSeeking = false;
        this.videoDuration = 0;
        this.lastValidTime = 0;      // 早送り防止：正当に到達した最遠点
        this.playStartTime = null;    // 再生開始時の実時刻
        this.accumulatedSeconds = 0;  // 累積再生秒数
        this.watchedSegments = new Set(); // 視聴済み秒数のセット

        this.player = new Vimeo.Player(iframeElement);
        this._bindEvents();
        this._bindVisibility();
        this._startSyncTimer();
    }

    VimeoTracker.prototype._bindEvents = function() {
        var self = this;

        this.player.getDuration().then(function(d) { self.videoDuration = d; });

        // 再生開始
        this.player.on('play', function(data) {
            self.isPlaying = true;
            self.playStartTime = Date.now();
        });

        // 一時停止
        this.player.on('pause', function() {
            self._accumulate();
            self.isPlaying = false;
        });

        // 再生完了
        this.player.on('ended', function() {
            self._accumulate();
            self.isPlaying = false;
            self._sync(true);
        });

        // timeupdate: 再生中約4回/秒発火 → 視聴セグメント記録
        this.player.on('timeupdate', function(data) {
            if (!self.isSeeking && self.isPlaying
                && !self.isBuffering && self.isPageVisible) {
                var sec = Math.floor(data.seconds);
                self.watchedSegments.add(sec);
                // 正当な再生位置を更新（2秒以内の進行は通常再生）
                if (data.seconds <= self.lastValidTime + 2) {
                    self.lastValidTime = Math.max(self.lastValidTime, data.seconds);
                }
            }
        });

        // シーク開始
        this.player.on('seeking', function() {
            self.isSeeking = true;
            self._accumulate();
        });

        // シーク完了 → 早送り防止ロジック
        this.player.on('seeked', function(data) {
            if (data.seconds > self.lastValidTime + 2) {
                // 未視聴区間への早送り → 最遠視聴位置に強制戻し
                self.player.setCurrentTime(self.lastValidTime).then(function() {
                    self.isSeeking = false;
                    if (self.isPlaying) self.playStartTime = Date.now();
                });
            } else {
                // 巻き戻しまたは視聴済み範囲内 → 許可
                self.isSeeking = false;
                if (self.isPlaying) self.playStartTime = Date.now();
            }
        });

        // バッファリング
        this.player.on('bufferstart', function() {
            self._accumulate();
            self.isBuffering = true;
        });
        this.player.on('bufferend', function() {
            self.isBuffering = false;
            if (self.isPlaying) self.playStartTime = Date.now();
        });
    };

    /** Page Visibility APIとの連携 */
    VimeoTracker.prototype._bindVisibility = function() {
        var self = this;
        document.addEventListener('visibilitychange', function() {
            var wasVisible = self.isPageVisible;
            self.isPageVisible = (document.visibilityState === 'visible');
            if (!self.isPageVisible && wasVisible) {
                self._accumulate();
                // オプション：タブ非表示時に動画を自動一時停止
                // self.player.pause();
            } else if (self.isPageVisible && !wasVisible) {
                if (self.isPlaying) self.playStartTime = Date.now();
            }
        });
    };

    /** 再生時間の累積 */
    VimeoTracker.prototype._accumulate = function() {
        if (this.playStartTime && this.isPlaying
            && !this.isBuffering && this.isPageVisible) {
            this.accumulatedSeconds += (Date.now() - this.playStartTime) / 1000;
        }
        this.playStartTime = this.isPlaying ? Date.now() : null;
    };

    /** 15秒間隔のサーバー同期 */
    VimeoTracker.prototype._startSyncTimer = function() {
        var self = this;
        setInterval(function() {
            if (self.isPlaying) self._sync(false);
        }, 15000);
    };

    /** サーバーへ視聴進捗を送信 */
    VimeoTracker.prototype._sync = function(isFinal) {
        this._accumulate();
        var ranges = this._compressRanges(Array.from(this.watchedSegments).sort(
            function(a,b){return a-b;}
        ));
        var percent = this.videoDuration > 0
            ? Math.round((this.watchedSegments.size / Math.ceil(this.videoDuration)) * 10000) / 100
            : 0;

        Ajax.call([{
            methodname: 'local_timetrack_record_video_progress',
            args: {
                courseid: this.courseId,
                cmid: this.cmId,
                videoid: this.videoId,
                videoduration: Math.ceil(this.videoDuration),
                watchedseconds: Math.round(this.accumulatedSeconds),
                watchedranges: JSON.stringify(ranges),
                percentcomplete: percent,
                isfinal: isFinal ? 1 : 0,
            }
        }])[0].catch(function(e) { console.warn('Video sync failed:', e); });

        this.accumulatedSeconds = 0;
        this.playStartTime = this.isPlaying ? Date.now() : null;
    };

    /** 秒数セットを[start,end]レンジ配列に圧縮 */
    VimeoTracker.prototype._compressRanges = function(sorted) {
        if (!sorted.length) return [];
        var ranges = [], s = sorted[0], e = sorted[0];
        for (var i = 1; i < sorted.length; i++) {
            if (sorted[i] <= e + 1) { e = sorted[i]; }
            else { ranges.push([s, e]); s = sorted[i]; e = sorted[i]; }
        }
        ranges.push([s, e]);
        return ranges;
    };

    return {
        init: function(selector, courseId, cmId, videoId) {
            var el = document.querySelector(selector);
            if (el) return new VimeoTracker(el, courseId, cmId, videoId);
        }
    };
});
```

### データベース設計

4つのカスタムテーブルで構成する。**生のHeartbeatデータ**と**集約済みサマリー**を分離し、レポートクエリのパフォーマンスを確保する。

```sql
-- 1. Heartbeat生データ（高頻度INSERT、定期的にクリーンアップ）
CREATE TABLE mdl_local_timetrack_heartbeat (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    userid BIGINT NOT NULL,
    courseid BIGINT NOT NULL,
    contextid BIGINT NOT NULL DEFAULT 0,
    activitytype VARCHAR(20) NOT NULL DEFAULT 'page_view', -- 'page_view' | 'video'
    activeseconds INT NOT NULL DEFAULT 0,
    eventtype VARCHAR(30) NOT NULL,  -- 'periodic'|'tab_hidden'|'idle_start'|'video_progress'等
    ipaddress VARCHAR(45),
    useragent VARCHAR(255),
    sessionid VARCHAR(128),
    timecreated BIGINT NOT NULL,
    processed TINYINT NOT NULL DEFAULT 0,
    INDEX idx_processed (processed, timecreated),
    INDEX idx_user_course_time (userid, courseid, timecreated)
);

-- 2. 日次サマリー（5分間隔のCronタスクでUPSERT）
CREATE TABLE mdl_local_timetrack_daily (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    userid BIGINT NOT NULL,
    courseid BIGINT NOT NULL,
    trackdate DATE NOT NULL,
    totalseconds INT NOT NULL DEFAULT 0,
    pageseconds INT NOT NULL DEFAULT 0,
    videoseconds INT NOT NULL DEFAULT 0,
    heartbeatcount INT NOT NULL DEFAULT 0,
    UNIQUE INDEX idx_user_course_date (userid, courseid, trackdate)
);

-- 3. 累積合計（ダッシュボード表示用、即座にルックアップ可能）
CREATE TABLE mdl_local_timetrack_total (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    userid BIGINT NOT NULL,
    courseid BIGINT NOT NULL,
    totalseconds INT NOT NULL DEFAULT 0,
    totalhours DECIMAL(8,2) NOT NULL DEFAULT 0.00,
    completed TINYINT NOT NULL DEFAULT 0,  -- 420時間達成フラグ
    UNIQUE INDEX idx_user_course (userid, courseid)
);

-- 4. 動画視聴進捗（セグメント単位の視聴記録）
CREATE TABLE mdl_local_timetrack_video (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    userid BIGINT NOT NULL,
    courseid BIGINT NOT NULL,
    cmid BIGINT NOT NULL,
    videoid VARCHAR(64) NOT NULL,
    videoduration INT NOT NULL DEFAULT 0,
    watchedseconds INT NOT NULL DEFAULT 0,
    watchedranges TEXT,  -- JSON: [[0,120],[180,300]] 形式
    percentcomplete DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    completed TINYINT NOT NULL DEFAULT 0,  -- 95%以上視聴で完了
    timecreated BIGINT NOT NULL,
    timemodified BIGINT NOT NULL,
    UNIQUE INDEX idx_user_cm_video (userid, cmid, videoid)
);
```

**パフォーマンス設計のポイント**: `mdl_logstore_standard_log`テーブルは大規模サイトでは数千万～数億行に膨れ上がり（80GB超の事例報告あり）、OPTIMIZEに3時間以上かかる場合がある。本設計ではこのテーブルに依存せず、**専用のHeartbeatテーブルにINSERT → 5分間隔でサマリーテーブルにUPSERT → 30日経過した処理済みHeartbeatを削除**という3段階パイプラインにより、レポートクエリは常に小さなサマリーテーブルに対して実行される。

### システム全体のシーケンスフロー

```
ブラウザ                           Moodleサーバー                    データベース
  |                                    |                                |
  |--- ページ読み込み ----------------→|                                |
  |←-- HTML + JS (activity_tracker     |                                |
  |    + vimeo_tracker) 配信 ----------|                                |
  |                                    |                                |
  | [Activity Tracker 初期化]          |                                |
  | ・visibilitychange バインド        |                                |
  | ・mousemove/keydown/scroll 監視    |                                |
  | ・30秒Heartbeatタイマー開始        |                                |
  | ・5分アイドルタイマー開始          |                                |
  |                                    |                                |
  | [30秒経過 & タブ可視 & 非アイドル] |                                |
  |--- AJAX: record_heartbeat -------→|                                |
  |    {courseid, activeseconds: 30,   |--- パラメータ検証 -----------→|
  |     eventtype: 'periodic'}         |--- レート制限チェック -------→|
  |                                    |--- 日次上限チェック ---------→|
  |                                    |--- INSERT heartbeat ---------→|
  |←-- {status: 'ok'} ---------------|                                |
  |                                    |                                |
  | [ユーザーがVimeo動画を再生]        |                                |
  | ・Vimeo SDK 'play' イベント発火    |                                |
  | ・timeupdate で秒単位セグメント記録|                                |
  | ・watchedSegments Set に蓄積       |                                |
  |                                    |                                |
  | [15秒経過（動画再生中）]           |                                |
  |--- AJAX: record_video_progress --→|                                |
  |    {watchedseconds, ranges,        |--- 秒数上限チェック（20秒）--→|
  |     percentcomplete}               |--- INSERT heartbeat ---------→|
  |                                    |--- UPSERT video進捗 --------→|
  |←-- {status, percentcomplete} -----|                                |
  |                                    |                                |
  | [ユーザーが早送りを試行]           |                                |
  | ・seeked イベント発火              |                                |
  | ・lastValidTime超過 → 強制巻き戻し|                                |
  |                                    |                                |
  | [タブ非表示 / 5分間無操作]         |                                |
  |--- Heartbeat送信（最終区間分）---→|                                |
  | [タイマー停止]                     |                                |
  |                                    |                                |
  | [ページ離脱 / ブラウザ閉じ]        |                                |
  |--- navigator.sendBeacon ----------→|--- INSERT heartbeat ---------→|
  |                                    |                                |
  |                                    | [Cron: 5分間隔]               |
  |                                    |--- aggregate_time タスク ----→|
  |                                    |   未処理HB集計                 |
  |                                    |   日次サマリーUPSERT           |
  |                                    |   累積合計テーブル更新         |
  |                                    |   HBをprocessed=1に更新        |
  |                                    |                                |
  |                                    | [Cron: 毎日3:30 AM]           |
  |                                    |--- cleanup_heartbeats タスク→ |
  |                                    |   30日以上前の処理済みHB削除   |
```

---

## 3. 不正受講対策の多層防御設計

### 多重ログイン防止

Moodleには`limitconcurrentlogins`という**ネイティブ設定**が存在する。サイト管理 → プラグイン → 認証 → 認証管理から設定し、値を`1`にすると同一ユーザーの同時ログインを制限できる。ただし、SSOプラグインとの併用時には**動作しない**ケースがフォーラムで複数報告されている。

より確実な対策として**auth_uniquelogin**プラグイン（https://moodle.org/plugins/auth_uniquelogin ）がある。ED-ROM社が開発し、新しいログイン時に既存セッションを強制終了する。認証プラグインリストの**最上位**に配置し、データベースセッション保存を有効にする必要がある。

クイズ限定だが、**quizaccess_onesession**プラグイン（https://moodle.org/plugins/quizaccess_onesession ）は同一クイズへの複数ブラウザからの同時アクセスを、セッションID・User Agent・IPアドレスの記録と照合によってブロックする。

### Bot・自動化ツール検知

**ヘッドレスブラウザ検知**には3つの主要手法がある。`navigator.webdriver`プロパティのチェック（Puppeteer/Seleniumが`true`を返す）、`navigator.userAgent`に"HeadlessChrome"が含まれるかの確認、そしてChrome DevTools Protocol（CDP）のシリアライゼーション副作用を検出する手法が最も効果的とされる。ただし、`puppeteer-extra-plugin-stealth`等のステルスフレームワークはこれらの多くをバイパスできるため、**行動分析との組み合わせが必須**となる。

```javascript
// Heartbeat送信パターンの異常検知（サーバーサイド）
// 人間は自然なジッター（±1-3秒）を持つが、
// ボットは完全に等間隔（例：正確に30.000秒）で送信する
function detectBotPattern($heartbeats) {
    $intervals = [];
    for ($i = 1; $i < count($heartbeats); $i++) {
        $intervals[] = $heartbeats[$i]->timecreated - $heartbeats[$i-1]->timecreated;
    }
    $stddev = stats_standard_deviation($intervals);
    if ($stddev < 0.5 && count($intervals) > 10) {
        return true; // ジッターが少なすぎる → ボットの可能性
    }
    return false;
}
```

CAPTCHA対策として、Moodleは**reCAPTCHA v2**をネイティブサポートしている（サイト管理 → プラグイン → 認証 → 認証管理）。さらに**tool_registrationrules**プラグインはALTCHA（プライバシー配慮型）、Cloudflare Turnstile、ハニーポットフィールド、最低入力時間チェックなど複数の防御層を提供する。

### Heartbeatリクエストの改ざん防止

開発者ツールを使ったHeartbeat偽造を防ぐため、**トークンベースの検証**を実装する。

```
サーバー → クライアント: {nextToken: encrypt(userId + timestamp + random + nonce)}
クライアント → サーバー: {token: 受信トークン, activeseconds: X}
サーバー: decrypt(token) → タイムスタンプ鮮度チェック → ワンタイム使用チェック → 検証OK
```

各Heartbeatレスポンスに次回用の暗号化チャレンジトークンを含め、ワンタイム使用かつ時間制限付きとする。加えて、リクエストパターン分析（完全に等間隔のHeartbeatはボットを示唆）やレート制限（1ユーザーあたり最大3 Heartbeat/分）をサーバーサイドで実施する。

### 複数タブの同時視聴排除

**BroadcastChannel API**を使用して同一ブラウザ内の複数タブを検知する。

```javascript
const channel = new BroadcastChannel('timetrack_session');
const tabId = crypto.randomUUID();

channel.postMessage({type: 'new_tab', tabId: tabId, courseId: courseId});

channel.onmessage = function(e) {
    if (e.data.type === 'new_tab' && e.data.courseId === courseId && e.data.tabId !== tabId) {
        // 同じコースが別タブで開かれた → 古いタブのトラッキングを停止
        stopTracking();
        showWarning('別のタブでこのコースが開かれたため、学習時間の計測を停止しました。');
    }
};
```

サーバーサイドでは、ページロード時にユニークなタブトークンを発行し、最新のトークンからのHeartbeatのみを有効とする。古いトークンからのHeartbeatは破棄することで、複数タブからの二重計上を防止する。

### 日本の規制要件への対応

文化庁の420時間基準では**1単位時間＝最低45分**と定められており、全50項目の必須教育内容を網羅する必要がある。2024年4月からは「登録日本語教員」が国家資格化され、登録日本語教員養成機関としての認定を受けるための時間管理の厳格化が進んでいる。

こども家庭庁（旧厚労省管轄）が2019年に公開した「不正防止対策検討会における議論のとりまとめ」は、eラーニングにおける不正を**「なりすまし行為」**と**「早回し等」**の2類型に分類している。特に「流し見（動画を再生しながら別の作業をする）」については、**純粋な技術的防止は極めて困難**との結論が示されており、定期的な理解度チェックや確認ポップアップの組み合わせが推奨されている。

日本国内では**サクテスAIMONITOR**（株式会社イー・コミュニケーションズ、2024年8月リリース）がeラーニング受講中のWebカメラリアルタイム監視をAIで行うソリューションとして注目されている。離席検知、なりすまし検知、複数人受講検知を行い、不正検知時にコンテンツを自動停止する機能を持つ。同社の2024年調査では、研修担当者の**69.1%が「動画流しっぱなし」**を、**52.9%が「代理受講」**を懸念しており、**66.0%が「読み飛ばし防止機能」**を導入済みと回答している。

---

## 4. 推奨アーキテクチャと実装ロードマップ

### 多層防御の技術スタック

|レイヤー|技術/方法|目的|
|---|---|---|
|**認証制御**|`limitconcurrentlogins=1` + `auth_uniquelogin`|同時ログイン排除|
|**MFA**|`tool_mfa`（TOTP + IPファクター）|本人確認強化|
|**ボット防止**|reCAPTCHA + `navigator.webdriver`チェック|自動化排除|
|**エンゲージメント検知**|Page Visibility API + Heartbeat + アイドル検知|非アクティブ排除|
|**動画視聴管理**|Vimeo Player SDK + セグメント追跡 + 早送り防止|視聴時間厳密計測|
|**複数タブ防止**|BroadcastChannel API + サーバーサイドタブトークン|二重計上防止|
|**トークン検証**|HMAC署名ローテーション + ワンタイムトークン|リプレイ攻撃防止|
|**サーバーサイド検証**|レート制限 + 日次上限（8時間/日） + パターン分析|不正データ排除|
|**コンテンツ完全性**|逐次アクセス制限 + 定期理解度テスト|読み飛ばし防止|
|**監査証跡**|IPアドレス + User Agent + セッションID記録|事後検証|

### プラグインファイル構成

```
local/timetrack/
├── version.php
├── lib.php                         # コールバック（ページヘッダーへのJS注入等）
├── settings.php                    # 管理設定画面
├── beacon.php                      # sendBeaconエンドポイント
├── db/
│   ├── install.xml                 # 4テーブル定義
│   ├── upgrade.php
│   ├── services.php                # Webサービス定義
│   ├── tasks.php                   # スケジュールドタスク
│   └── access.php                  # ケイパビリティ
├── classes/
│   ├── external/
│   │   ├── record_heartbeat.php    # Heartbeat受信API
│   │   ├── record_video_progress.php # 動画進捗受信API
│   │   └── get_user_time.php       # ダッシュボード用取得API
│   └── task/
│       ├── aggregate_time.php      # 5分間隔集約タスク
│       └── cleanup_heartbeats.php  # 30日超過HBクリーンアップ
├── amd/src/
│   ├── activity_tracker.js         # 汎用ページトラッカー
│   ├── vimeo_tracker.js            # Vimeo動画トラッカー
│   └── tab_guard.js                # 複数タブ防止モジュール
├── lang/
│   ├── en/local_timetrack.php
│   └── ja/local_timetrack.php
├── templates/
│   └── time_display.mustache       # ユーザー向け学習時間表示
├── report.php                      # 420時間コンプライアンスレポート
└── cli/
    └── recalculate.php             # 再集計CLIスクリプト
```

---

## Conclusion

420時間学習要件の厳密な管理には、既存プラグインの「ログベース推定」アプローチでは根本的に不十分であり、**クライアントサイドのリアルタイム検知（Page Visibility API + ユーザーアクティビティ検知）とサーバーサイドの多層検証を組み合わせたカスタムプラグインの開発が不可避**である。

特筆すべきは、日本政府機関（こども家庭庁）自身が「動画の流し見の純粋な技術的防止は極めて困難」と認めている点であり、技術的対策だけでなく**定期的な理解度確認テスト**や**確認ポップアップ**といった制度設計的アプローチとの組み合わせが現実的な解となる。block_timestatのリアルタイム計測コンセプト、IntelliBoard的なHeartbeat方式、Vimeo Player SDKのイベントフック、BroadcastChannel APIによるタブ制御という4つの技術要素を `local_timetrack` として統合することで、現時点で最も高い精度と不正耐性を持つ学習時間管理システムを実現できる。

実装優先順位としては、（1）Heartbeat基盤とActivity Trackerの構築、（2）Vimeo Player SDK統合、（3）複数タブ防止とトークン検証、（4）コンプライアンスレポート画面の開発、という順序が効率的である。開発規模は中級PHPエンジニア1名で約**4〜6週間**と見積もられ、最も工数がかかるのはフロントエンドのエッジケース処理（ブラウザクラッシュ、ネットワーク切断、localStorage退避と再送信）である。