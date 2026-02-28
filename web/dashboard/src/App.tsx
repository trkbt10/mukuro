import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { Layout } from './components/layout/Layout';
import { ConnectionOverlay } from './components/layout/ConnectionOverlay';
import { Dashboard } from './pages/Dashboard';
import { Plugins } from './pages/Plugins';
import { PluginDetail } from './pages/PluginDetail';
import { Context } from './pages/Context';
import { ContextDetail } from './pages/ContextDetail';
import { Settings } from './pages/Settings';
import { SettingsDetail } from './pages/SettingsDetail';
import { Chat } from './pages/Chat';
import { History } from './pages/History';
import { MessageProviders } from './pages/MessageProviders';
import { ProviderDetail } from './pages/ProviderDetail';
import { Toaster } from './components/ui';

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route element={<Layout />}>
          <Route index element={<Navigate to="/dashboard" replace />} />
          <Route path="dashboard" element={<Dashboard />} />
          <Route path="chat" element={<Chat />} />
          <Route path="history" element={<History />} />
          <Route path="history/:date" element={<History />} />
          <Route path="history/:date/:sessionId" element={<History />} />
          <Route path="plugins" element={<Plugins />} />
          <Route path="plugins/:id" element={<PluginDetail />} />
          <Route path="context" element={<Context />} />
          <Route path="context/:name" element={<ContextDetail />} />
          <Route path="providers" element={<MessageProviders />} />
          <Route path="providers/:id" element={<ProviderDetail />} />
          <Route path="settings" element={<Settings />} />
          <Route path="settings/ai-providers/:providerName" element={<SettingsDetail />} />
          <Route path="settings/:section" element={<SettingsDetail />} />
        </Route>
      </Routes>
      <ConnectionOverlay />
      <Toaster />
    </BrowserRouter>
  );
}
