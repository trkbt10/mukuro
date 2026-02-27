import { useState, useEffect } from 'react';
import { Save, Trash2, FileText } from 'lucide-react';
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Button,
  Textarea,
  Badge,
  Loading,
} from '@/components/ui';
import { useContextFiles, useUpdateContextFile, useDeleteContextFile } from '@/hooks';

interface FileEditState {
  content: string;
  dirty: boolean;
}

const fileIcons: Record<string, string> = {
  soul: 'AI personality and core values',
  identity: 'AI identity and name',
  bootstrap: 'Base system instructions',
  agents: 'Workspace handbook and guidelines',
  tools: 'Local tools and environment configuration',
  user: 'User preferences and context',
};

const filePlaceholders: Record<string, string> = {
  soul: 'Define the AI personality, tone, and core values...\n\nExample:\nYou are a thoughtful and precise assistant. You value clarity and honesty.',
  identity: 'Define the AI identity and name...\n\nExample:\nYour name is Mukuro. You are a workspace AI assistant.',
  bootstrap: 'Base system instructions sent at the start of each session...\n\nExample:\nAlways respond in the user\'s language. Follow the project conventions.',
  agents: 'Workspace handbook and guidelines for agent behavior...\n\nExample:\n# Project Guidelines\n- Use TypeScript for all new code\n- Write tests for all features',
  tools: 'Local tools and environment configuration...\n\nExample:\n# Available Tools\n- Node.js v20\n- pnpm for package management',
  user: 'User preferences and personal context...\n\nExample:\nPreferred language: Japanese\nTimezone: Asia/Tokyo',
};

export function Context() {
  const { data: contextFiles, isLoading } = useContextFiles();
  const updateContextFile = useUpdateContextFile();
  const deleteContextFile = useDeleteContextFile();

  const [editStates, setEditStates] = useState<Record<string, FileEditState>>({});

  useEffect(() => {
    if (contextFiles && Object.keys(editStates).length === 0) {
      const states: Record<string, FileEditState> = {};
      for (const file of contextFiles) {
        states[file.name] = { content: file.content, dirty: false };
      }
      setEditStates(states);
    }
  }, [contextFiles, editStates]);

  const handleContentChange = (name: string, content: string) => {
    setEditStates((prev) => ({
      ...prev,
      [name]: { content, dirty: true },
    }));
  };

  const handleSave = (name: string) => {
    const state = editStates[name];
    if (!state) return;
    updateContextFile.mutate(
      { name, content: state.content },
      {
        onSuccess: () => {
          setEditStates((prev) => ({
            ...prev,
            [name]: { ...prev[name], dirty: false },
          }));
        },
      }
    );
  };

  const handleDelete = (name: string) => {
    deleteContextFile.mutate(name, {
      onSuccess: () => {
        setEditStates((prev) => ({
          ...prev,
          [name]: { content: '', dirty: false },
        }));
      },
    });
  };

  if (isLoading) {
    return <Loading message="Loading context files..." />;
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold text-text">Context</h1>
        <p className="text-text-secondary">
          Manage workspace context files that shape AI behavior. These files are loaded into the system prompt with priority ordering.
        </p>
      </div>

      <div className="grid gap-4 lg:grid-cols-2">
        {contextFiles?.map((file) => {
          const state = editStates[file.name];
          const content = state?.content ?? file.content;
          const dirty = state?.dirty ?? false;

          return (
            <Card key={file.name}>
              <CardHeader className="flex-row items-center justify-between pb-3">
                <div className="flex items-center gap-2 min-w-0">
                  <FileText className="h-4 w-4 text-text-muted shrink-0" />
                  <div className="min-w-0">
                    <CardTitle className="text-base">{file.filename}</CardTitle>
                    <p className="text-xs text-text-muted mt-0.5">
                      {fileIcons[file.name] ?? file.description}
                    </p>
                  </div>
                </div>
                <div className="flex items-center gap-2 shrink-0">
                  <Badge
                    variant={file.exists ? 'success' : 'secondary'}
                    size="sm"
                  >
                    {file.exists ? 'Active' : 'Empty'}
                  </Badge>
                </div>
              </CardHeader>
              <CardContent className="space-y-3 pt-0">
                <Textarea
                  value={content}
                  onChange={(e) => handleContentChange(file.name, e.target.value)}
                  rows={5}
                  placeholder={filePlaceholders[file.name] ?? 'Enter content...'}
                />
                <div className="flex justify-end gap-2">
                  {file.exists && (
                    <Button
                      variant="ghost"
                      size="sm"
                      onClick={() => handleDelete(file.name)}
                      loading={deleteContextFile.isPending}
                    >
                      <Trash2 className="h-4 w-4 text-red-500" />
                    </Button>
                  )}
                  <Button
                    size="sm"
                    onClick={() => handleSave(file.name)}
                    loading={updateContextFile.isPending}
                    disabled={!dirty}
                    leftIcon={<Save className="h-4 w-4" />}
                  >
                    Save
                  </Button>
                </div>
              </CardContent>
            </Card>
          );
        })}
      </div>
    </div>
  );
}
