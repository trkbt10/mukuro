/**
 * Chat input state and handlers.
 * Manages text input, file attachments, voice mode, and drag-drop.
 */

import { useState, useRef, useCallback } from 'react';
import type { ChatStatus } from './useChat';

export interface UseChatInputOptions {
  status: ChatStatus;
  onSend: (text: string, files?: File[]) => void;
}

export function useChatInput({ status, onSend }: UseChatInputOptions) {
  const [input, setInput] = useState('');
  const [attachedFiles, setAttachedFiles] = useState<File[]>([]);
  const [isDragging, setIsDragging] = useState(false);
  const [isVoiceMode, setIsVoiceMode] = useState(false);

  const composingRef = useRef(false);
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Derived state
  const isDisabled =
    status === 'disconnected' ||
    status === 'connecting' ||
    status === 'auth_error';

  const isThinking = status === 'thinking';

  const canSend =
    (input.trim().length > 0 || attachedFiles.length > 0) &&
    !isThinking &&
    !isDisabled;

  const placeholder =
    status === 'auth_error'
      ? 'Authentication required — set MUKURO_AUTH_TOKEN'
      : status === 'disconnected'
        ? 'Disconnected from server...'
        : 'Type a message... (Enter to send, Shift+Enter for newline)';

  // Handlers
  const handleInputChange = useCallback(
    (e: React.ChangeEvent<HTMLTextAreaElement>) => {
      setInput(e.target.value);
      const el = e.target;
      el.style.height = 'auto';
      el.style.height = `${Math.min(el.scrollHeight, 140)}px`;
    },
    [],
  );

  const handleSend = useCallback(() => {
    const trimmed = input.trim();
    if (!trimmed || isThinking || isDisabled) return;
    onSend(trimmed, attachedFiles.length > 0 ? attachedFiles : undefined);
    setInput('');
    setAttachedFiles([]);
    if (textareaRef.current) {
      textareaRef.current.style.height = 'auto';
    }
  }, [input, isThinking, isDisabled, onSend, attachedFiles]);

  const handleKeyDown = useCallback(
    (e: React.KeyboardEvent) => {
      if (e.key === 'Enter' && !e.shiftKey && !composingRef.current) {
        e.preventDefault();
        handleSend();
      }
    },
    [handleSend],
  );

  const handleCompositionStart = useCallback(() => {
    composingRef.current = true;
  }, []);

  const handleCompositionEnd = useCallback(() => {
    composingRef.current = false;
  }, []);

  // File handlers
  const openFilePicker = useCallback(() => {
    fileInputRef.current?.click();
  }, []);

  const handleFileChange = useCallback(
    (e: React.ChangeEvent<HTMLInputElement>) => {
      const files = Array.from(e.target.files || []);
      setAttachedFiles((prev) => [...prev, ...files]);
      e.target.value = '';
    },
    [],
  );

  const removeFile = useCallback((index: number) => {
    setAttachedFiles((prev) => prev.filter((_, i) => i !== index));
  }, []);

  // Drag-drop handlers
  const handleDragOver = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(true);
  }, []);

  const handleDragLeave = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
  }, []);

  const handleDrop = useCallback((e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
    const files = Array.from(e.dataTransfer.files);
    setAttachedFiles((prev) => [...prev, ...files]);
  }, []);

  // Voice handlers
  const startVoiceMode = useCallback(() => {
    setIsVoiceMode(true);
  }, []);

  const handleVoiceResult = useCallback((text: string) => {
    setInput((prev) => (prev ? `${prev} ${text}` : text));
    setIsVoiceMode(false);
  }, []);

  const handleVoiceCancel = useCallback(() => {
    setIsVoiceMode(false);
  }, []);

  return {
    // State
    input,
    attachedFiles,
    isDragging,
    isVoiceMode,
    isDisabled,
    isThinking,
    canSend,
    placeholder,

    // Refs
    textareaRef,
    fileInputRef,

    // Text input handlers
    handleInputChange,
    handleKeyDown,
    handleCompositionStart,
    handleCompositionEnd,
    handleSend,

    // File handlers
    openFilePicker,
    handleFileChange,
    removeFile,

    // Drag-drop handlers
    handleDragOver,
    handleDragLeave,
    handleDrop,

    // Voice handlers
    startVoiceMode,
    handleVoiceResult,
    handleVoiceCancel,
  };
}
