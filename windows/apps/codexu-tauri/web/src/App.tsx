import { Dashboard } from './windows/Dashboard';
import { Settings } from './windows/Settings';
import { getCurrentWindow } from '@tauri-apps/api/window';

function App() {
  const label = getCurrentWindow().label;
  return label === 'settings' ? <Settings /> : <Dashboard />;
}

export default App;
