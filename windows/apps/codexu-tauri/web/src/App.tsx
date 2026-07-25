import { Dashboard } from './windows/Dashboard';
import { Settings } from './windows/Settings';
import { getCurrentWindow } from '@tauri-apps/api/window';
import React from 'react';

interface ErrorBoundaryState {
  hasError: boolean;
  error: Error | null;
}

class AppErrorBoundary extends React.Component<
  { children?: React.ReactNode },
  ErrorBoundaryState
> {
  state: ErrorBoundaryState = { hasError: false, error: null };

  static getDerivedStateFromError(error: Error): ErrorBoundaryState {
    return { hasError: true, error };
  }

  componentDidCatch(error: Error, info: React.ErrorInfo) {
    console.error('[AppErrorBoundary] Runtime error:', error, info);
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="h-screen p-4 bg-transparent text-primary box-border">
          <div className="mx-auto max-w-2xl glass-panel p-4">
            <h2 className="text-lg font-semibold mb-2">Application error</h2>
            <pre className="text-sm whitespace-pre-wrap break-words bg-surface-inset rounded-lg border border-theme p-3">
            {(this.state.error && this.state.error.message) || 'Unknown error'}
            </pre>
          <button
            onClick={() => window.location.reload()}
            className="mt-3 px-3 py-2 rounded-full glass-button-solid text-sm"
          >
            Reload
          </button>
          </div>
        </div>
      );
    }

    return this.props.children as React.ReactElement;
  }
}

function getWindowLabel() {
  try {
    return getCurrentWindow().label;
  } catch (error) {
    console.error('[App] Failed to read current window label:', error);
    return 'main';
  }
}

function App() {
  const label = getWindowLabel();
  return label === 'settings' ? <Settings /> : <Dashboard />;
}

export default function AppWithBoundary() {
  return (
    <AppErrorBoundary>
      <App />
    </AppErrorBoundary>
  );
}
