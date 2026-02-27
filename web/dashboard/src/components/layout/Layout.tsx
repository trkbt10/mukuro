import { Outlet } from 'react-router-dom';
import { GridLayout, type PanelLayoutConfig, type LayerDefinition } from 'react-panel-layout';
import { Sidebar } from './Sidebar';
import { Header } from './Header';
import { AppStatusBar } from './AppStatusBar';
import styles from './Layout.module.css';

const config: PanelLayoutConfig = {
  areas: [
    ['sidebar', 'main'],
    ['statusbar', 'statusbar'],
  ],
  columns: [
    { size: '200px', resizable: true, minSize: 160, maxSize: 300 },
    { size: '1fr' },
  ],
  rows: [
    { size: '1fr' },
    { size: '24px' },
  ],
};

export function Layout() {
  const layers: LayerDefinition[] = [
    {
      id: 'sidebar',
      gridArea: 'sidebar',
      scrollable: true,
      component: <Sidebar />,
    },
    {
      id: 'main',
      gridArea: 'main',
      component: (
        <div className={styles.main}>
          <Header />
          <main className={styles.content}>
            <Outlet />
          </main>
        </div>
      ),
    },
    {
      id: 'statusbar',
      gridArea: 'statusbar',
      component: <AppStatusBar />,
    },
  ];

  return <GridLayout config={config} layers={layers} root />;
}
