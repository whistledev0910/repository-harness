# Symphony Web UI Controller Design Reference

This folder captures the completed reference design for the next Symphony Web
UI/UX revamp pass.

## Files

- `template.html` - standalone HTML/CSS/JS reference for the controller surface.
- `data.json` - sample dashboard data used by the reference.
- `artifact.json` - live artifact metadata for the HTML/data pairing.
- `template.html.artifact.json` - exported template metadata.
- `provenance.json` - source notes, refresh plan, transformations, and safety notes.
- `critique.json` - design critique scores and rationale from the polish pass.
- `mqum833g-drawing-2026-06-26T07-34-24-936Z.png` - screenshot preview of the controller concept.

## Implementation Notes

Use this reference to guide the product UI, not as a direct source of runtime
truth. The live app should continue to read Symphony board, run event, review,
PR, and sync state from the existing local web API contracts.
