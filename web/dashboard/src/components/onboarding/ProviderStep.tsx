import { useState, useEffect, useMemo } from 'react';
import { Eye, EyeOff } from 'lucide-react';
import { Button, Input, Select, Toggle, Badge } from '@/components/ui';
import { useAiProviders, useUpdateAiProvider, useProviderModels } from '@/hooks';
import styles from './OnboardingWizard.module.css';

interface Props {
  onComplete: () => void;
}

export function ProviderStep({ onComplete }: Props) {
  const { data: providers } = useAiProviders();
  const updateProvider = useUpdateAiProvider();

  const [selected, setSelected] = useState('');
  const [apiKey, setApiKey] = useState('');
  const [showApiKey, setShowApiKey] = useState(false);
  const [defaultModel, setDefaultModel] = useState('');
  const [useResponsesApi, setUseResponsesApi] = useState(false);

  const { data: knownModels } = useProviderModels(selected);

  const provider = providers?.find((p) => p.name === selected);

  useEffect(() => {
    if (provider) {
      setDefaultModel(provider.default_model);
      setUseResponsesApi(provider.use_responses_api);
      setApiKey('');
      setShowApiKey(false);
    }
  }, [provider]);

  // Auto-select first provider if none selected
  useEffect(() => {
    if (!selected && providers && providers.length > 0) {
      setSelected(providers[0].name);
    }
  }, [selected, providers]);

  const modelOptions = useMemo(() => {
    const opts = (knownModels ?? []).map((m: string) => ({ value: m, label: m }));
    if (defaultModel && !opts.some((o) => o.value === defaultModel)) {
      opts.unshift({ value: defaultModel, label: defaultModel });
    }
    return opts;
  }, [knownModels, defaultModel]);

  const handleSave = () => {
    if (!selected) return;
    const update: Record<string, unknown> = {
      default_model: defaultModel,
      use_responses_api: useResponsesApi,
    };
    if (apiKey) {
      update.api_key = apiKey;
    }
    updateProvider.mutate(
      { name: selected, update },
      { onSuccess: onComplete },
    );
  };

  const canSave = selected && apiKey;

  return (
    <div>
      <h3 className={styles.stepTitle}>AI Provider</h3>
      <p className={styles.stepDesc}>
        Select a provider and enter your API key to connect to an LLM.
      </p>

      <div className={styles.providerGrid}>
        {providers?.map((p) => (
          <div
            key={p.name}
            className={`${styles.providerCard} ${selected === p.name ? styles.selected : ''}`}
            onClick={() => setSelected(p.name)}
          >
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
              <span className={styles.providerCardName}>{p.name}</span>
              {p.has_api_key && <Badge variant="success" size="sm">Key set</Badge>}
            </div>
            <span className={styles.providerCardModel}>{p.default_model}</span>
          </div>
        ))}
      </div>

      {selected && (
        <div className={styles.fields}>
          <div className={styles.apiKeyWrap}>
            <Input
              label="API Key"
              type={showApiKey ? 'text' : 'password'}
              value={apiKey}
              onChange={(v) => setApiKey(v)}
              placeholder={provider?.has_api_key ? '••••••••' : 'Enter your API key'}
            />
            <button
              type="button"
              className={styles.apiKeyToggle}
              onClick={() => setShowApiKey(!showApiKey)}
              aria-label={showApiKey ? 'Hide API key' : 'Show API key'}
            >
              {showApiKey
                ? <EyeOff style={{ width: 14, height: 14 }} />
                : <Eye style={{ width: 14, height: 14 }} />}
            </button>
          </div>

          {modelOptions.length > 0 ? (
            <Select
              label="Default Model"
              options={modelOptions}
              value={defaultModel}
              onChange={(v) => setDefaultModel(v)}
            />
          ) : (
            <Input
              label="Default Model"
              value={defaultModel}
              onChange={(v) => setDefaultModel(v)}
              placeholder="e.g., gpt-4o"
            />
          )}

          <Toggle
            checked={useResponsesApi}
            onChange={(checked) => setUseResponsesApi(checked)}
            label="Use Responses API"
            description="Use the OpenAI Responses API format instead of Chat Completions"
          />

          <div className={styles.saveRow}>
            <Button
              onClick={handleSave}
              loading={updateProvider.isPending}
              disabled={!canSave && !provider?.has_api_key}
            >
              {provider?.has_api_key ? 'Update & Continue' : 'Save & Continue'}
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}
