---
name: readme-screenshot
description: Add or update a screenshot in the README. Drop an image into the conversation, then run this skill. It saves the image to docs/images/ and updates README.md.
---

# README Screenshot — Delta Neutral

Add or update a screenshot in the project README. The user will have already dropped an image into the conversation before invoking this skill.

## Step 1: Identify the source image

Look at the current conversation for an image the user has shared. The image will have a source path (e.g. `/Users/.../Screenshot...png` or a temp path). Store that path for Step 3.

If no image is visible in the conversation, ask the user to drop one in and try again.

## Step 2: Determine the screenshot name

If the user passed an argument (e.g. `/readme-screenshot position-view`), use that as the name.

Otherwise, read `README.md` and look at the existing screenshots in the `## Screenshots` section. Present the user with options using AskUserQuestion:
- Update an existing screenshot (list the ones found, e.g. `dashboard`, `position-view`)
- Add a new screenshot (ask for the name and caption)

## Step 3: Copy the image

Copy the source image to `docs/images/<name>.png`. Use Python to handle macOS unicode filename quirks:

```bash
python3 -c "
import shutil, glob
files = glob.glob('<source-path-with-glob-wildcards-if-needed>')
if files:
    shutil.copy2(files[0], 'docs/images/<name>.png')
    print('Copied successfully')
else:
    print('ERROR: Source file not found')
"
```

If the glob approach fails, try the exact path. The key issue is macOS screenshots often contain unicode narrow no-break spaces (`\u202f`) before AM/PM that look like regular spaces but aren't.

## Step 4: Update README.md if needed

Read `README.md` and check if `docs/images/<name>.png` is already referenced.

- **If already referenced**: No change needed, tell the user the image was updated in place.
- **If new**: Add `![<Caption>](docs/images/<name>.png)` to the `## Screenshots` section, after the last existing screenshot entry. Use title case for the caption (e.g. `Position View` for name `position-view`).

## Step 5: Confirm

Tell the user:
- Which file was saved and its size
- Whether the README was updated or the image was replaced in place
