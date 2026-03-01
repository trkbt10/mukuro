import { useState, useEffect } from 'react';
import { useMutation } from '@tanstack/react-query';
import { Save, Check, Sparkles, PenLine } from 'lucide-react';
import { Button, Input, Textarea } from '@/components/ui';
import { useContextFiles, useUpdateContextFile } from '@/hooks';
import { fileDescriptions, filePlaceholders } from '@/lib/contextFiles';
import { getClient } from '@/lib/client';
import type { ContextFileName } from '@mukuro/client';
import styles from './OnboardingWizard.module.css';

interface Props {
  onComplete: () => void;
}

const TAB_ORDER: ContextFileName[] = ['soul', 'identity', 'user', 'agents', 'tools', 'bootstrap'];

const TAB_LABELS: Record<ContextFileName, string> = {
  soul: 'SOUL',
  identity: 'IDENTITY',
  user: 'USER',
  agents: 'AGENTS',
  tools: 'TOOLS',
  bootstrap: 'BOOTSTRAP',
};

// ── Interview answers ──

interface InterviewAnswers {
  userName: string;
  work: string;
  personality: string;
  notes: string;
}

// ── Component ──

export function WorkspaceStep({ onComplete }: Props) {
  const { data: contextFiles } = useContextFiles();
  const updateFile = useUpdateContextFile();
  const gen = useMutation({
    mutationFn: (answers: InterviewAnswers) =>
      getClient().onboard.generate({
        user_name: answers.userName,
        work: answers.work,
        personality: answers.personality,
        notes: answers.notes,
      }),
  });

  const [mode, setMode] = useState<'interview' | 'editor'>('interview');
  const [answers, setAnswers] = useState<InterviewAnswers>({
    userName: '',
    work: '',
    personality: '',
    notes: '',
  });
  const [activeTab, setActiveTab] = useState<ContextFileName>('soul');
  const [drafts, setDrafts] = useState<Partial<Record<ContextFileName, string>>>({});
  const [saved, setSaved] = useState<Set<ContextFileName>>(new Set());

  // Initialize drafts from fetched data (existing customized files)
  useEffect(() => {
    if (!contextFiles) return;
    const initial: Partial<Record<ContextFileName, string>> = {};
    for (const file of contextFiles) {
      if (file.exists && !file.is_default) {
        initial[file.name] = file.content;
      }
    }
    setDrafts((prev) => ({ ...initial, ...prev }));
  }, [contextFiles]);

  // When AI generation completes, populate drafts and switch to editor
  useEffect(() => {
    const d = gen.data;
    if (gen.isSuccess && d && Object.keys(d).length > 0) {
      setDrafts((prev) => ({ ...prev, ...d }));
      setMode('editor');
    }
  }, [gen.isSuccess, gen.data]);

  const handleGenerate = () => {
    gen.mutate(answers);
  };

  const canGenerate = answers.userName.trim() || answers.work.trim() || answers.personality.trim();

  // ── Editor logic ──
  const currentFile = contextFiles?.find((f) => f.name === activeTab);
  const currentDraft = drafts[activeTab] ?? '';
  const isDirty = currentDraft !== (currentFile?.exists && !currentFile.is_default ? currentFile.content : '');

  const handleDraftChange = (value: string) => {
    setDrafts((prev) => ({ ...prev, [activeTab]: value }));
  };

  const handleSave = () => {
    if (!currentDraft.trim()) return;
    updateFile.mutate(
      { name: activeTab, content: currentDraft },
      {
        onSuccess: () => {
          setSaved((prev) => new Set(prev).add(activeTab));
        },
      },
    );
  };

  const handleSaveAllAndContinue = async () => {
    // Save all non-empty drafts that haven't been saved yet
    const toSave = TAB_ORDER.filter(
      (name) => drafts[name]?.trim() && !saved.has(name),
    );
    if (toSave.length === 0) {
      onComplete();
      return;
    }
    for (const name of toSave) {
      updateFile.mutate(
        { name, content: drafts[name]! },
        {
          onSuccess: () => {
            setSaved((prev) => new Set(prev).add(name));
          },
        },
      );
    }
    // Small delay to let mutations settle, then continue
    setTimeout(onComplete, 500);
  };

  // ── Interview mode ──
  if (mode === 'interview') {
    return (
      <div>
        <h3 className={styles.stepTitle}>Workspace</h3>
        <p className={styles.stepDesc}>
          Answer a few questions and let your AI generate all context files for you.
        </p>

        <div className={styles.interviewHint}>
          Your AI will use these answers to generate SOUL.md, IDENTITY.md, USER.md, and more.
          You can review and edit everything afterward.
        </div>

        <div className={styles.interviewForm} style={{ marginTop: 'var(--mk-space-xl)' }}>
          <Input
            label="What should the AI call you?"
            placeholder="e.g., Alex, Boss, senpai..."
            value={answers.userName}
            onChange={(v) => setAnswers((p) => ({ ...p, userName: v }))}
          />
          <Input
            label="What do you do / what are your interests?"
            placeholder="e.g., Full-stack dev, writer, researcher..."
            value={answers.work}
            onChange={(v) => setAnswers((p) => ({ ...p, work: v }))}
          />
          <Input
            label="What personality should your AI have?"
            placeholder="e.g., Sharp & concise, warm & patient, chaotic gremlin..."
            value={answers.personality}
            onChange={(v) => setAnswers((p) => ({ ...p, personality: v }))}
          />
          <Textarea
            label="Anything else?"
            placeholder="Timezone, preferred language, tools you use, things to avoid..."
            value={answers.notes}
            onChange={(e) => setAnswers((p) => ({ ...p, notes: e.target.value }))}
            rows={3}
          />
        </div>

        <div className={styles.generateRow} style={{ marginTop: 'var(--mk-space-xl)' }}>
          <Button
            onClick={handleGenerate}
            disabled={!canGenerate}
            loading={gen.isPending}
            leftIcon={<Sparkles style={{ width: 14, height: 14 }} />}
          >
            Generate Files
          </Button>
          {gen.isPending && (
            <span className={styles.generateStatus}>
              Generating<span className={styles.generateDots}>...</span>
            </span>
          )}
          {gen.error && (
            <span className={styles.generateStatus} style={{ color: 'var(--mk-error)' }}>
              {gen.error instanceof Error ? gen.error.message : 'Generation failed'}
            </span>
          )}
        </div>

        <div className={styles.dividerRow}>
          <div className={styles.dividerLine} />
          <span className={styles.dividerText}>or</span>
          <div className={styles.dividerLine} />
        </div>

        <button className={styles.modeToggle} onClick={() => setMode('editor')}>
          <PenLine style={{ width: 12, height: 12, display: 'inline', verticalAlign: -2, marginRight: 4 }} />
          Write manually instead
        </button>

        <div className={styles.saveRow} style={{ marginTop: 'var(--mk-space-xl)', borderTop: '1px solid var(--mk-border-default)', paddingTop: 'var(--mk-space-lg)' }}>
          <Button variant="secondary" onClick={onComplete}>
            Skip for now
          </Button>
        </div>
      </div>
    );
  }

  // ── Editor mode ──
  return (
    <div>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 'var(--mk-space-xs)' }}>
        <h3 className={styles.stepTitle}>Workspace</h3>
        <button className={styles.modeToggle} onClick={() => setMode('interview')}>
          <Sparkles style={{ width: 12, height: 12, display: 'inline', verticalAlign: -2, marginRight: 4 }} />
          Re-generate with AI
        </button>
      </div>
      <p className={styles.stepDesc}>
        Review and edit your context files. Save each file, or save all and continue.
      </p>

      <div className={styles.tabBar}>
        {TAB_ORDER.map((name) => (
          <button
            key={name}
            className={`${styles.tab} ${activeTab === name ? styles.activeTab : ''} ${saved.has(name) ? styles.savedTab : ''}`}
            onClick={() => setActiveTab(name)}
          >
            {saved.has(name) && <Check style={{ width: 10, height: 10, marginRight: 4, display: 'inline' }} />}
            {TAB_LABELS[name]}
          </button>
        ))}
      </div>

      <div className={styles.tabContent} key={activeTab}>
        <p className={styles.fileDesc}>
          {fileDescriptions[activeTab] ?? currentFile?.description ?? ''}
        </p>
        <div className={styles.textareaWrap}>
          <Textarea
            value={currentDraft}
            onChange={(e) => handleDraftChange(e.target.value)}
            rows={10}
            placeholder={filePlaceholders[activeTab] ?? 'Enter content...'}
          />
        </div>
        <div className={styles.saveRow}>
          {saved.has(activeTab) && <span className={styles.savedHint}>Saved</span>}
          <Button
            size="sm"
            onClick={handleSave}
            loading={updateFile.isPending}
            disabled={!isDirty && !currentDraft.trim()}
            leftIcon={<Save style={{ width: 12, height: 12 }} />}
          >
            Save
          </Button>
        </div>
      </div>

      <div className={styles.saveRow} style={{ marginTop: 'var(--mk-space-xl)', borderTop: '1px solid var(--mk-border-default)', paddingTop: 'var(--mk-space-lg)' }}>
        <Button onClick={handleSaveAllAndContinue} loading={updateFile.isPending}>
          Save All & Continue
        </Button>
      </div>
    </div>
  );
}
