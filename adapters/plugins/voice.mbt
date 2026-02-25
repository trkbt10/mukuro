///|
/// Voice Interface Plugin
/// Provides Text-to-Speech (TTS) and Speech-to-Text (STT) capabilities

///|
/// Audio format
pub(all) enum AudioFormat {
  Pcm16
  Mp3
  Wav
  Ogg
  Flac
}

///|
/// Convert audio format to string
pub fn AudioFormat::to_string(self : AudioFormat) -> String {
  match self {
    Pcm16 => "pcm16"
    Mp3 => "mp3"
    Wav => "wav"
    Ogg => "ogg"
    Flac => "flac"
  }
}

///|
/// Parse audio format from string
pub fn AudioFormat::from_string(s : String) -> AudioFormat? {
  match s.to_lower() {
    "pcm16" => Some(Pcm16)
    "mp3" => Some(Mp3)
    "wav" => Some(Wav)
    "ogg" => Some(Ogg)
    "flac" => Some(Flac)
    _ => None
  }
}

///|
/// Voice model for TTS
pub(all) struct VoiceModel {
  /// Model ID
  id : String
  /// Display name
  name : String
  /// Language code (e.g., "en-US", "ja-JP")
  language : String
  /// Gender (male, female, neutral)
  gender : String
  /// Provider (google, azure, aws, openai, elevenlabs)
  provider : String
}

///|
/// Speech synthesis request
pub(all) struct SpeechRequest {
  /// Text to synthesize
  text : String
  /// Voice model ID
  voice_id : String
  /// Output format
  format : AudioFormat
  /// Speaking rate (0.5 to 2.0, 1.0 = normal)
  rate : Double
  /// Pitch adjustment (-20 to 20 semitones)
  pitch : Double
  /// Volume gain (-96 to 16 dB)
  volume_gain_db : Double
  /// SSML input (if true, text contains SSML)
  ssml : Bool
}

///|
/// Speech synthesis result
pub(all) struct SpeechResult {
  /// Request ID
  id : String
  /// Audio data (base64 encoded)
  audio_data : String
  /// Audio format
  format : AudioFormat
  /// Duration in milliseconds
  duration_ms : Int
  /// Character count processed
  character_count : Int
}

///|
/// Transcription request
pub(all) struct TranscriptionRequest {
  /// Audio data (base64 encoded)
  audio_data : String
  /// Audio format
  format : AudioFormat
  /// Language hint (optional)
  language : String?
  /// Enable word-level timestamps
  word_timestamps : Bool
  /// Enable punctuation
  punctuation : Bool
  /// Enable profanity filter
  profanity_filter : Bool
}

///|
/// Word with timestamp
pub(all) struct TranscriptWord {
  /// Word text
  word : String
  /// Start time in milliseconds
  start_ms : Int
  /// End time in milliseconds
  end_ms : Int
  /// Confidence score (0.0 to 1.0)
  confidence : Double
}

///|
/// Transcription result
pub(all) struct TranscriptionResult {
  /// Request ID
  id : String
  /// Full transcript text
  text : String
  /// Detected language
  language : String
  /// Confidence score (0.0 to 1.0)
  confidence : Double
  /// Word-level timestamps (if requested)
  words : Array[TranscriptWord]
  /// Duration of audio in milliseconds
  duration_ms : Int
}

///|
/// Wake word configuration
pub(all) struct WakeWordConfig {
  /// Wake word phrases (e.g., ["hey mukuro", "ok mukuro"])
  phrases : Array[String]
  /// Sensitivity (0.0 to 1.0, higher = more sensitive)
  sensitivity : Double
  /// Timeout in seconds (how long to listen after wake word)
  timeout_seconds : Int
  /// Audio format for streaming
  format : AudioFormat
}

///|
/// Wake word detection result
pub(all) struct WakeWordResult {
  /// Detected phrase
  phrase : String
  /// Confidence score
  confidence : Double
  /// Timestamp when detected
  timestamp : Int64
}

///|
/// Streaming session
pub(all) struct StreamingSession {
  /// Session ID
  id : String
  /// Is active
  active : Bool
  /// Audio format
  format : AudioFormat
  /// Buffer of audio chunks (base64)
  audio_chunks : Array[String]
  /// Partial transcripts
  partial_transcripts : Array[String]
  /// Start timestamp
  started_at : Int64
}

