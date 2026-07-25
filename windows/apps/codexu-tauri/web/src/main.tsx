import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import { applyAppTheme } from './utils/appTheme';
import './index.css';

applyAppTheme('system');

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
