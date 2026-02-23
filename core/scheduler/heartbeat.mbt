///|
/// ハートビート管理
/// エージェントの生存確認とヘルスチェック

///|
/// ハートビート状態
pub(all) enum HeartbeatStatus {
  /// 正常
  Healthy
  /// 警告（応答が遅い）
  Warning
  /// 異常（タイムアウト）
  Unhealthy
  /// 不明（まだ受信なし）
  Unknown
}

///|
/// ハートビート設定
pub(all) struct HeartbeatConfig {
  /// ハートビート間隔（ミリ秒）
  interval_ms : Int64
  /// タイムアウト（ミリ秒）
  timeout_ms : Int64
  /// 警告閾値（ミリ秒）
  warning_threshold_ms : Int64
  /// 最大リトライ回数
  max_retries : Int
}

///|
/// デフォルトのハートビート設定
pub fn HeartbeatConfig::default() -> HeartbeatConfig {
  {
    interval_ms: 30000L, // 30秒
    timeout_ms: 90000L, // 90秒
    warning_threshold_ms: 60000L, // 60秒
    max_retries: 3,
  }
}

///|
/// ハートビートレコード
pub struct HeartbeatRecord {
  /// エージェントID
  agent_id : String
  /// 最後のハートビート時刻
  mut last_heartbeat : Int64
  /// 状態
  mut status : HeartbeatStatus
  /// 連続失敗回数
  mut failure_count : Int
  /// メタデータ
  metadata : Map[String, Json]
}

///|
/// HeartbeatRecordを新規作成
pub fn HeartbeatRecord::new(agent_id~ : String) -> HeartbeatRecord {
  {
    agent_id,
    last_heartbeat: 0L,
    status: HeartbeatStatus::Unknown,
    failure_count: 0,
    metadata: {},
  }
}

///|
/// ハートビートマネージャ
pub struct HeartbeatManager {
  /// 設定
  config : HeartbeatConfig
  /// エージェントごとのレコード
  records : Map[String, HeartbeatRecord]
}

///|
/// HeartbeatManagerを新規作成
pub fn HeartbeatManager::new(config~ : HeartbeatConfig) -> HeartbeatManager {
  { config, records: {} }
}

///|
/// デフォルトのHeartbeatManager
pub fn HeartbeatManager::default() -> HeartbeatManager {
  { config: HeartbeatConfig::default(), records: {} }
}

///|
/// ハートビートを受信
pub fn HeartbeatManager::receive_heartbeat(
  self : HeartbeatManager,
  agent_id : String,
  timestamp : Int64,
  metadata : Map[String, Json],
) -> Unit {
  let record = match self.records.get(agent_id) {
    Some(r) => r
    None => {
      let r = HeartbeatRecord::new(agent_id~)
      self.records[agent_id] = r
      r
    }
  }
  record.last_heartbeat = timestamp
  record.status = HeartbeatStatus::Healthy
  record.failure_count = 0
  for key, value in metadata {
    record.metadata[key] = value
  }
}

///|
/// 全エージェントの状態を更新
pub fn HeartbeatManager::update_all_statuses(
  self : HeartbeatManager,
  current_time : Int64,
) -> Unit {
  for _, record in self.records {
    self.update_status(record, current_time)
  }
}

///|
/// 単一レコードの状態を更新
fn HeartbeatManager::update_status(
  self : HeartbeatManager,
  record : HeartbeatRecord,
  current_time : Int64,
) -> Unit {
  let elapsed = current_time - record.last_heartbeat
  if elapsed > self.config.timeout_ms {
    record.status = HeartbeatStatus::Unhealthy
    record.failure_count = record.failure_count + 1
  } else if elapsed > self.config.warning_threshold_ms {
    record.status = HeartbeatStatus::Warning
  } else {
    record.status = HeartbeatStatus::Healthy
  }
}

///|
/// エージェントの状態を取得
pub fn HeartbeatManager::get_status(
  self : HeartbeatManager,
  agent_id : String,
) -> HeartbeatStatus {
  match self.records.get(agent_id) {
    Some(record) => record.status
    None => HeartbeatStatus::Unknown
  }
}

///|
/// 不健全なエージェントのリストを取得
pub fn HeartbeatManager::get_unhealthy_agents(
  self : HeartbeatManager,
) -> Array[String] {
  let result : Array[String] = []
  for agent_id, record in self.records {
    match record.status {
      HeartbeatStatus::Unhealthy => result.push(agent_id)
      _ => ()
    }
  }
  result
}

///|
/// 全エージェントのサマリーを取得
pub fn HeartbeatManager::get_summary(self : HeartbeatManager) -> Json {
  let mut healthy = 0
  let mut warning = 0
  let mut unhealthy = 0
  let mut unknown = 0
  for _, record in self.records {
    match record.status {
      HeartbeatStatus::Healthy => healthy = healthy + 1
      HeartbeatStatus::Warning => warning = warning + 1
      HeartbeatStatus::Unhealthy => unhealthy = unhealthy + 1
      HeartbeatStatus::Unknown => unknown = unknown + 1
    }
  }
  {
    "total": self.records.length(),
    "healthy": healthy,
    "warning": warning,
    "unhealthy": unhealthy,
    "unknown": unknown,
  }
}

///|
/// エージェントを削除
pub fn HeartbeatManager::remove_agent(
  self : HeartbeatManager,
  agent_id : String,
) -> Bool {
  match self.records.get(agent_id) {
    Some(_) => {
      self.records.remove(agent_id)
      true
    }
    None => false
  }
}

///|
/// ヘルスチェックエンドポイント用のレスポンス
pub struct HealthCheckResponse {
  /// 全体の状態
  status : String
  /// バージョン
  version : String
  /// 詳細
  details : Json
  /// タイムスタンプ
  timestamp : Int64
}

///|
/// ヘルスチェックを実行
pub fn HeartbeatManager::health_check(
  self : HeartbeatManager,
  current_time : Int64,
) -> HealthCheckResponse {
  self.update_all_statuses(current_time)
  let summary = self.get_summary()
  let unhealthy = self.get_unhealthy_agents()
  let status = if unhealthy.length() > 0 { "degraded" } else { "healthy" }
  {
    status,
    version: "0.1.0",
    details: {
      "agents": summary,
      "unhealthy_agents": Json::array(
        unhealthy.map(fn(id) { Json::string(id) }),
      ),
    },
    timestamp: current_time,
  }
}

///|
/// HealthCheckResponseをJSONに変換
pub fn HealthCheckResponse::to_json(self : HealthCheckResponse) -> Json {
  {
    "status": self.status,
    "version": self.version,
    "details": self.details,
    "timestamp": self.timestamp.to_int(),
  }
}