///|
/// Voice plugin configuration
pub(all) struct VoicePluginConfig {
  /// Plugin name
  name : String
  /// Default TTS provider
  tts_provider : String
  /// Default STT provider
  stt_provider : String
  /// Default voice ID
  default_voice_id : String
  /// Default language
  default_language : String
  /// Sample rate (Hz)
  sample_rate : Int
  /// Enable wake word detection
  enable_wake_word : Bool
}

///|
/// Default voice config
pub fn VoicePluginConfig::default(name~ : String) -> VoicePluginConfig {
  {
    name,
    tts_provider: "openai",
    stt_provider: "openai",
    default_voice_id: "alloy",
    default_language: "en-US",
    sample_rate: 16000,
    enable_wake_word: false,
  }
}

///|
/// Voice plugin
pub struct VoicePlugin {
  config : VoicePluginConfig
  /// Available voice models
  voices : Map[String, VoiceModel]
  /// Active streaming sessions
  sessions : Map[String, StreamingSession]
  /// Wake word config
  mut wake_word_config : WakeWordConfig?
  /// ID generators for different entity types
  tts_id_gen : @util.IdGenerator
  stt_id_gen : @util.IdGenerator
  stream_id_gen : @util.IdGenerator
  /// Simulated timestamp
  mut current_time : Int64
}

///|
/// Create new voice plugin
pub fn VoicePlugin::new(config : VoicePluginConfig) -> VoicePlugin {
  let voices : Map[String, VoiceModel] = {}
  // Add default voices
  voices["alloy"] = {
    id: "alloy",
    name: "Alloy",
    language: "en-US",
    gender: "neutral",
    provider: "openai",
  }
  voices["echo"] = {
    id: "echo",
    name: "Echo",
    language: "en-US",
    gender: "male",
    provider: "openai",
  }
  voices["fable"] = {
    id: "fable",
    name: "Fable",
    language: "en-US",
    gender: "female",
    provider: "openai",
  }
  voices["onyx"] = {
    id: "onyx",
    name: "Onyx",
    language: "en-US",
    gender: "male",
    provider: "openai",
  }
  voices["nova"] = {
    id: "nova",
    name: "Nova",
    language: "en-US",
    gender: "female",
    provider: "openai",
  }
  voices["shimmer"] = {
    id: "shimmer",
    name: "Shimmer",
    language: "en-US",
    gender: "female",
    provider: "openai",
  }
  {
    config,
    voices,
    sessions: {},
    wake_word_config: None,
    tts_id_gen: @util.IdGenerator::new("tts_"),
    stt_id_gen: @util.IdGenerator::new("stt_"),
    stream_id_gen: @util.IdGenerator::new("stream_"),
    current_time: 1000000000000L,
  }
}

///|
/// Get current timestamp
fn VoicePlugin::get_timestamp(self : VoicePlugin) -> Int64 {
  let ts = self.current_time
  self.current_time = self.current_time + 1L
  ts
}

///|
/// Synthesize speech (TTS)
pub fn VoicePlugin::synthesize(
  self : VoicePlugin,
  text : String,
  voice_id? : String? = None,
  format? : AudioFormat = Wav,
  rate? : Double = 1.0,
  pitch? : Double = 0.0,
  volume_gain_db? : Double = 0.0,
  ssml? : Bool = false,
) -> SpeechResult {
  // Future: Use these for SSML generation
  let _ = pitch
  let _ = volume_gain_db
  let _ = ssml
  let vid = match voice_id {
    Some(v) => v
    None => self.config.default_voice_id
  }
  let id = self.tts_id_gen.next()
  // Simulate audio generation
  // In reality, this would call the TTS API
  let char_count = text.length()
  // Estimate duration: ~150 words per minute, ~5 chars per word
  let words = char_count / 5
  let duration_ms = (words.to_double() / 150.0 * 60000.0 / rate).to_int()
  // Generate placeholder audio data (base64)
  let audio_data = "PLACEHOLDER_AUDIO_\{vid}_\{format.to_string()}"
  { id, audio_data, format, duration_ms, character_count: char_count }
}

