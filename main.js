const { app, BrowserWindow, ipcMain, screen } = require('electron');
const fs = require('fs');
const path = require('path');

let mainWindow;
let miniWindow;
let timerIntervalId = null;
let isPinned = false;
let pinAnchor = null;
let savePinAnchorTimer = null;

const mainWindowSize = { width: 360, height: 310 };
const miniWindowSize = { width: 230, height: 132 };

const timerState = {
  durationSeconds: 60,
  remainingSeconds: 60,
  isRunning: false,
  isFinished: false
};

function isValidPoint(point) {
  return point && Number.isFinite(point.x) && Number.isFinite(point.y);
}

function getWindowStatePath() {
  return path.join(app.getPath('userData'), 'window-state.json');
}

function loadPinAnchor() {
  try {
    const state = JSON.parse(fs.readFileSync(getWindowStatePath(), 'utf8'));

    if (isValidPoint(state.pinAnchor)) {
      pinAnchor = {
        x: Math.round(state.pinAnchor.x),
        y: Math.round(state.pinAnchor.y)
      };
    }
  } catch (_error) {
    pinAnchor = null;
  }
}

function savePinAnchor() {
  if (!isValidPoint(pinAnchor)) {
    return;
  }

  try {
    const statePath = getWindowStatePath();
    fs.mkdirSync(path.dirname(statePath), { recursive: true });
    fs.writeFileSync(statePath, `${JSON.stringify({ pinAnchor }, null, 2)}\n`);
  } catch (_error) {
    // Position persistence is best-effort.
  }
}

function schedulePinAnchorSave() {
  if (savePinAnchorTimer) {
    clearTimeout(savePinAnchorTimer);
  }

  savePinAnchorTimer = setTimeout(() => {
    savePinAnchorTimer = null;
    savePinAnchor();
  }, 120);
}

function rememberPinAnchorFromBounds(bounds, shouldPersist = true) {
  pinAnchor = {
    x: Math.round(bounds.x + (bounds.width / 2)),
    y: Math.round(bounds.y + (bounds.height / 2))
  };

  if (shouldPersist) {
    schedulePinAnchorSave();
  }
}

function rememberPinAnchorFromWindow(window, shouldPersist = true) {
  if (!window || window.isDestroyed()) {
    return;
  }

  rememberPinAnchorFromBounds(window.getBounds(), shouldPersist);
}

function clamp(value, min, max) {
  return Math.min(Math.max(value, min), Math.max(min, max));
}

function ensurePinAnchor() {
  if (isValidPoint(pinAnchor)) {
    return;
  }

  if (mainWindow && !mainWindow.isDestroyed()) {
    rememberPinAnchorFromWindow(mainWindow, false);
    return;
  }

  const workArea = screen.getPrimaryDisplay().workArea;
  pinAnchor = {
    x: Math.round(workArea.x + (workArea.width / 2)),
    y: Math.round(workArea.y + (workArea.height / 2))
  };
}

function getBoundsByPinAnchor(width, height) {
  ensurePinAnchor();

  const display = screen.getDisplayNearestPoint(pinAnchor);
  const workArea = display.workArea;
  const x = clamp(Math.round(pinAnchor.x - (width / 2)), workArea.x, workArea.x + workArea.width - width);
  const y = clamp(Math.round(pinAnchor.y - (height / 2)), workArea.y, workArea.y + workArea.height - height);

  return { x, y, width, height };
}

function positionWindowByPinAnchor(window) {
  if (!window || window.isDestroyed()) {
    return;
  }

  const bounds = window.getBounds();
  window.setBounds(getBoundsByPinAnchor(bounds.width, bounds.height), false);
}

function getTimerSnapshot() {
  return {
    durationSeconds: timerState.durationSeconds,
    remainingSeconds: timerState.remainingSeconds,
    isRunning: timerState.isRunning,
    isFinished: timerState.isFinished,
    isPinned
  };
}

function broadcastTimerState() {
  const snapshot = getTimerSnapshot();

  for (const window of [mainWindow, miniWindow]) {
    if (window && !window.isDestroyed()) {
      window.webContents.send('timer:update', snapshot);
    }
  }
}

function stopTimerInterval() {
  if (timerIntervalId) {
    clearInterval(timerIntervalId);
    timerIntervalId = null;
  }

  timerState.isRunning = false;
}

function finishTimer() {
  stopTimerInterval();
  timerState.remainingSeconds = 0;
  timerState.isFinished = true;
  broadcastTimerState();
}

function tickTimer() {
  if (timerState.remainingSeconds <= 1) {
    finishTimer();
    return;
  }

  timerState.remainingSeconds -= 1;
  broadcastTimerState();
}

function startTimer() {
  if (timerState.remainingSeconds <= 0 || timerState.isFinished) {
    timerState.remainingSeconds = timerState.durationSeconds;
  }

  if (timerState.remainingSeconds <= 0) {
    timerState.isFinished = false;
    broadcastTimerState();
    return;
  }

  stopTimerInterval();
  timerState.isRunning = true;
  timerState.isFinished = false;
  broadcastTimerState();
  timerIntervalId = setInterval(tickTimer, 1000);
}

function pauseTimer() {
  stopTimerInterval();
  broadcastTimerState();
}

function resetTimer() {
  stopTimerInterval();
  timerState.remainingSeconds = timerState.durationSeconds;
  timerState.isFinished = false;
  broadcastTimerState();
}

function applyMiniAlwaysOnTop() {
  if (!miniWindow || miniWindow.isDestroyed()) {
    return;
  }

  miniWindow.setAlwaysOnTop(true, 'floating');
  miniWindow.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });
}

