# Regression checks

Run from the repository root with Lua 5.1:

```sh
lua tests/docking.lua
lua tests/chat_look.lua
```

The tests load the production Lua modules. WoW frames are simulated; docking tests replace unrelated rendering callbacks using debug upvalues. These checks do not certify WoW rendering, protected-frame behavior or compatibility with other addons.

Docking covers the default and selected Blizzard tabs, hidden frames, scaled cursor coordinates, title-bar precedence and preview, snapping, free placement, and undocking/redocking. Chat-look tests cover the real login discovery order, lazy installation, setting toggles, message formatting, new chat frames, skin conflicts and protected-message pass-through.

## Required in-game follow-up

1. With modern chat enabled, reload and send a normal chat message. Check the frame background and two-line message formatting.
2. Turn modern chat off and on without reloading. Toggle chat beautification separately. Check old and new messages and temporary whisper tabs.
3. Drag a ChatPilot window onto the main chat with General selected, then with Combat Log or another Blizzard dock tab selected. Check preview, tab creation, selection, drag-out and redocking.
4. Drop onto another ChatPilot title bar, including when it overlaps the main chat. Check that messages and tabs remain in the intended group.
5. Snap above chat, move freely, reload and verify saved groups. Repeat at the user's UI scale, during combat, and with their usual addons. Watch for Lua errors.

No live WoW client test was performed for this patch. A mock secret value only checks pass-through logic; it does not reproduce the game's secret-value enforcement.
