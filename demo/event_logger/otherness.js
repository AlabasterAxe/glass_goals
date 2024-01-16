const saveButton = document.getElementById("save-button");

saveButton.onclick = async () => {
  const { log } = await chrome.storage.local.get(["log"]);
  const blob = new Blob([JSON.stringify(log)]);
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = "mouse-events.json";
  link.click();
};

let recording = false;

chrome.storage.local.get(['status']).then(({status})=>{
  if (status === 'start') {
    recording = true;
    recordButton.innerText = "Stop";
  }
})

const recordButton = document.getElementById("record-button");
recordButton.onclick = () => {
  if (recording) {
    chrome.storage.local.set({ status: 'stop' });
    recordButton.innerText = "Record";
  } else {
    chrome.storage.local.set({ status: 'start' });
    recordButton.innerText = "Stop";
  }
  recording = !recording;
};
