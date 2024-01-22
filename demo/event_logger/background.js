function injectLogger() {
  chrome.storage.local.set({ log: [], status: "stop" });
  let startTime = Date.now();
  let log = [];
  let recording = false;

  chrome.storage.onChanged.addListener(({ status }) => {
    console.log(status);
    switch (status?.newValue) {
      case "start":
        startTime = Date.now();
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

  document.onclick = function (e) {
    if (recording) {
      log.push({
        x: e.clientX,
        y: e.clientY,
        time: Date.now() - startTime,
        type: "click",
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

let injected = false;

chrome.tabs.onUpdated.addListener(function (tabId, changeInfo, tab) {
  console.log('running');
  console.log(changeInfo);
  if (changeInfo.status == "complete") {
    if (tab.url.startsWith("http://localhost:52222") && !injected) {
      chrome.scripting.executeScript({
        target: { tabId },
        function: injectLogger,
      });
      injected = true;
    }
  }
});
