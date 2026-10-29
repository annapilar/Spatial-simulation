# Prompt log – AI_AfricanSavannah_T3

AI tool: Claude Code (Claude Opus 5.5) · GAMA 2025-06

| # | Prompt summary | Change summary | Comment | Model version |
|---|---|---|---|---|
| 1 | Declare a list of age values | Added global variable `list<int> lion_ages <- []` | Ages in whole years; list is empty and will be filled from the lions later | 3.0 |
| 2 | Fill the list with the age values 0 to 60, to be assigned to the lions later | Changed declaration to `list<int> lion_ages <- range(60)` (values 0–60, 60 included) | Agent first proposed a loop and random ages per lion; corrected to a plain list of all possible ages. 60 years is not realistic but required by the task | 3.0 |
| 3 | Commit and push, document in the log | Committed and pushed the model and both prompt logs (PROMPT_LOG.md, PROMPT_LOG.xlsx) to GitHub | Excel log is generated from the Markdown log, so both contain the same rows | 3.0 |
