# Bug report: Dia crashes when `execute javascript` is sent via AppleScript

**To:** The Browser Company / Dia team (send via Dia → Help → Send Feedback, or your usual feedback channel)

**Summary:** With Dia launched using `--enable-applescript-javascript`, sending an
AppleScript `execute javascript` command to a tab reliably crashes the whole
browser with a stack-overflow (infinite recursion in the Swift runtime). 100%
reproducible.

---

## Environment
- **Dia:** 1.36.0 (`company.thebrowser.dia`)
- **macOS:** 27.0 (build 26A5353q), Apple Silicon
- Dia launched with: `open -a Dia --args --enable-applescript-javascript`

## Steps to reproduce
1. Quit Dia fully.
2. Launch with the flag: `/Applications/Dia.app/Contents/MacOS/Dia --enable-applescript-javascript`
   (or `open -a Dia --args --enable-applescript-javascript`).
3. With any normal tab focused, run from Terminal:
   ```
   osascript -e 'tell application "Dia" to tell active tab of window 1 to execute javascript "true"'
   ```
   (A trivial expression like `"true"` or `"2+2"` is enough — no page interaction needed.)

## Expected
The JavaScript executes in the tab and the result is returned to AppleScript
(this is the behavior gated behind the `--enable-applescript-javascript` flag,
matching Chrome's "Allow JavaScript from Apple Events").

## Actual
Dia crashes within ~30 seconds — **`EXC_BAD_ACCESS` / `SIGSEGV`, "Thread stack
size exceeded due to excessive recursion" / "Could not determine thread index
for stack guard region."** macOS then offers to reopen Dia. Reproduced twice,
identical signature.

### Without the flag (control)
The same command returns a clean, correct error and does **not** crash:
`Dia got an error: JavaScript execution via AppleScript requires the
--enable-applescript-javascript launch flag. (-10006)`
So the crash is specific to the enabled-flag code path actually executing JS.

## Crash signature (faulting thread, top frames)
```
EXC_BAD_ACCESS (SIGSEGV) — stack guard / excessive recursion, thread 0
  libswiftCore.dylib  (x5, recursing)
  Foundation
  Dia                 (x2)
  CoreFoundation      (run-loop / Apple Event dispatch)
  Foundation
  ...
```
The recursion originates in the Swift runtime while Dia handles the incoming
`execute javascript` Apple Event dispatched through the CoreFoundation run loop —
i.e. the AppleScript-JS handler appears to recurse without a base case.

## Impact
This is the only mechanism Dia exposes for Apple-Events JavaScript execution
(unlike Chrome, there is no menu toggle / persistent preference — the launch flag
is the sole path). Because the flag itself crashes the browser, AppleScript-based
JS automation against Dia is currently unusable. It breaks tools that rely on
`execute javascript` (e.g. tab/automation utilities that read page or media state).

## Notes
- Likely interacts with Dia's `agent-server` layer, which Chrome/Arc don't have.
- Happy to provide the full `.ips` crash reports on request.
