import { useState, useEffect } from 'react';
import { Save, Eye, EyeOff } from 'lucide-react';
import {
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Button,
  Input,
  Select,
  Toggle,
  Loading,
  Badge,
} from '@/components/ui';
import {
  useAllSettings,
  useUpdateRetrySettings,
  useUpdateAgentSettings,
  useUpdateModelSettings,
  useUpdateThinkingSettings,
  useProviders,
  useUpdateProvider,
} from '@/hooks';
import type { ThinkingLevel } from '@mukuro/client';

const thinkingLevelOptions = [
  { value: 'off', label: 'Off' },
  { value: 'minimal', label: 'Minimal' },
  { value: 'low', label: 'Low' },
  { value: 'medium', label: 'Medium' },
  { value: 'high', label: 'High' },
  { value: 'xhigh', label: 'Extra High' },
];

export function Settings() {
  const { data: settings, isLoading } = useAllSettings();
  const { data: providers } = useProviders();

  const updateRetry = useUpdateRetrySettings();
  const updateAgent = useUpdateAgentSettings();
  const updateModel = useUpdateModelSettings();
  const updateThinking = useUpdateThinkingSettings();
  const updateProvider = useUpdateProvider();

  // Retry settings state
  const [maxRetries, setMaxRetries] = useState(3);
  const [initialBackoff, setInitialBackoff] = useState(1000);
  const [maxBackoff, setMaxBackoff] = useState(30000);
  const [backoffMultiplier, setBackoffMultiplier] = useState(2.0);
  const [retryDirty, setRetryDirty] = useState(false);

  // Agent settings state
  const [maxIterations, setMaxIterations] = useState(10);
  const [timeoutMs, setTimeoutMs] = useState(60000);
  const [agentDirty, setAgentDirty] = useState(false);

  // Model settings state
  const [modelName, setModelName] = useState('');
  const [temperature, setTemperature] = useState('');
  const [maxTokens, setMaxTokens] = useState('');
  const [modelDirty, setModelDirty] = useState(false);

  // Thinking settings state
  const [thinkingEnabled, setThinkingEnabled] = useState(false);
  const [thinkingLevel, setThinkingLevel] = useState<ThinkingLevel>('medium');
  const [budgetTokens, setBudgetTokens] = useState('');
  const [thinkingDirty, setThinkingDirty] = useState(false);

  // Provider settings state
  const [selectedProvider, setSelectedProvider] = useState<string | null>(null);
  const [providerApiKey, setProviderApiKey] = useState('');
  const [showApiKey, setShowApiKey] = useState(false);

  // Initialize state when data loads
  useEffect(() => {
    if (settings) {
      setMaxRetries(settings.retry.max_retries);
      setInitialBackoff(settings.retry.initial_backoff_ms);
      setMaxBackoff(settings.retry.max_backoff_ms);
      setBackoffMultiplier(settings.retry.backoff_multiplier);

      setMaxIterations(settings.agent.max_iterations);
      setTimeoutMs(settings.agent.timeout_ms);

      setModelName(settings.model.model_name);
      setTemperature(
        settings.model.temperature !== null
          ? String(settings.model.temperature)
          : ''
      );
      setMaxTokens(
        settings.model.max_tokens !== null
          ? String(settings.model.max_tokens)
          : ''
      );
    }
  }, [settings]);

  const handleSaveRetry = () => {
    updateRetry.mutate(
      {
        max_retries: maxRetries,
        initial_backoff_ms: initialBackoff,
        max_backoff_ms: maxBackoff,
        backoff_multiplier: backoffMultiplier,
      },
      { onSuccess: () => setRetryDirty(false) }
    );
  };

  const handleSaveAgent = () => {
    updateAgent.mutate(
      {
        max_iterations: maxIterations,
        timeout_ms: timeoutMs,
      },
      { onSuccess: () => setAgentDirty(false) }
    );
  };

  const handleSaveModel = () => {
    updateModel.mutate(
      {
        model_name: modelName,
        temperature: temperature ? parseFloat(temperature) : null,
        max_tokens: maxTokens ? parseInt(maxTokens, 10) : null,
      },
      { onSuccess: () => setModelDirty(false) }
    );
  };

  const handleSaveThinking = () => {
    updateThinking.mutate(
      {
        enabled: thinkingEnabled,
        level: thinkingLevel,
        budget_tokens: budgetTokens ? parseInt(budgetTokens, 10) : null,
      },
      { onSuccess: () => setThinkingDirty(false) }
    );
  };

  const handleSaveProviderKey = () => {
    if (!selectedProvider) return;
    updateProvider.mutate(
      {
        name: selectedProvider,
        update: { api_key: providerApiKey },
      },
      {
        onSuccess: () => {
          setProviderApiKey('');
          setSelectedProvider(null);
        },
      }
    );
  };

  if (isLoading) {
    return <Loading message="Loading settings..." />;
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-2xl font-semibold text-text">Settings</h1>
        <p className="text-text-secondary">Configure your mukuro instance</p>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <Card>
          <CardHeader className="flex-row items-center justify-between">
            <CardTitle>Retry Settings</CardTitle>
            <Button
              size="sm"
              onClick={handleSaveRetry}
              loading={updateRetry.isPending}
              disabled={!retryDirty}
              leftIcon={<Save className="h-4 w-4" />}
            >
              Save
            </Button>
          </CardHeader>
          <CardContent className="space-y-4">
            <Input
              label="Max Retries"
              type="number"
              value={maxRetries}
              onChange={(e) => {
                setMaxRetries(parseInt(e.target.value, 10) || 0);
                setRetryDirty(true);
              }}
              min={0}
              max={10}
            />
            <Input
              label="Initial Backoff (ms)"
              type="number"
              value={initialBackoff}
              onChange={(e) => {
                setInitialBackoff(parseInt(e.target.value, 10) || 0);
                setRetryDirty(true);
              }}
              min={100}
            />
            <Input
              label="Max Backoff (ms)"
              type="number"
              value={maxBackoff}
              onChange={(e) => {
                setMaxBackoff(parseInt(e.target.value, 10) || 0);
                setRetryDirty(true);
              }}
              min={1000}
            />
            <Input
              label="Backoff Multiplier"
              type="number"
              step="0.1"
              value={backoffMultiplier}
              onChange={(e) => {
                setBackoffMultiplier(parseFloat(e.target.value) || 1);
                setRetryDirty(true);
              }}
              min={1}
              max={5}
            />
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex-row items-center justify-between">
            <CardTitle>Agent Settings</CardTitle>
            <Button
              size="sm"
              onClick={handleSaveAgent}
              loading={updateAgent.isPending}
              disabled={!agentDirty}
              leftIcon={<Save className="h-4 w-4" />}
            >
              Save
            </Button>
          </CardHeader>
          <CardContent className="space-y-4">
            <Input
              label="Max Iterations"
              type="number"
              value={maxIterations}
              onChange={(e) => {
                setMaxIterations(parseInt(e.target.value, 10) || 1);
                setAgentDirty(true);
              }}
              min={1}
              max={100}
            />
            <Input
              label="Timeout (ms)"
              type="number"
              value={timeoutMs}
              onChange={(e) => {
                setTimeoutMs(parseInt(e.target.value, 10) || 1000);
                setAgentDirty(true);
              }}
              min={1000}
            />
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex-row items-center justify-between">
            <CardTitle>Model Settings</CardTitle>
            <Button
              size="sm"
              onClick={handleSaveModel}
              loading={updateModel.isPending}
              disabled={!modelDirty}
              leftIcon={<Save className="h-4 w-4" />}
            >
              Save
            </Button>
          </CardHeader>
          <CardContent className="space-y-4">
            <Input
              label="Model Name"
              value={modelName}
              onChange={(e) => {
                setModelName(e.target.value);
                setModelDirty(true);
              }}
              placeholder="e.g., claude-3-5-sonnet-20241022"
            />
            <Input
              label="Temperature"
              type="number"
              step="0.1"
              value={temperature}
              onChange={(e) => {
                setTemperature(e.target.value);
                setModelDirty(true);
              }}
              placeholder="0.0 - 1.0"
              min={0}
              max={1}
            />
            <Input
              label="Max Tokens"
              type="number"
              value={maxTokens}
              onChange={(e) => {
                setMaxTokens(e.target.value);
                setModelDirty(true);
              }}
              placeholder="e.g., 4096"
            />
          </CardContent>
        </Card>

        <Card>
          <CardHeader className="flex-row items-center justify-between">
            <CardTitle>Thinking Settings</CardTitle>
            <Button
              size="sm"
              onClick={handleSaveThinking}
              loading={updateThinking.isPending}
              disabled={!thinkingDirty}
              leftIcon={<Save className="h-4 w-4" />}
            >
              Save
            </Button>
          </CardHeader>
          <CardContent className="space-y-4">
            <Toggle
              checked={thinkingEnabled}
              onChange={(checked) => {
                setThinkingEnabled(checked);
                setThinkingDirty(true);
              }}
              label="Enable Thinking"
              description="Allow the model to think before responding"
            />
            <Select
              label="Thinking Level"
              options={thinkingLevelOptions}
              value={thinkingLevel}
              onChange={(e) => {
                setThinkingLevel(e.target.value as ThinkingLevel);
                setThinkingDirty(true);
              }}
              disabled={!thinkingEnabled}
            />
            <Input
              label="Budget Tokens"
              type="number"
              value={budgetTokens}
              onChange={(e) => {
                setBudgetTokens(e.target.value);
                setThinkingDirty(true);
              }}
              placeholder="Optional token budget"
              disabled={!thinkingEnabled}
            />
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Providers</CardTitle>
        </CardHeader>
        <CardContent>
          {providers && providers.length > 0 ? (
            <div className="space-y-4">
              {providers.map((provider) => (
                <div
                  key={provider.name}
                  className="border rounded-lg p-4 space-y-3"
                >
                  <div className="flex items-center justify-between">
                    <div>
                      <span className="font-medium text-text">
                        {provider.name}
                      </span>
                      <p className="text-sm text-text-secondary">
                        {provider.default_model}
                      </p>
                    </div>
                    <Badge
                      variant={provider.has_api_key ? 'success' : 'warning'}
                    >
                      {provider.has_api_key ? 'Configured' : 'No API Key'}
                    </Badge>
                  </div>

                  {selectedProvider === provider.name ? (
                    <div className="space-y-2">
                      <Input
                        label="API Key"
                        type={showApiKey ? 'text' : 'password'}
                        value={providerApiKey}
                        onChange={(e) => setProviderApiKey(e.target.value)}
                        placeholder="Enter API key"
                        rightElement={
                          <button
                            type="button"
                            onClick={() => setShowApiKey(!showApiKey)}
                            className="focus:outline-none"
                          >
                            {showApiKey ? (
                              <EyeOff className="h-4 w-4" />
                            ) : (
                              <Eye className="h-4 w-4" />
                            )}
                          </button>
                        }
                      />
                      <div className="flex justify-end gap-2">
                        <Button
                          variant="secondary"
                          size="sm"
                          onClick={() => {
                            setSelectedProvider(null);
                            setProviderApiKey('');
                          }}
                        >
                          Cancel
                        </Button>
                        <Button
                          size="sm"
                          onClick={handleSaveProviderKey}
                          loading={updateProvider.isPending}
                          disabled={!providerApiKey}
                        >
                          Save
                        </Button>
                      </div>
                    </div>
                  ) : (
                    <Button
                      variant="secondary"
                      size="sm"
                      onClick={() => setSelectedProvider(provider.name)}
                    >
                      Update API Key
                    </Button>
                  )}
                </div>
              ))}
            </div>
          ) : (
            <p className="text-center text-text-secondary py-8">
              No providers configured
            </p>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