///|
/// Transcribe audio (STT)
pub fn VoicePlugin::transcribe(
  self : VoicePlugin,
  audio_data : String,
  format? : AudioFormat = Wav,
  language? : String? = None,
  word_timestamps? : Bool = false,
  punctuation? : Bool = true,
  profanity_filter? : Bool = false,
) -> TranscriptionResult {
  let id = self.stt_id_gen.next()
  let lang = match language {
    Some(l) => l
    None => self.config.default_language
  }
  // Simulate transcription
  // In reality, this would call the STT API
  let text = "This is a simulated transcription of the audio input."
  let words : Array[TranscriptWord] = if word_timestamps {
    let word_list = text.split(" ")
    let result : Array[TranscriptWord] = []
    let mut start = 0
    for word_view in word_list {
      let word = word_view.to_string()
      let duration = word.length() * 100 // ~100ms per char
      result.push({
        word,
        start_ms: start,
        end_ms: start + duration,
        confidence: 0.95,
      })
      start = start + duration + 50 // 50ms gap
    }
    result
  } else {
    []
  }
  let duration_ms = if words.length() > 0 {
    words[words.length() - 1].end_ms
  } else {
    2000 // 2 seconds default
  }
  // Ignore unused variables
  let _ = audio_data
  let _ = format
  let _ = punctuation
  let _ = profanity_filter
  { id, text, language: lang, confidence: 0.92, words, duration_ms }
}

///|
/// Configure wake word detection
pub fn VoicePlugin::configure_wake_word(
  self : VoicePlugin,
  phrases : Array[String],
  sensitivity? : Double = 0.5,
  timeout_seconds? : Int = 10,
  format? : AudioFormat = Pcm16,
) -> Unit {
  self.wake_word_config = Some({ phrases, sensitivity, timeout_seconds, format })
}

///|
/// Disable wake word detection
pub fn VoicePlugin::disable_wake_word(self : VoicePlugin) -> Unit {
  self.wake_word_config = None
}

///|
/// Start streaming session
pub fn VoicePlugin::start_streaming(
  self : VoicePlugin,
  format? : AudioFormat = Pcm16,
) -> String {
  let id = self.stream_id_gen.next()
  let session : StreamingSession = {
    id,
    active: true,
    format,
    audio_chunks: [],
    partial_transcripts: [],
    started_at: self.get_timestamp(),
  }
  self.sessions[id] = session
  id
}

///|
/// Add audio chunk to streaming session
pub fn VoicePlugin::add_audio_chunk(
  self : VoicePlugin,
  session_id : String,
  audio_chunk : String,
) -> String? {
  match self.sessions.get(session_id) {
    Some(session) =>
      if session.active {
        session.audio_chunks.push(audio_chunk)
        // Simulate partial transcript
        if session.audio_chunks.length() % 5 == 0 {
          let partial = "Partial transcript \{session.audio_chunks.length() / 5}..."
          session.partial_transcripts.push(partial)
          Some(partial)
        } else {
          None
        }
      } else {
        None
      }
    None => None
  }
}

///|
/// End streaming session and get final transcript
pub fn VoicePlugin::end_streaming(
  self : VoicePlugin,
  session_id : String,
) -> TranscriptionResult? {
  match self.sessions.get(session_id) {
    Some(session) => {
      self.sessions.remove(session_id)
      // Combine all chunks and transcribe
      let combined_audio = session.audio_chunks.join("")
      Some(self.transcribe(combined_audio, format=session.format))
    }
    None => None
  }
}

///|
/// List available voices
pub fn VoicePlugin::list_voices(
  self : VoicePlugin,
  language? : String? = None,
  provider? : String? = None,
) -> Array[VoiceModel] {
  let results : Array[VoiceModel] = []
  for _, voice in self.voices {
    match language {
      Some(lang) => if voice.language != lang { continue }
      None => ()
    }
    match provider {
      Some(prov) => if voice.provider != prov { continue }
      None => ()
    }
    results.push(voice)
  }
  results
}

///|
/// Add custom voice
pub fn VoicePlugin::add_voice(self : VoicePlugin, voice : VoiceModel) -> Unit {
  self.voices[voice.id] = voice
}

///|
/// Convert voice model to JSON
fn voice_to_json(voice : VoiceModel) -> Json {
  {
    "id": voice.id,
    "name": voice.name,
    "language": voice.language,
    "gender": voice.gender,
    "provider": voice.provider,
  }
}

///|
/// Convert speech result to JSON
fn speech_result_to_json(result : SpeechResult) -> Json {
  {
    "id": result.id,
    "audio_data": result.audio_data,
    "format": result.format.to_string(),
    "duration_ms": Json::number(result.duration_ms.to_double()),
    "character_count": Json::number(result.character_count.to_double()),
  }
}

