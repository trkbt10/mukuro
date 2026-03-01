import { useState, useCallback } from 'react';

/**
 * Editable content with dirty tracking.
 * - null = not edited (shows saved or fallback)
 * - string = user has edited
 */
export function useEditableContent(savedContent: string, fallbackContent: string = '') {
  const [editedContent, setEditedContent] = useState<string | null>(null);

  const content = editedContent ?? (savedContent || fallbackContent);
  const isDirty = editedContent !== null && editedContent !== savedContent;

  const setContent = useCallback((value: string) => setEditedContent(value), []);
  const reset = useCallback(() => setEditedContent(null), []);

  return { content, setContent, isDirty, reset };
}
