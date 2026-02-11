---
name: liveview
description: Phoenix LiveView and LiveComponent. Use when adding or changing LiveView, live components, or real-time UI.
user-invocable: false
---

# LiveView

## When to Use

- Adding or changing LiveView modules (mount, handle_params, handle_event, handle_info).
- Building or refactoring LiveComponents or function components used in LiveView.
- Handling async work or real-time updates in LiveView.
- Writing or fixing LiveView tests.

## Principles

1. **State in assigns**: Keep UI state in `socket.assigns`; avoid storing large or redundant data. Derive in mount/handle_params/handle_event or in the template when possible.
2. **Thin callbacks**: Delegate business logic to context functions. In handle_event, call context then update assigns or push_navigate/push_patch. Use `send(self(), {:result, ...})` and `handle_info` for async work.
3. **Components**: Extract repeated markup into function components (in `lib/my_app_web.ex`) or LiveComponents. Use slots and attributes for configuration.
4. **Security**: Never assign user-controlled data that is rendered as raw HTML without sanitization. Use Phoenix.HTML and helpers for escaping; validate uploads with `allow_upload`.
5. **Testing**: Use Phoenix.LiveViewTest; test mount, params, and key events. Assert on rendered content and navigation; test behaviour, not implementation details.
6. **Verification**: Run `mix test` for affected LiveView tests after changes.
