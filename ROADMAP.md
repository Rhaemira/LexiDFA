# Roadmap

This roadmap records possible follow-up work. Items are priorities, not release promises.

## Correctness and teaching

- [ ] Add line and column information to lexical diagnostics while keeping character offsets available for trace selection.
- [ ] Publish a concise language-spec document for keywords, identifiers, operators, literals, and unsupported forms.
- [ ] Test DFA visualization metadata against scanner behavior so the diagram and implementation are less likely to drift.
- [ ] Add property-based or fuzz-style tests for arbitrary input and termination guarantees.
- [ ] Add a guided teaching mode that explains why a lexeme was accepted or rejected and how the DFA transitioned.
- [ ] Add a deliberately small parser module while keeping lexical and syntax analysis separate.

## Workflow and performance

- [ ] Add UI automation for tab navigation, trace selection, pause/resume, and appearance preferences.
- [ ] Export token tables and scan reports as JSON or CSV.
- [ ] Expose benchmark workload size and bounded worker count as controlled options; keep result verification enabled by default.
- [ ] Collect release-build benchmark baselines on physical devices and keep simulator measurements separate.

## Presentation

- [ ] Capture current light- and dark-appearance screenshots for the main screens after the release UI has been validated in Xcode.
