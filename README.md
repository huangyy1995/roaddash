# 🏍️ Road Dash — Motorcycle Combat Racing

A Road Rash-inspired motorcycle combat racing game built with **Godot 4**. Features pseudo-3D road rendering, AI opponents, punch combat, bike upgrades, and touch controls for mobile play.

## Features

- 🛣️ Classic pseudo-3D road with curves, hills, and roadside scenery
- 👊 Punch combat — knock opponents off their bikes
- 🤖 5 AI opponents with varying difficulty
- 🏪 Bike shop — upgrade Speed, Acceleration, and Armor
- 📱 Touch controls for mobile browsers
- 🎮 Keyboard controls: Arrow/WASD + Z/X to punch
- 📈 Progressive difficulty across levels
- 🏁 Finish line, race positions, and prize money

## Controls

| Action       | Keyboard         | Touch               |
|-------------|-----------------|----------------------|
| Steer Left  | ← / A           | Bottom-left zone     |
| Steer Right | → / D           | Bottom-left zone     |
| Accelerate  | ↑ / W           | Bottom-right (GAS)   |
| Brake       | ↓ / S           | Bottom-right (BRK)   |
| Punch Left  | Z               | Left-middle zone     |
| Punch Right | X               | Right-middle zone    |

## Play Locally with Godot

1. Install [Godot 4.2+](https://godotengine.org/download)
2. Open the `roaddash/` folder as a Godot project
3. Press **F5** to run

## Export to HTML5 (Manual)

1. Open in Godot Editor
2. Go to **Project → Export**
3. Select **Web** preset
4. Click **Export Project** → save to `build/index.html`
5. Serve the `build/` folder with any web server:
   ```bash
   cd build && python3 -m http.server 8080
   ```

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
# 1. Build Docker image (includes Godot HTML5 export)
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

### Option C: Pre-export (faster Docker build)

If you already exported the game to `build/`:

```dockerfile
# Use this simpler Dockerfile instead:
FROM nginx:alpine
RUN rm /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY build/ /usr/share/nginx/html/
EXPOSE 8080
CMD ["nginx", "-g", "daemon off;"]
```

## Project Structure

```
roaddash/
├── project.godot          # Godot project config
├── export_presets.cfg     # HTML5 export preset
├── scenes/
│   └── main.tscn          # Root scene
├── scripts/
│   └── main.gd            # All game logic (~700 lines)
├── Dockerfile             # Multi-stage: Godot export + nginx
├── nginx.conf             # Web server config (COOP/COEP headers)
├── deploy.sh              # One-click Cloud Run deployment
└── README.md              # This file
```

## Architecture

The game uses a **single-scene, single-script** architecture for simplicity:

- **State machine**: `MENU → COUNTDOWN → RACING → RESULTS → SHOP → RACING...`
- **Pseudo-3D rendering**: Classic segment-based road projection (à la OutRun/Road Rash)
- **Procedural graphics**: Everything drawn with `_draw()` — no image assets needed
- **Road generation**: Composed of curves, hills, and straight sections with configurable intensity

## License

MIT — free to use, modify, and distribute.
# roaddash