function trackMiniWindowPosition() {
  if (!miniWindow || miniWindow.isDestroyed()) {
    return;
  }

  const rememberPosition = () => rememberPinAnchorFromWindow(miniWindow);
  miniWindow.on('move', rememberPosition);
  miniWindow.on('moved', rememberPosition);
}

function createMiniWindow() {
  if (miniWindow && !miniWindow.isDestroyed()) {
    positionWindowByPinAnchor(miniWindow);
    miniWindow.show();
    applyMiniAlwaysOnTop();
    return;
  }

  ensurePinAnchor();
  const miniBounds = getBoundsByPinAnchor(miniWindowSize.width, miniWindowSize.height);

  miniWindow = new BrowserWindow({
    x: miniBounds.x,
    y: miniBounds.y,
    width: miniBounds.width,
    height: miniBounds.height,
    minWidth: 210,
    minHeight: 120,
    resizable: false,
    frame: false,
    transparent: true,
    backgroundColor: '#00000000',
    show: false,
    alwaysOnTop: true,
    skipTaskbar: true,
    title: 'Countdown Mini',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  miniWindow.loadFile('mini.html');
  trackMiniWindowPosition();

  miniWindow.once('ready-to-show', () => {
    positionWindowByPinAnchor(miniWindow);
    applyMiniAlwaysOnTop();
    miniWindow.show();
    rememberPinAnchorFromWindow(miniWindow);
    broadcastTimerState();
  });

  miniWindow.on('closed', () => {
    miniWindow = null;
    if (isPinned) {
      isPinned = false;
      restoreMainWindow();
      broadcastTimerState();
    }
  });
}

function restoreMainWindow(shouldAnimate = true) {
  if (!mainWindow || mainWindow.isDestroyed()) {
    return;
  }

  if (mainWindow.isMinimized()) {
    mainWindow.restore();
  }

  positionWindowByPinAnchor(mainWindow);
  mainWindow.show();
  mainWindow.focus();

  if (shouldAnimate) {
    mainWindow.webContents.send('window:restored');
  }
}

function setPinned(nextPinned) {
  isPinned = Boolean(nextPinned);

  if (isPinned) {
    createMiniWindow();

    if (mainWindow && !mainWindow.isDestroyed()) {
      mainWindow.minimize();
    }
  } else {
    if (miniWindow && !miniWindow.isDestroyed()) {
      const windowToClose = miniWindow;
      miniWindow = null;
      windowToClose.hide();
      windowToClose.close();
    }

    restoreMainWindow();
  }

  broadcastTimerState();
  return isPinned;
}

function createMainWindow() {
  const initialBounds = isValidPoint(pinAnchor)
    ? getBoundsByPinAnchor(mainWindowSize.width, mainWindowSize.height)
    : mainWindowSize;

  mainWindow = new BrowserWindow({
    ...initialBounds,
    minWidth: 320,
    minHeight: 280,
    resizable: false,
    frame: false,
    transparent: true,
    backgroundColor: '#00000000',
    show: false,
    alwaysOnTop: false,
    skipTaskbar: false,
    title: 'Floating Countdown',
    trafficLightPosition: { x: 14, y: 14 },
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false
    }
  });

  mainWindow.loadFile('index.html');

  mainWindow.once('ready-to-show', () => {
    if (isValidPoint(pinAnchor)) {
      positionWindowByPinAnchor(mainWindow);
    }

    mainWindow.show();
    broadcastTimerState();
  });

  mainWindow.on('closed', () => {
    mainWindow = null;
    if (miniWindow && !miniWindow.isDestroyed()) {
      miniWindow.close();
    }
  });
}

app.whenReady().then(() => {
  loadPinAnchor();
  createMainWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
      createMainWindow();
    } else if (mainWindow && !isPinned) {
      restoreMainWindow();
    }
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') {
    app.quit();
  }
});

ipcMain.handle('timer:get', () => getTimerSnapshot());

ipcMain.handle('timer:setDuration', (_event, durationSeconds) => {
  const nextDuration = Math.max(0, Number.parseInt(durationSeconds, 10) || 0);
  timerState.durationSeconds = nextDuration;

  if (!timerState.isRunning) {
    timerState.remainingSeconds = nextDuration;
    timerState.isFinished = false;
  }

  broadcastTimerState();
  return getTimerSnapshot();
});

ipcMain.handle('timer:start', () => {
  startTimer();
  return getTimerSnapshot();
});

ipcMain.handle('timer:pause', () => {
  pauseTimer();
  return getTimerSnapshot();
});

ipcMain.handle('timer:reset', () => {
  resetTimer();
  return getTimerSnapshot();
});

ipcMain.handle('pin:get', () => isPinned);

ipcMain.handle('pin:set', (_event, nextPinned) => setPinned(nextPinned));

ipcMain.handle('pin:showMiniAfterAnimation', () => {
  isPinned = true;
  createMiniWindow();

  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.minimize();
  }

  broadcastTimerState();
  return getTimerSnapshot();
});

ipcMain.handle('pin:restoreAfterAnimation', () => setPinned(false));

ipcMain.handle('pin:hideMiniAndRestore', () => {
  if (miniWindow && !miniWindow.isDestroyed()) {
    miniWindow.hide();
  }

  return setPinned(false);
});

ipcMain.handle('window:close', () => {
  if (mainWindow && !mainWindow.isDestroyed()) {
    mainWindow.close();
  }
});
