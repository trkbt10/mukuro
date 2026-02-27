import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom';
import { Layout } from './components/layout/Layout';
import { ConnectionOverlay } from './components/layout/ConnectionOverlay';
import { Dashboard } from './pages/Dashboard';
import { Plugins } from './pages/Plugins';
import { PluginDetail } from './pages/PluginDetail';
import { Context } from './pages/Context';
import { Settings } from './pages/Settings';
import { MessageProviders } from './pages/MessageProviders';
import { Toaster } from './components/ui';

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route element={<Layout />}>
          <Route index element={<Navigate to="/dashboard" replace />} />
          <Route path="dashboard" element={<Dashboard />} />
          <Route path="plugins" element={<Plugins />} />
          <Route path="plugins/:id" element={<PluginDetail />} />
          <Route path="context" element={<Context />} />
          <Route path="providers" element={<MessageProviders />} />
          <Route path="settings" element={<Settings />} />
        </Route>
      </Routes>
      <ConnectionOverlay />
      <Toaster />
    </BrowserRouter>
  );
}
