const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('floatingTimer', {
  getTimer: () => ipcRenderer.invoke('timer:get'),
  setDuration: (durationSeconds) => ipcRenderer.invoke('timer:setDuration', durationSeconds),
  startTimer: () => ipcRenderer.invoke('timer:start'),
  pauseTimer: () => ipcRenderer.invoke('timer:pause'),
  resetTimer: () => ipcRenderer.invoke('timer:reset'),
  getPinned: () => ipcRenderer.invoke('pin:get'),
  setPinned: (isPinned) => ipcRenderer.invoke('pin:set', isPinned),
  showMiniAfterAnimation: () => ipcRenderer.invoke('pin:showMiniAfterAnimation'),
  restoreAfterAnimation: () => ipcRenderer.invoke('pin:restoreAfterAnimation'),
  hideMiniAndRestore: () => ipcRenderer.invoke('pin:hideMiniAndRestore'),
  closeWindow: () => ipcRenderer.invoke('window:close'),
  onWindowRestored: (callback) => {
    const listener = () => callback();
    ipcRenderer.on('window:restored', listener);
    return () => ipcRenderer.removeListener('window:restored', listener);
  },
  onTimerUpdate: (callback) => {
    const listener = (_event, snapshot) => callback(snapshot);
    ipcRenderer.on('timer:update', listener);
    return () => ipcRenderer.removeListener('timer:update', listener);
  }
});
