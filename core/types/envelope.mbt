///|
/// メッセージ種別
pub(all) enum MessageType {
  Text
  Command(String)
  Reaction(String)
  Attachment(Array[AttachmentInfo])
  System(SystemEvent)
}

///|
/// 添付ファイル情報
pub(all) struct AttachmentInfo {
  filename : String
  content_type : String
  url : String
  size : Int64
}

///|
/// システムイベント種別
pub(all) enum SystemEvent {
  Join
  Leave
  ChannelCreated
  ChannelDeleted
}

///|
/// チャネルからの入力メッセージを表す共通構造
pub(all) struct InboundEnvelope {
  /// チャネル識別子（discord, slack, telegram, http など）
  channel : String
  /// チャット/スレッド識別子
  chat_id : String
  /// 送信者識別子
  sender_id : String
  /// 送信者表示名
  sender_name : String
  /// メッセージ内容
  content : String
  /// メッセージ種別
  message_type : MessageType
  /// チャネル固有メタデータ
  /// Vision/マルチモーダル: "image_url" キーに画像URLを格納
  /// 例: metadata["image_url"] = Json::string("https://...")
  /// 例: metadata["image_base64"] = Json::string("data:image/png;base64,...")
  metadata : Map[String, Json]
  /// 受信タイムスタンプ（Unix epoch ms）
  timestamp : Int64
}

///|
/// 出力添付ファイル
pub(all) struct OutboundAttachment {
  filename : String
  content_type : String
  data : Bytes
}

///|
/// 出力メッセージ
pub(all) struct OutboundMessage {
  /// 宛先チャネル
  channel : String
  /// 宛先チャット/スレッド
  chat_id : String
  /// メッセージ内容
  content : String
  /// 返信先メッセージID（オプション）
  reply_to : String?
  /// 添付ファイル
  attachments : Array[OutboundAttachment]?
  /// チャネル固有オプション
  options : Map[String, Json]?
}

///|
/// InboundEnvelopeのデフォルト値を生成
pub fn InboundEnvelope::default() -> InboundEnvelope {
  {
    channel: "",
    chat_id: "",
    sender_id: "",
    sender_name: "",
    content: "",
    message_type: MessageType::Text,
    metadata: {},
    timestamp: 0L,
  }
}

///|
/// OutboundMessageのデフォルト値を生成
pub fn OutboundMessage::default() -> OutboundMessage {
  {
    channel: "",
    chat_id: "",
    content: "",
    reply_to: None,
    attachments: None,
    options: None,
  }
}
