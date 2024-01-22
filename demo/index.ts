import { Builder, Key, WebDriver } from "selenium-webdriver";
import { Options } from "selenium-webdriver/chrome";
import {writeFileSync} from "fs";
import express from "express";
import fileUpload from 'express-fileupload';
import bodyParser from 'body-parser';
import cors from 'cors';

const FRAMERATE = 30;
const port = process.env.PORT || 20001;


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

async function performEvent(driver: WebDriver, event: any) {

  switch (event.type) {
    case "mousemove":
      await driver
        .actions()
        .move({ x: event.x, y: event.y, duration: 1 })
        .perform()
        .catch(() => {
          // ignore
        });
      break;
    case "click":
      await driver
        .actions()
        .move({ x: event.x, y: event.y, duration: 1 })
        .click() 
        .perform()
        .catch(() => {});
      break;
    case "mousedown":
      await driver
        .actions()
        .move({ x: event.x, y: event.y, duration: 1 })
        .press() 
        .perform()
        .catch(() => {});
      break;
    case "mouseup":
      await driver
        .actions()
        .move({ x: event.x, y: event.y, duration: 1 })
        .release()
        .perform()
        .catch(() => {});
      break;
    case "keydown":
      if (event.payload?.key) {
        await driver
          .actions()
          .keyDown(getKey(event.payload.key))
          .perform()
          .catch(() => {});
      }
      break;
    case "keyup":
      if (event.payload?.key) {
        await driver
          .actions()
          .keyUp(getKey(event.payload.key))
          .perform()
          .catch(() => {});
      }
      break;
  }
}

function zeroPad(num: number, places: number) {
  return String(num).padStart(places, "0");
}

async function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function processEvents(
  driver: WebDriver,
  events: any[],
  {render}: {render: boolean},
) {
  let currentTime = 0;
  let eventIndex = 0;
  let frameIndex = 0;

  while (eventIndex < events.length) {
    let currentEvent = events[eventIndex++];
    while (currentEvent && currentTime > currentEvent.time) {
      await performEvent(driver, currentEvent);
      currentEvent = events[eventIndex++];
    }
    if (render) {
      writeFileSync(`./frames/${zeroPad(frameIndex++, 5)}.png`, await driver.takeScreenshot(), 'base64');
    }
    
    const timeStep = 1/FRAMERATE * 1000;
    currentTime += timeStep;
    if (!render) {
      await sleep(timeStep);
    }
  }
}

const ZOOM_25_PERCENT = -7.6035680338478615;
const ZOOM_75_PERCENT = -1.5778829311823859;
const ZOOM_100_PERCENT = 0.0;
const ZOOM_150_PERCENT = 2.223901085741545;
const ZOOM_200_PERCENT = 3.8017840169239308;

const ZOOM_400_PERCENT = 7.6035680338478615;
const ZOOM_500_PERCENT = 8.827469119589406;

async function run({events, render}: RunRequest) {
  const opts = new Options();
  if (render) {
    opts.addArguments('--headless=new');
  }
  opts.windowSize({
    width: 2560 * 2,
    height: 1440 * 2,
  });
  opts.setUserPreferences({
    partition: {
      default_zoom_level: {
        x: ZOOM_400_PERCENT,
      },
    },
  });
  const driver = await new Builder()
    .forBrowser("chrome")
    .setChromeOptions(opts)
    .build();
  await driver.get("http://localhost:52222/");

  await processEvents(driver, events, {render});

  driver.quit();
};

const app = express();

app.get('/ok', (_, res) => res.send('oks'));

app.use(bodyParser.json({ limit: '5mb' }));

// this is needed to accept form post requests.
app.use(bodyParser.urlencoded({ extended: true }));

app.use(fileUpload());
app.use(cors());


interface RunRequest {
  events: any[];
  render: boolean;
}

app.post('/run', (req, res) => {
  run({events: req.body.events, render: req.body.render ?? false,});
  res.sendStatus(200);
});

app.listen(port, ()=>{
  console.log(`Listening on port ${port}`);
});