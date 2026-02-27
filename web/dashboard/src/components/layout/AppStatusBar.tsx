import { StatusBar, StatusBarItem } from 'react-editor-ui';
import { useConnection } from '@/hooks/useConnection';

export function AppStatusBar() {
  const { data } = useConnection();
  const connected = data?.status === 'connected';

  return (
    <StatusBar>
      <StatusBarItem>mukuro v0.1.0</StatusBarItem>
      <StatusBarItem>
        {connected ? 'Connected' : 'Disconnected'}
      </StatusBarItem>
    </StatusBar>
  );
}
