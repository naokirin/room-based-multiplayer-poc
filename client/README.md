# Client - Room-based Multiplayer Game Platform

React + TypeScript + PixiJS web client for the multiplayer card game platform.

## Tech Stack

- **React 19** - UI framework
- **TypeScript 5.9** - Type safety
- **PixiJS 8** - Game rendering
- **Zustand 5** - State management
- **Phoenix WebSocket** - Real-time communication
- **Vite** - Build tool

## Project Structure

```
src/
├── components/       # React components
│   ├── Auth.tsx     # Login/Register UI
│   ├── Lobby.tsx    # Game lobby and matchmaking
│   └── Game.tsx     # Game screen wrapper
├── stores/          # Zustand stores
│   ├── authStore.ts    # Authentication state
│   ├── lobbyStore.ts   # Matchmaking state
│   └── gameStore.ts    # Game state
├── services/        # API and WebSocket clients
│   ├── api.ts      # REST API client
│   └── socket.ts   # Phoenix WebSocket manager
├── game/            # Game rendering
│   └── GameRenderer.ts  # PixiJS renderer
├── types/           # TypeScript types
│   └── index.ts    # Shared type definitions
└── App.tsx          # Main app router
```

## Development

### Prerequisites

- Node.js 18+
- npm or yarn

### Setup

```bash
# Install dependencies
npm install

# Set environment variables (optional)
# Create .env.local file:
VITE_API_URL=http://localhost:3001/api/v1

# Start development server
npm run dev
```

### Available Scripts

```bash
npm run dev          # Start dev server (port 5173)
npm run build        # Build for production
npm run preview      # Preview production build
npm run typecheck    # Run TypeScript type checking
npm run lint         # Run Biome (lint + format check)
npm run lint:fix     # Fix with Biome
```

## Implementation Status

### Phase 3 - Client Implementation ✅

- [x] T077: Auth Store (authStore.ts)
- [x] T078: Login/Register UI (Auth.tsx)
- [x] T079: Lobby Store (lobbyStore.ts)
- [x] T080: Lobby UI (Lobby.tsx)
- [x] T081: WebSocket Manager (socket.ts)
- [x] T082: Game Store (gameStore.ts)
- [x] T083: PixiJS Game Renderer (GameRenderer.ts)
- [x] T084: Game UI (Game.tsx)
- [x] T085: App Router (App.tsx)

### Key Features

**Authentication**
- Auto-refresh token (50 min interval for 1hr tokens)
- Persistent session via localStorage
- Login/Register with email and password

**Matchmaking**
- Browse available game types
- Join matchmaking queue
- Real-time status polling (3s interval)
- Cancel queue support

**Game**
- PixiJS 8 rendering with proper async initialization
- Real-time game state via WebSocket
- Card playing with click interaction
- Turn timer with countdown
- HP bars with color coding (green/yellow/red)
- Game result modal
- Reconnection token persistence

**State Management**
- Zustand stores for auth, lobby, and game state
- Proper cleanup of timers and subscriptions
- Type-safe state updates

## Architecture Notes

### Screen Routing

Simple state-based routing without react-router:
- `auth` - Not authenticated
- `lobby` - Authenticated, no active game
- `game` - In game or matched

### WebSocket Connection

Phoenix WebSocket with:
- JWT token authentication
- Protocol version 1.0
- Auto-generated nonce for actions (UUID v4)
- Event-based message handling

### Game Rendering

PixiJS 8 with:
- Async initialization pattern
- Null-safe render methods
- Efficient state updates
- Interactive card elements

### Memory Management

Proper cleanup implemented for:
- Token refresh timers
- Matchmaking poll timers
- Turn countdown timers
- WebSocket connections
- PixiJS renderer resources

## Known Limitations (MVP)

- No target selection UI for damage cards (auto-targets opponent)
- Chat is placeholder (Phase 5)
- No reconnection flow UI (token stored but flow not implemented)
- Basic styling (inline styles, no CSS modules)
- No error boundary components
- No loading skeletons

## Testing

Type checking is required before commits:

```bash
npm run typecheck
```

Biome linting is recommended:

```bash
npm run biome:check
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `VITE_API_URL` | `http://localhost:3001/api/v1` | API server base URL |

WebSocket URL is provided dynamically by the matchmaking response.
