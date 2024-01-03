function injectLogger() {
  const startTime = Date.now();
  chrome.storage.local.set({ log: [], status: "stop" });
  let log = [];
  let recording = false;

  chrome.storage.onChanged.addListener(({ status }) => {
    console.log(status);
    switch (status?.newValue) {
      case "start":
        recording = true;
        log = [];
        break;
      case "stop":
        recording = false;
        chrome.storage.local.set({ log: log });
        break;
    }
  });

  // on mousemove update div contents to reflect mouse coords
  document.onmousemove = function (e) {
    if (recording) {
      log.push({
        x: e.clientX,
        y: e.clientY,
        time: Date.now() - startTime,
        type: "mousemove",
      });
    }
  };

  document.onmousedown = function (e) {
    if (recording) {
      log.push({
        x: e.clientX,
        y: e.clientY,
        time: Date.now() - startTime,
        type: "mousedown",
      });
    }
  };

  document.onmouseup = function (e) {
    if (recording) {
      log.push({
        x: e.clientX,
        y: e.clientY,
        time: Date.now() - startTime,
        type: "mouseup",
      });
    }
  };

  document.onkeydown = function (e) {
    if (recording) {
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
    }
  };

  document.onkeyup = function (e) {
    if (recording) {
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
    }
  };
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
