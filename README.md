# Roblox Debug Console

Local debug console for **your own** Roblox games.
Opens with **F8** in-game. Works only in Studio or for whitelisted UserIds.

⚠️ This project is NOT a cheat. It does NOT work in other people's games.
It only works in **your own game** where you have full server access.

## Install

1. Copy `DebugConsole.lua`.
2. In Roblox Studio: `StarterPlayer → StarterPlayerScripts → Insert LocalScript`.
3. Paste the code.
4. Put your UserId in `WHITELIST`.
5. Press Play → F8.

## Commands

| Command | Description |
|---|---|
| `help` | list all commands |
| `speed 100` | set WalkSpeed |
| `jump 200` | set JumpPower |
| `fly on` | enable fly (WASD + Space/Shift) |
| `noclip on` | walk through walls |
| `god on` | local godmode |
| `tp Player` | teleport to player |
| `esp on` | highlight players |
| `fullbright on` | brighten lighting |
| `pos` | show coordinates |
| `save` / `load` | save / load settings |

Full list: type `help` in console.

## License

MIT
