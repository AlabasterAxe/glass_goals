import { By, Builder, Origin } from "selenium-webdriver";
import * as events from "./mouse-events.json";

(async function test() {
  const driver = await new Builder().forBrowser("chrome").build();
  await driver.get("http://localhost:55210/");
  const startTime = Date.now();
  const period = 10000;
  const framerate = 60;
  let eventIndex = 0;
  let interval: ReturnType<typeof setInterval>;

  interval = setInterval(() => {
    const time = (Date.now() - startTime) % period;

    let currentEvent = events[eventIndex];
    while (currentEvent.time < time) {
      const nextEvent = events[++eventIndex];
      if (!nextEvent) {
        clearInterval(interval);
        break;
      }
      currentEvent = nextEvent;
    }
    driver
      .actions()
      .move({ x: currentEvent.x, y: currentEvent.y, duration: 1 })
      .perform()
      .catch(() => {
        // ignore
      });
  }, 1000 / framerate);
})();
