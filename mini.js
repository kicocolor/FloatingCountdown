const miniCard = document.getElementById('miniCard');
const miniTimeDisplay = document.getElementById('miniTimeDisplay');
const miniStatusText = document.getElementById('miniStatusText');
const unpinButton = document.getElementById('unpinButton');
let isClosing = false;

function waitForAnimation(element, fallbackMs = 220) {
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
    return '专注中';
  }

  if (state.remainingSeconds > 0 && state.remainingSeconds !== state.durationSeconds) {
    return '已暂停';
  }

  return '准备开始';
}

function renderState(state) {
  miniTimeDisplay.textContent = formatTime(state.remainingSeconds);
  miniStatusText.textContent = getStatusText(state);
  miniCard.classList.toggle('finished', state.isFinished);
}

unpinButton.addEventListener('click', async () => {
  if (isClosing) {
    return;
  }

  isClosing = true;
  unpinButton.disabled = true;
  miniCard.classList.add('closing');
  await waitForAnimation(miniCard, 220);
  await window.floatingTimer.hideMiniAndRestore();
});

window.addEventListener('DOMContentLoaded', async () => {
  renderState(await window.floatingTimer.getTimer());
  miniCard.classList.add('opening');
  window.floatingTimer.onTimerUpdate(renderState);
});
