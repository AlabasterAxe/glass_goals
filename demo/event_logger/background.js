function injectLogger() {
  const startTime = Date.now();
  const log = []

  // on mousemove update div contents to reflect mouse coords
  document.onmousemove = function (e) {
    log.push({
      x: e.clientX,
      y: e.clientY,
      time: Date.now() - startTime,
      type: "mousemove",
    });
  };

  document.onclick = function (e) {
    log.push({
      x: e.clientX,
      y: e.clientY,
      time: Date.now() - startTime,
      type: "click",
    });
  };

  document.onkeydown = function (e) {
    log.push({
      x: e.clientX,
      y: e.clientY,
      time: Date.now() - startTime,
      type: "keydown",
      payload: {
        key: e.key,
        code: e.code,
      },
    });
  };

  document.onkeyup = function (e) {
    log.push({
      x: e.clientX,
      y: e.clientY,
      time: Date.now() - startTime,
      type: "keyup",
      payload: {
        key: e.key,
        code: e.code,
      },
    });
  };

  setInterval(()=>{
    chrome.storage.local.set({log: log});
  }, 10_000)
}

chrome.tabs.onUpdated.addListener(function (tabId, changeInfo, tab) {
  if (changeInfo.status == "complete") {
    if (tab.url.startsWith("http://localhost")) {
      chrome.scripting.executeScript({
        target: { tabId },
        function: injectLogger,
      });
    }
  }
});