///|
/// Convert transcription result to JSON
fn transcription_result_to_json(result : TranscriptionResult) -> Json {
  let words_json : Array[Json] = []
  for word in result.words {
    words_json.push({
      "word": word.word,
      "start_ms": Json::number(word.start_ms.to_double()),
      "end_ms": Json::number(word.end_ms.to_double()),
      "confidence": Json::number(word.confidence),
    })
  }
  {
    "id": result.id,
    "text": result.text,
    "language": result.language,
    "confidence": Json::number(result.confidence),
    "words": Json::array(words_json),
    "duration_ms": Json::number(result.duration_ms.to_double()),
  }
}

///|
/// Handle JSON-RPC request
pub fn VoicePlugin::handle_request(
  self : VoicePlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  match request.rpc_method {
    "synthesize" => self.handle_synthesize(request)
    "transcribe" => self.handle_transcribe(request)
    "list_voices" => self.handle_list_voices(request)
    "add_voice" => self.handle_add_voice(request)
    "configure_wake_word" => self.handle_configure_wake_word(request)
    "disable_wake_word" => self.handle_disable_wake_word(request)
    "start_streaming" => self.handle_start_streaming(request)
    "add_audio_chunk" => self.handle_add_audio_chunk(request)
    "end_streaming" => self.handle_end_streaming(request)
    "get_wake_word_config" => self.handle_get_wake_word_config(request)
    _ => @interfaces.rpc_method_not_found(request.rpc_method, request.id)
  }
}

///|
fn VoicePlugin::handle_synthesize(
  self : VoicePlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let text = match @interfaces.rpc_require_string(request, "text") {
    Ok(t) => t
    Err(response) => return response
  }
  let voice_id = @interfaces.rpc_string_or_none(request, "voice_id")
  let format = match request.params {
    Some({ "format": String(f), .. }) =>
      match AudioFormat::from_string(f) {
        Some(fmt) => fmt
        None => Wav
      }
    _ => Wav
  }
  let rate = match request.params {
    Some({ "rate": Number(r, ..), .. }) => r
    _ => 1.0
  }
  let pitch = match request.params {
    Some({ "pitch": Number(p, ..), .. }) => p
    _ => 0.0
  }
  let volume_gain_db = match request.params {
    Some({ "volume_gain_db": Number(v, ..), .. }) => v
    _ => 0.0
  }
  let ssml = match request.params {
    Some({ "ssml": True, .. }) => true
    _ => false
  }
  let result = self.synthesize(
    text,
    voice_id~,
    format~,
    rate~,
    pitch~,
    volume_gain_db~,
    ssml~,
  )
  @interfaces.JsonRpcResponse::success(
    result=speech_result_to_json(result),
    id=request.id,
  )
}

///|
fn VoicePlugin::handle_transcribe(
  self : VoicePlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let audio_data = match @interfaces.rpc_require_string(request, "audio_data") {
    Ok(a) => a
    Err(response) => return response
  }
  let format_str = @interfaces.rpc_optional_string(request, "format", "wav")
  let format = match AudioFormat::from_string(format_str) {
    Some(fmt) => fmt
    None => Wav
  }
  let language = @interfaces.rpc_string_or_none(request, "language")
  let word_timestamps = match request.params {
    Some({ "word_timestamps": True, .. }) => true
    _ => false
  }
  let punctuation = match request.params {
    Some({ "punctuation": False, .. }) => false
    _ => true
  }
  let profanity_filter = match request.params {
    Some({ "profanity_filter": True, .. }) => true
    _ => false
  }
  let result = self.transcribe(
    audio_data,
    format~,
    language~,
    word_timestamps~,
    punctuation~,
    profanity_filter~,
  )
  @interfaces.JsonRpcResponse::success(
    result=transcription_result_to_json(result),
    id=request.id,
  )
}

///|
fn VoicePlugin::handle_list_voices(
  self : VoicePlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let language = @interfaces.rpc_string_or_none(request, "language")
  let provider = @interfaces.rpc_string_or_none(request, "provider")
  let voices = self.list_voices(language~, provider~)
  @interfaces.rpc_success_array("voices", voices, voice_to_json, request.id)
}

