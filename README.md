# 🏍️ Road Dash — Motorcycle Combat Racing

A **Road Rash**-inspired motorcycle combat racing game built as a single-file **HTML5 Canvas** application. Zero dependencies, runs in any modern browser, optimized for mobile touch controls. Deployable to GCP Cloud Run.

![Road Dash](https://img.shields.io/badge/HTML5-Canvas-orange) ![Zero Dependencies](https://img.shields.io/badge/Dependencies-None-green) ![Mobile Ready](https://img.shields.io/badge/Mobile-Ready-blue)

## Features

- 🛣️ Pseudo-3D road with curves, hills, parallax mountains, and sunset sky
- 🏍️ Pre-rendered motorcycle sprites with detailed rear-view rider (helmet, jacket, exhaust)
- 👊 Punch combat with screen shake, slow-motion, hit flash, and combo system
- 🔊 Dynamic sound effects via Web Audio API (punch impacts, whoosh on miss)
- 🤖 6 AI opponents with distinct colors and steering/avoidance AI
- 🏪 Bike shop between races — repair, speed boost, armor upgrades
- 🏁 Visible finish zone with checkerboard road, FINISH billboards, and progress bar
- 📱 Full-screen mobile layout with transparent touch zones
- 🎮 Keyboard + touch controls
- 📈 Progressive difficulty across levels
- 🌲 6 scenery types: pine trees, palms, oaks, rocks, cacti, telegraph poles, billboards

## Controls

| Action | Keyboard | Touch |
|---|---|---|
| Steer Left | ← / A | Left zone (◀) |
| Steer Right | → / D | Left-center zone (▶) |
| Accelerate | ↑ / W | Right-center zone (▲ GAS) |
| Brake | ↓ / S | Right zone (▼ BRAKE) |
| Punch Left | Z | Center-left zone (👊) |
| Punch Right | X | Center-right zone (👊) |
| Confirm | Enter / Space | Tap anywhere |

## Play Locally

No build step, no dependencies — just serve the HTML file:

```bash
cd roaddash
python3 -m http.server 8080
# Open http://localhost:8080
```

Or use any static file server (Node `npx serve`, VS Code Live Server, etc.)

## Deploy to GCP Cloud Run

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) installed
- [gcloud CLI](https://cloud.google.com/sdk/docs/install) installed and authenticated
- A GCP project with billing enabled

### Option A: One-command deploy

```bash
chmod +x deploy.sh
GCP_PROJECT_ID=your-project-id ./deploy.sh
```

### Option B: Step by step

```bash
# 1. Build Docker image
docker build -t gcr.io/YOUR_PROJECT/road-dash .

# 2. Push to Container Registry
docker push gcr.io/YOUR_PROJECT/road-dash

# 3. Deploy to Cloud Run
gcloud run deploy road-dash \
  --image gcr.io/YOUR_PROJECT/road-dash \
  --platform managed \
  --region asia-east1 \
  --port 8080 \
  --allow-unauthenticated
```

The game will be available at the URL printed by `gcloud run deploy`.

### Docker Local Test

```bash
docker build -t road-dash .
docker run -p 8080:8080 road-dash
# Open http://localhost:8080
```

## Project Structure

```
roaddash/
├── index.html       # Complete game (single file, ~1800 lines)
├── Dockerfile       # nginx:alpine + static file serving
├── nginx.conf       # Web server config (port 8080, /healthz endpoint)
├── deploy.sh        # One-click GCP Cloud Run deployment script
└── README.md        # This file
```

## Architecture

Everything lives in a single `index.html` — no external assets, no build tools.

- **Rendering**: HTML5 Canvas 2D with pseudo-3D segment-based road projection (technique from [Jake Gordon's JavaScript Racer](https://github.com/jakesgordon/javascript-racer) / [Lou's Pseudo 3D Page](http://www.extentofthejam.com/pseudo/))
- **Sprites**: Pre-rendered to offscreen canvases at init time (bikes, trees, rocks, billboards)
- **State machine**: `MENU → COUNTDOWN → RACING → CRASHED/RESULTS → SHOP → next race`
- **Physics**: Segment-based collision, centrifugal force on curves, off-road deceleration
- **AI**: Opponents steer around player and each other with lookahead avoidance
- **Combat**: Hit detection by proximity + direction, with combo multiplier and visual/audio feedback
- **Mobile**: Transparent touch zones covering bottom 38% of screen, full-screen canvas

## Combat System

- Punch connects when an opponent is within range and on the correct side
- Successful hits trigger: screen shake, yellow flash, slow-motion freeze, floating "+$" popup
- Consecutive hits build a **combo multiplier** (2x, 3x...) for bonus cash
- Knocked opponents spin and slow down significantly
- Opponents can also punch you, draining your health

## License

MIT — free to use, modify, and distribute.
