const timerCard = document.querySelector('.timer-card');
const timeDisplay = document.getElementById('timeDisplay');
const statusText = document.getElementById('statusText');
const minutesInput = document.getElementById('minutesInput');
const secondsInput = document.getElementById('secondsInput');
const startPauseButton = document.getElementById('startPauseButton');
const resetButton = document.getElementById('resetButton');
const pinButton = document.getElementById('pinButton');
const closeButton = document.getElementById('closeButton');

let currentState = null;
let isTransitioningPin = false;

function waitForAnimation(element, fallbackMs = 240) {
  return new Promise((resolve) => {
    let isResolved = false;

    const finish = () => {
      if (isResolved) {
        return;
      }

      isResolved = true;
      element.removeEventListener('animationend', finish);
      resolve();
    };

    element.addEventListener('animationend', finish, { once: true });
    window.setTimeout(finish, fallbackMs);
  });
}

async function playCardAnimation(className, fallbackMs = 240) {
  timerCard.classList.remove('pinning-out', 'restoring-in');
  timerCard.classList.add(className);
  await waitForAnimation(timerCard, fallbackMs);
  timerCard.classList.remove(className);
}

function clampInteger(value, min, max) {
  const number = Number.parseInt(value, 10);

  if (Number.isNaN(number)) {
    return min;
  }

  return Math.min(Math.max(number, min), max);
}

function normalizeInputs() {
  minutesInput.value = String(clampInteger(minutesInput.value, 0, 9999));
  secondsInput.value = String(clampInteger(secondsInput.value, 0, 59));
}

function getInputSeconds() {
  const minutes = clampInteger(minutesInput.value, 0, 9999);
  const seconds = clampInteger(secondsInput.value, 0, 59);
  return (minutes * 60) + seconds;
}

function setInputsFromDuration(durationSeconds) {
  const safeSeconds = Math.max(0, durationSeconds);
  const minutes = Math.floor(safeSeconds / 60);
  const seconds = safeSeconds % 60;
  minutesInput.value = String(minutes);
  secondsInput.value = String(seconds);
}

function formatTime(totalSeconds) {
  const safeSeconds = Math.max(0, totalSeconds);
  const minutes = Math.floor(safeSeconds / 60);
  const seconds = safeSeconds % 60;

  return `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
}

function getStatusText(state) {
  if (state.isFinished) {
    return '时间到';
  }

  if (state.isRunning) {
    return '倒计时运行中';
  }

  if (state.remainingSeconds > 0 && state.remainingSeconds !== state.durationSeconds) {
    return '已暂停';
  }

  if (state.durationSeconds > 0) {
    return '设置分钟和秒数后点击开始';
  }

  return '请先设置大于 0 的时间';
}

function renderState(state) {
  currentState = state;
  timeDisplay.textContent = formatTime(state.remainingSeconds);
  statusText.textContent = getStatusText(state);
  timerCard.classList.toggle('finished', state.isFinished);
  startPauseButton.textContent = state.isRunning ? '暂停' : state.remainingSeconds > 0 && state.remainingSeconds !== state.durationSeconds ? '继续' : '开始';
  pinButton.classList.toggle('active', state.isPinned);
  pinButton.setAttribute('aria-pressed', String(state.isPinned));
  pinButton.textContent = state.isPinned ? 'Pinned' : 'Pin';
  pinButton.title = state.isPinned ? '时间窗已开启' : '开启时间悬浮窗';
}

async function syncDurationFromInputs() {
  normalizeInputs();
  const snapshot = await window.floatingTimer.setDuration(getInputSeconds());
  renderState(snapshot);
}

function shouldSyncInputImmediately() {
  return !currentState || (!currentState.isRunning && !currentState.isFinished);
}

startPauseButton.addEventListener('click', async () => {
  if (currentState?.isRunning) {
    renderState(await window.floatingTimer.pauseTimer());
    return;
  }

  if (!currentState || currentState.remainingSeconds <= 0 || currentState.isFinished) {
    await syncDurationFromInputs();
  }

  renderState(await window.floatingTimer.startTimer());
});

resetButton.addEventListener('click', async () => {
  await syncDurationFromInputs();
  renderState(await window.floatingTimer.resetTimer());
});

for (const input of [minutesInput, secondsInput]) {
  input.addEventListener('change', async () => {
    normalizeInputs();

    if (shouldSyncInputImmediately()) {
      await syncDurationFromInputs();
    }
  });

  input.addEventListener('blur', async () => {
    normalizeInputs();

    if (shouldSyncInputImmediately()) {
      await syncDurationFromInputs();
    }
  });
}

pinButton.addEventListener('click', async () => {
  if (isTransitioningPin) {
    return;
  }

  isTransitioningPin = true;
  pinButton.disabled = true;

  try {
    if (currentState?.isPinned) {
      const isPinned = await window.floatingTimer.setPinned(false);
      renderState({ ...currentState, isPinned });
      return;
    }

    renderState({ ...currentState, isPinned: true });
    await playCardAnimation('pinning-out', 260);
    renderState(await window.floatingTimer.showMiniAfterAnimation());
  } finally {
    pinButton.disabled = false;
    isTransitioningPin = false;
  }
});

closeButton.addEventListener('click', () => {
  window.floatingTimer.closeWindow();
});

window.addEventListener('DOMContentLoaded', async () => {
  const snapshot = await window.floatingTimer.getTimer();
  setInputsFromDuration(snapshot.durationSeconds);
  renderState(snapshot);
  window.floatingTimer.onTimerUpdate(renderState);
  window.floatingTimer.onWindowRestored(() => {
    playCardAnimation('restoring-in', 260);
  });
});
