// Loads the app's JSX screens in order (transpiled with Babel), then exposes window.GymApp.
(async () => {
  const here = document.currentScript ? document.currentScript.src : location.href;
  const base = new URL('.', here);
  const wait = (test) => new Promise(r => { const t = setInterval(() => { if (test()) { clearInterval(t); r(); } }, 30); });
  await wait(() => window.React && window.ReactDOM && window.Babel && window.GymTrackerDesignSystem_9b15a7);
  for (const f of ['chrome.jsx','HomeScreen.jsx','ActiveWorkoutScreen.jsx','LibraryScreen.jsx','HistoryScreen.jsx','App.jsx']) {
    const src = await (await fetch(new URL(f, base))).text();
    const { code } = Babel.transform(src, { presets: ['react'], filename: f });
    (0, eval)(code);
  }
  class GymAppEl extends HTMLElement {
    connectedCallback(){ this.style.display='block'; this.style.height='100%'; this._root = ReactDOM.createRoot(this); this._root.render(React.createElement(window.GymApp)); }
    disconnectedCallback(){ this._root && this._root.unmount(); }
  }
  if (!customElements.get('gym-app')) customElements.define('gym-app', GymAppEl);
})();
