import { useState, useCallback } from 'react';

export function useEditMode() {
  const [isEditing, setEditing] = useState(false);

  const enterEditMode = useCallback(() => setEditing(true), []);
  const exitEditMode = useCallback(() => setEditing(false), []);
  const toggleEditMode = useCallback(() => setEditing((v) => !v), []);

  return { isEditing, enterEditMode, exitEditMode, toggleEditMode };
}