///|
fn VoicePlugin::handle_add_voice(
  self : VoicePlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let (id, name, language, gender, provider) = match request.params {
    Some(
      {
        "id": String(i),
        "name": String(n),
        "language": String(l),
        "gender": String(g),
        "provider": String(p),
        ..
      }
    ) => (i, n, l, g, p)
    _ =>
      return @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Missing required voice parameters",
        id=request.id,
      )
  }
  let voice : VoiceModel = { id, name, language, gender, provider }
  self.add_voice(voice)
  @interfaces.JsonRpcResponse::success(
    result={ "status": "added", "voice": voice_to_json(voice) },
    id=request.id,
  )
}

///|
fn VoicePlugin::handle_configure_wake_word(
  self : VoicePlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let phrases = @interfaces.rpc_string_array(request, "phrases")
  if phrases.length() == 0 {
    return @interfaces.rpc_invalid_params(
      "Missing or empty 'phrases' parameter",
      request.id,
    )
  }
  let sensitivity = @interfaces.rpc_optional_double(request, "sensitivity", 0.5)
  let timeout_seconds = @interfaces.rpc_optional_int(
    request, "timeout_seconds", 10,
  )
  let format_str = @interfaces.rpc_optional_string(request, "format", "pcm16")
  let format = match AudioFormat::from_string(format_str) {
    Some(fmt) => fmt
    None => Pcm16
  }
  self.configure_wake_word(phrases, sensitivity~, timeout_seconds~, format~)
  @interfaces.JsonRpcResponse::success(
    result={ "status": "configured" },
    id=request.id,
  )
}

///|
fn VoicePlugin::handle_disable_wake_word(
  self : VoicePlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  self.disable_wake_word()
  @interfaces.JsonRpcResponse::success(
    result={ "status": "disabled" },
    id=request.id,
  )
}

///|
fn VoicePlugin::handle_start_streaming(
  self : VoicePlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let format_str = @interfaces.rpc_optional_string(request, "format", "pcm16")
  let format = match AudioFormat::from_string(format_str) {
    Some(fmt) => fmt
    None => Pcm16
  }
  let session_id = self.start_streaming(format~)
  @interfaces.JsonRpcResponse::success(
    result={ "session_id": session_id, "status": "started" },
    id=request.id,
  )
}

///|
fn VoicePlugin::handle_add_audio_chunk(
  self : VoicePlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let session_id = match @interfaces.rpc_require_string(request, "session_id") {
    Ok(s) => s
    Err(response) => return response
  }
  let audio_chunk = match
    @interfaces.rpc_require_string(request, "audio_chunk") {
    Ok(a) => a
    Err(response) => return response
  }
  match self.add_audio_chunk(session_id, audio_chunk) {
    Some(partial) =>
      @interfaces.JsonRpcResponse::success(
        result={ "status": "added", "partial_transcript": partial },
        id=request.id,
      )
    None =>
      @interfaces.JsonRpcResponse::success(
        result={ "status": "added" },
        id=request.id,
      )
  }
}

///|
fn VoicePlugin::handle_end_streaming(
  self : VoicePlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  let session_id = match @interfaces.rpc_require_string(request, "session_id") {
    Ok(s) => s
    Err(response) => return response
  }
  match self.end_streaming(session_id) {
    Some(result) =>
      @interfaces.JsonRpcResponse::success(
        result=transcription_result_to_json(result),
        id=request.id,
      )
    None =>
      @interfaces.JsonRpcResponse::error(
        code=@interfaces.jsonrpc_error_invalid_params(),
        message="Session not found",
        id=request.id,
      )
  }
}

///|
fn VoicePlugin::handle_get_wake_word_config(
  self : VoicePlugin,
  request : @interfaces.JsonRpcRequest,
) -> @interfaces.JsonRpcResponse {
  match self.wake_word_config {
    Some(config) => {
      let phrases_json : Array[Json] = []
      for phrase in config.phrases {
        phrases_json.push(Json::string(phrase))
      }
      @interfaces.JsonRpcResponse::success(
        result={
          "enabled": Json::boolean(true),
          "phrases": Json::array(phrases_json),
          "sensitivity": Json::number(config.sensitivity),
          "timeout_seconds": Json::number(config.timeout_seconds.to_double()),
          "format": config.format.to_string(),
        },
        id=request.id,
      )
    }
    None =>
      @interfaces.JsonRpcResponse::success(
        result={ "enabled": Json::boolean(false) },
        id=request.id,
      )
  }
}
