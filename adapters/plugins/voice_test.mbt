///|
test "synthesize returns result" {
  let config = VoicePluginConfig::default(name="test")
  let plugin = VoicePlugin::new(config)
  let result = plugin.synthesize("Hello world")
  inspect(result.id.has_prefix("tts_"), content="true")
  inspect(result.character_count, content="11")
}

///|
test "transcribe returns result" {
  let config = VoicePluginConfig::default(name="test")
  let plugin = VoicePlugin::new(config)
  let result = plugin.transcribe("audio_data")
  inspect(result.id.has_prefix("stt_"), content="true")
}

///|
test "streaming session" {
  let config = VoicePluginConfig::default(name="test")
  let plugin = VoicePlugin::new(config)
  let session_id = plugin.start_streaming()
  inspect(session_id.has_prefix("stream_"), content="true")
  let _ = plugin.add_audio_chunk(session_id, "chunk1")
  match plugin.end_streaming(session_id) {
    Some(result) => inspect(result.id.has_prefix("stt_"), content="true")
    None => fail("Expected result")
  }
}

///|
test "list_voices returns defaults" {
  let config = VoicePluginConfig::default(name="test")
  let plugin = VoicePlugin::new(config)
  let voices = plugin.list_voices()
  inspect(voices.length() > 0, content="true")
}
