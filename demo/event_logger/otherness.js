const button = document.getElementById("save-button");

button.onclick = async () => {
  const { log } = await chrome.storage.local.get(["log"]);
  const blob = new Blob([JSON.stringify(log)]);
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = "mouse-events.json";
  link.click();
};
