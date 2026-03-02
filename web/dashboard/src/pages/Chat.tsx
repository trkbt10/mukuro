import { useRef, useEffect, useMemo, useCallback } from 'react';
import { MessageCircle, Plus, Trash2, AlertCircle, Paperclip, Mic, Upload } from 'lucide-react';
import { ChatInput, SendButton, FilePreview } from 'react-editor-ui/chat/ChatInput';
import { VoiceInput } from 'react-editor-ui/chat/VoiceInput';
import { IconButton } from '@/components/ui';
import { PageToolbar } from '@/components/layout/PageToolbar';
import {
  StatusBadge,
  ChatMessageDisplay,
  chatMessageToDisplay,
  defaultDisplayOptions,
  type ChatMessageDisplayHandle,
} from '@/components/chat';
import { useChat, useChatInput } from '@/hooks';
import { getClient } from '@/lib/client';
import styles from './Chat.module.css';

export function Chat() {
  const { chatId, messages, status, errorMsg, sendMessage, clearMessages } = useChat();
  const displayRef = useRef<ChatMessageDisplayHandle>(null);

  // Input state and handlers
  const chatInput = useChatInput({
    status,
    onSend: (text) => sendMessage(text),
  });

  // Convert messages for display
  const displayMessages = useMemo(
    () => messages.map(chatMessageToDisplay),
    [messages],
  );

  // Auto-scroll to bottom on new messages
  useEffect(() => {
    displayRef.current?.scrollToBottom();
  }, [messages.length, status]);

  // Toolbar actions
  const handleNewChat = useCallback(() => {
    clearMessages();
    window.location.reload();
  }, [clearMessages]);

  const handleClearHistory = useCallback(async () => {
    if (!chatId) return;
    try {
      await getClient().chat.deleteSession(chatId);
      clearMessages();
    } catch {
      // ignore
    }
  }, [chatId, clearMessages]);

  return (
    <div className={styles.page}>
      <PageToolbar
        title="Chat"
        titleBadge={<StatusBadge status={status} />}
        noPadding
        actions={
          <>
            <IconButton
              icon={<Trash2 size={14} />}
              aria-label="Clear history"
              onClick={handleClearHistory}
              variant="ghost"
              size="sm"
              disabled={messages.length === 0}
            />
            <IconButton
              icon={<Plus size={14} />}
              aria-label="New chat"
              onClick={handleNewChat}
              variant="ghost"
              size="sm"
            />
          </>
        }
      />

      {/* Messages */}
      <div className={styles.messageArea}>
        <ChatMessageDisplay.Root
          ref={displayRef}
          messages={displayMessages}
          height="100%"
          isThinking={chatInput.isThinking}
          displayOptions={defaultDisplayOptions}
        >
          <ChatMessageDisplay.Overlay visible={messages.length === 0 && !chatInput.isThinking}>
            <div className={styles.emptyState}>
              <MessageCircle className={styles.emptyIcon} size={48} />
              <span className={styles.emptyText}>
                Send a message to start chatting with the agent
              </span>
            </div>
          </ChatMessageDisplay.Overlay>
        </ChatMessageDisplay.Root>

        {status === 'error' && errorMsg && (
          <div className={styles.errorBanner}>
            <AlertCircle size={14} style={{ flexShrink: 0 }} />
            {errorMsg}
          </div>
        )}
      </div>

      {/* Input */}
      <div
        className={styles.inputArea}
        onDragOver={chatInput.handleDragOver}
        onDragLeave={chatInput.handleDragLeave}
        onDrop={chatInput.handleDrop}
      >
        <input
          ref={chatInput.fileInputRef}
          type="file"
          multiple
          onChange={chatInput.handleFileChange}
          className={styles.hiddenInput}
        />

        {chatInput.isVoiceMode ? (
          <VoiceInput
            variant="ghost"
            onResult={chatInput.handleVoiceResult}
            onCancel={chatInput.handleVoiceCancel}
            listeningText="Listening..."
          />
        ) : (
          <ChatInput.Root variant="ghost" disabled={chatInput.isDisabled}>
            {chatInput.attachedFiles.length > 0 && (
              <ChatInput.Badges>
                {chatInput.attachedFiles.map((file, i) => (
                  <FilePreview
                    key={`${file.name}-${i}`}
                    file={file}
                    onRemove={() => chatInput.removeFile(i)}
                  />
                ))}
              </ChatInput.Badges>
            )}

            <ChatInput.Content>
              <textarea
                ref={chatInput.textareaRef}
                className={styles.chatInput}
                value={chatInput.input}
                onChange={chatInput.handleInputChange}
                onKeyDown={chatInput.handleKeyDown}
                onCompositionStart={chatInput.handleCompositionStart}
                onCompositionEnd={chatInput.handleCompositionEnd}
                placeholder={chatInput.placeholder}
                rows={1}
                disabled={chatInput.isDisabled}
              />
            </ChatInput.Content>

            <ChatInput.Overlay visible={chatInput.isDragging}>
              <div className={styles.dropOverlay}>
                <Upload size={32} />
                <span>Drop files here</span>
              </div>
            </ChatInput.Overlay>

            <ChatInput.Toolbar style={{ justifyContent: 'space-between' }}>
              <div className={styles.toolbarLeft}>
                <button
                  type="button"
                  className={styles.toolbarBtn}
                  onClick={chatInput.openFilePicker}
                  disabled={chatInput.isDisabled}
                  aria-label="Attach files"
                >
                  <Paperclip size={18} />
                </button>
                <button
                  type="button"
                  className={styles.toolbarBtn}
                  onClick={chatInput.startVoiceMode}
                  disabled={chatInput.isDisabled}
                  aria-label="Voice input"
                >
                  <Mic size={18} />
                </button>
              </div>
              <SendButton
                canSend={chatInput.canSend}
                isLoading={chatInput.isThinking}
                onClick={chatInput.handleSend}
              />
            </ChatInput.Toolbar>
          </ChatInput.Root>
        )}
      </div>
    </div>
  );
}
