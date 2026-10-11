## Coding conventions

- Define extracted or logically distinct SwiftUI views as separate `View` structs.
  Do not implement subviews as computed properties returning `some View`; `body`
  is the normal exception. Computed data properties are fine.
- Put private helper methods and enums in private extensions. Keep protocol
  requirements and overrides where their visibility requires them.
- Localize user-visible strings, tooltips, and accessibility labels. Add French
  and Spanish translations with compatible interpolation placeholders to the
  string catalogs. Preserve English as the source language.
- Use locale-aware formatting for percentages, counts, dates, durations and byte
  quantities. Percent styles consume fractions: `1.0` represents 100%.
- Follow `.swiftformat`: Swift 6 language mode, four-space indentation and LF
  line endings. Format touched Swift files rather than unrelated files.

## Formatting and spacing

- Match the surrounding code's vertical spacing. Separate sibling SwiftUI
  views with a blank line, including `Text`, `Spacer`, `Divider`, buttons,
  containers, and conditional or repeated view groups.
- Separate logical steps in methods with blank lines: setup, guards, operations,
  error handling, and returns. Keep related declarations and assignments grouped.
- Keep modifiers attached to their view without intervening blank lines. Preserve
  the existing modifier-chain style rather than reformatting unrelated code.
- Do not combine separate statements on one line with semicolons. Expand
  multi-statement closures and control-flow blocks onto separate lines; concise
  single-statement closures and guards may remain inline.
- Run SwiftFormat on every touched Swift file using the root `.swiftformat`,
  then run it again with `--lint`. Also run `git diff --check` and manually review
  sibling-view and logical-group spacing: SwiftFormat's default rules do not
  insert all of the blank lines required by this project.
