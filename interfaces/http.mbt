///|
/// HTTPメソッド
pub(all) enum HttpMethod {
  Get
  Post
  Put
  Delete
  Patch
  Head
  Options
}

///|
/// HTTPリクエスト
pub(all) struct HttpRequest {
  /// リクエストURL
  url : String
  /// HTTPメソッド
  http_method : HttpMethod
  /// ヘッダー
  headers : Map[String, String]
  /// ボディ
  body : Bytes?
}

///|
/// HTTPレスポンス
pub(all) struct HttpResponse {
  /// ステータスコード
  status : Int
  /// ヘッダー
  headers : Map[String, String]
  /// ボディ
  body : Bytes
}

///|
/// HTTPクライアント トレイト
/// HTTP通信を抽象化
pub(open) trait HttpClient {
  /// リクエストを送信
  request(Self, HttpRequest) -> HttpResponse raise
  /// GETリクエスト
  get(Self, url~ : String, headers~ : Map[String, String]) -> HttpResponse raise
  /// POSTリクエスト
  post(Self, url~ : String, body~ : Bytes, headers~ : Map[String, String]) -> HttpResponse raise
}

///|
/// HTTPサーバー トレイト
/// HTTPサーバーを抽象化
pub(open) trait HttpServer {
  /// サーバーを開始
  start(Self, port~ : Int) -> Unit raise
  /// サーバーを停止
  stop(Self) -> Unit raise
  /// ルートを登録
  route(
    Self,
    http_method~ : HttpMethod,
    path~ : String,
    handler~ : (HttpRequest) -> HttpResponse,
  ) -> Unit
}

///|
/// WebSocketメッセージ
pub(all) enum WsMessage {
  Text(String)
  Binary(Bytes)
  Close(code~ : Int, reason~ : String)
  Ping(Bytes)
  Pong(Bytes)
}

///|
/// WebSocketクライアント トレイト
pub(open) trait WsClient {
  /// 接続
  connect(Self, url~ : String) -> Unit raise
  /// 切断
  disconnect(Self) -> Unit raise
  /// 接続中かどうか
  is_connected(Self) -> Bool
  /// メッセージを送信
  send(Self, WsMessage) -> Unit raise
  /// メッセージを受信
  receive(Self) -> WsMessage raise
}
