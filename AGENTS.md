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
