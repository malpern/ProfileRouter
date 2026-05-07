# ProfileRouter.spoon

A Hammerspoon Spoon that routes browser tabs between profiles automatically. Press one key to move a tab, or let it route itself based on domain rules.

Supports **Dia** and **Google Chrome**. Works with any number of profiles.

## What it does

- **Ctrl+S** cycles the current tab to the next browser profile (under a second)
- **Auto-routing** moves tabs to the correct profile based on domain/path rules
- **YouTube** videos keep their playback position and resume playing after the move
- **External URLs** route to the right profile when Hammerspoon is your default browser
- **Cooldowns** prevent the auto-router from fighting you when you override it
- **Live-reload** — edit a route file, save, done

## Quick start (2 profiles)

### 1. Install Hammerspoon

```
brew install hammerspoon
```

### 2. Install the Spoon

Copy `ProfileRouter.spoon/` to `~/.hammerspoon/Spoons/`:

```
cp -r ProfileRouter.spoon ~/.hammerspoon/Spoons/
```

### 3. Create route files

Create `~/.hammerspoon/routes/` and add one text file per profile. The filename becomes the profile name.

```
mkdir -p ~/.hammerspoon/routes
```

**~/.hammerspoon/routes/work.txt**
```
slack.com
figma.com
linear.app
path:github.com/your-org
```

**~/.hammerspoon/routes/personal.txt**
```
youtube.com
reddit.com
amazon.com
path:github.com/yourusername
```

### 4. Load the Spoon

Add to `~/.hammerspoon/init.lua`:

```lua
hs.loadSpoon("ProfileRouter")
spoon.ProfileRouter:start()
spoon.ProfileRouter:bindHotkeys({ cycleTab = {{"ctrl"}, "s"} })
```

Reload your Hammerspoon config. That's it.

## How it works

**Profile detection:** Each profile's route file name maps to a window title pattern. A file named `work.txt` creates a profile called "Work" that matches browser windows with "Work:" in the title. The last profile alphabetically becomes the default (matched when no title pattern matches).

**Route files:** One domain per line. Lines starting with `#` are comments. Use `path:` for path-based matching:

```
# Domain rule — matches domain and all subdomains
slack.com

# Path rule — matches URLs starting with this path
path:github.com/your-org
```

**Ctrl+S:** Cycles through profiles in order. With 2 profiles it toggles. With 3+ it advances to the next and wraps around.

**Auto-routing:** Watches for page loads (via window title changes), checks the URL against all route files, and moves the tab if it's in the wrong profile.

**Cooldowns:** When you manually move a tab with Ctrl+S, the URL goes on a 10-minute cooldown so the auto-router won't move it back. The notification includes an "Undo Cooldown" button.

## Browser-specific setup

### Dia

For YouTube video position preservation, launch Dia with the JavaScript flag:

```
/Applications/Dia.app/Contents/MacOS/Dia --enable-applescript-javascript
```

### Google Chrome

For YouTube features, enable JavaScript execution:

1. Open Chrome
2. Go to **View > Developer > Allow JavaScript from Apple Events**

## Explicit configuration

For Chrome, 3+ profiles, or custom title patterns, set config before calling `:start()`:

```lua
hs.loadSpoon("ProfileRouter")

spoon.ProfileRouter.browser = {
    name = "Google Chrome",
    bundleID = "com.google.Chrome",
    processName = "Google Chrome",
}

spoon.ProfileRouter.profiles = {
    { name = "Work",     titlePattern = "Work:",  routeFile = "work.txt",     icon = "💼" },
    { name = "School",   titlePattern = "School:", routeFile = "school.txt",  icon = "🎓" },
    { name = "Personal", titlePattern = nil,       routeFile = "personal.txt", icon = "🏠", isDefault = true },
}

spoon.ProfileRouter:start()
spoon.ProfileRouter:bindHotkeys({ cycleTab = {{"ctrl"}, "s"} })
```

## Configuration reference

| Property | Default | Description |
|----------|---------|-------------|
| `browser` | auto-detected | `{name, bundleID, processName}` |
| `profiles` | auto-discovered | List of profile tables |
| `routesDir` | `~/.hammerspoon/routes/` | Directory containing route files |
| `cooldownSeconds` | `600` | Cooldown duration after manual move |
| `debug` | `true` | Log to `~/.hammerspoon/profile-router.log` |

## Troubleshooting

**Check the log:** `tail -f ~/.hammerspoon/profile-router.log`

**No route files found:** Create at least one `.txt` file in `~/.hammerspoon/routes/`.

**Tabs not auto-routing:** Check that the domain is in a route file and the profile window title matches the expected pattern (`ProfileName: Page Title`).

**YouTube position not preserved:** Ensure the browser has JavaScript execution enabled (see browser-specific setup above).

## License

MIT
