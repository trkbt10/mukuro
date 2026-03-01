import { useContextDataFile, useUpdateContextDataFile, useDeleteContextDataFile, useContextTemplate } from './useContext';
import { useEditableContent } from './useEditableContent';

export function useContextEditor(name: string) {
  const { data: file, isLoading } = useContextDataFile(name);
  const { data: template } = useContextTemplate(name);
  const updateFile = useUpdateContextDataFile();
  const deleteFile = useDeleteContextDataFile();

  const savedContent = file?.content ?? '';
  const fallbackContent = template?.content ?? '';

  const { content, setContent, isDirty, reset } = useEditableContent(savedContent, fallbackContent);

  const save = () => {
    updateFile.mutate({ name, content }, {
      onSuccess: reset,
    });
  };

  const clear = () => {
    deleteFile.mutate(name, {
      onSuccess: reset,
    });
  };

  const resetToTemplate = () => {
    setContent(fallbackContent);
  };

  return {
    content,
    setContent,
    isDirty,
    isLoading,
    file,
    template,
    save,
    clear,
    resetToTemplate,
    isSaving: updateFile.isPending,
    isClearing: deleteFile.isPending,
  };
}
