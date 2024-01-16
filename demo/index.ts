import { Builder, Key, WebDriver } from "selenium-webdriver";
import { Options } from "selenium-webdriver/chrome";
import * as events from "./mouse-events_take-4.json";

const FRAMERATE = 60;

function getKey(key: string): any {
  switch (key) {
    case "Shift":
      return Key.SHIFT;
    case "Control":
      return Key.CONTROL;
    case "Alt":
      return Key.ALT;
    case "Meta":
      return Key.META;
    case "Enter":
      return Key.ENTER;
    case "Backspace":
      return Key.BACK_SPACE;
    default:
      return key;
  }
}

async function processEvents(
  driver: WebDriver,
  events: any[],
  eventIndex: number,
  startTime: number
) {
  let time = Date.now() - startTime;

  let currentEvent = events[eventIndex++];

  if (!currentEvent) {
    return;
  }

  while (currentEvent.time < time && currentEvent.type === "mousemove") {
    const nextEvent = events[eventIndex++];
    if (!nextEvent) {
      break;
    }
    currentEvent = nextEvent;
  }

  switch (currentEvent.type) {
    case "mousemove":
      await driver
        .actions()
        .move({ x: currentEvent.x, y: currentEvent.y, duration: 1 })
        .perform()
        .catch(() => {
          // ignore
        });
      break;
    case "mousedown":
      await driver
        .actions()
        .move({ x: currentEvent.x, y: currentEvent.y, duration: 1 })
        .press() 
        .perform()
        .catch(() => {});
      break;
    case "mouseup":
      await driver
        .actions()
        .move({ x: currentEvent.x, y: currentEvent.y, duration: 1 })
        .release()
        .perform()
        .catch(() => {});
      break;
    case "keydown":
      if (currentEvent.payload?.key) {
        await driver
          .actions()
          .keyDown(getKey(currentEvent.payload.key))
          .perform()
          .catch(() => {});
      }
      break;
    case "keyup":
      if (currentEvent.payload?.key) {
        await driver
          .actions()
          .keyUp(getKey(currentEvent.payload.key))
          .perform()
          .catch(() => {});
      }
      break;
  }

  const nextEvent = events[eventIndex];

  // get time again after async actions
  time = Date.now() - startTime;

  if (nextEvent) {
    setTimeout(() => {
      processEvents(driver, events, eventIndex, startTime);
    }, Math.max(nextEvent.time - time, nextEvent.type === "mousemove" ? 1000 / FRAMERATE : 0));
  }
}

(async function test() {
  const opts = new Options();
  opts.windowSize({
    width: 1920,
    height: 1080,
  });
  opts.setUserPreferences({
    partition: {
      default_zoom_level: {
        x: 2.223901085741545,
      },
    },
  });
  const driver = await new Builder()
    .forBrowser("chrome")
    .setChromeOptions(opts)
    .build();
  await driver.get("http://localhost:52222/");

  processEvents(driver, events, 0, Date.now());
})();
