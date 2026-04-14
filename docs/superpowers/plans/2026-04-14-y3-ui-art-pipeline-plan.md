# Y3 UI Art Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a new `y3-ui-art-pipeline` skill that classifies Y3 UI art requests, splits reusable editor assets from preview composites, routes into existing skills, and enforces preview approval before editor-facing landing.

**Architecture:** Add one new coordinator skill under `C:\Users\裴浩然\.codex\skills\y3-ui-art-pipeline` and keep it intentionally thin. Put durable rules and prompt scaffolds into `references/` so the main `SKILL.md` stays readable and trigger-focused. Validate the skill by checking folder structure, frontmatter, and the behavior it should drive on realistic Y3 UI art requests.

**Tech Stack:** Codex skills (`SKILL.md`), Markdown reference files, local validation via skill metadata rules and file inspection.

---

### Task 1: Create Skill Skeleton

**Files:**
- Create: `C:\Users\裴浩然\.codex\skills\y3-ui-art-pipeline\SKILL.md`
- Create: `C:\Users\裴浩然\.codex\skills\y3-ui-art-pipeline\references\asset-rules.md`
- Create: `C:\Users\裴浩然\.codex\skills\y3-ui-art-pipeline\references\prompt-templates.md`
- Create: `C:\Users\裴浩然\.codex\skills\y3-ui-art-pipeline\references\review-checklist.md`

- [ ] **Step 1: Create the directories**

Run: `New-Item -ItemType Directory -Force 'C:\Users\裴浩然\.codex\skills\y3-ui-art-pipeline','C:\Users\裴浩然\.codex\skills\y3-ui-art-pipeline\references'`
Expected: PowerShell prints created directories or returns existing ones without error.

- [ ] **Step 2: Write the initial `SKILL.md`**

Write this content to `C:\Users\裴浩然\.codex\skills\y3-ui-art-pipeline\SKILL.md`:

```md
---
name: y3-ui-art-pipeline
description: Use when working on Y3 UI visual assets, especially when Codex must distinguish reusable editor resource images from preview-only composite art, evaluate whether an existing UI image is suitable for Y3 import, or produce both source assets and preview composites before sending work to y3-ui-generator or imagegen.
---

# Y3 UI Art Pipeline

Use this skill as the first stop for Y3 UI art work.

## First responsibility

Classify the request into:

- `ui-resource-art`
- `display-art`
- `mixed`

If unclear, default to `mixed`.

## Required split

Before generating or approving any image, split the request into:

- what must be a reusable bitmap asset
- what must remain a Y3 widget or text node
- what is preview-only composite art

If the user provides existing images, label each one as:

- valid reusable Y3 resource image
- valid preview or display image
- invalid for Y3 reusable import

## Hard rules

- Reusable resource images must not bake in dynamic text, prices, counters, hotkeys, mutable icons, or localized strings.
- Composite preview images may include sample text and layout, but they are not editor assets.
- Do not allow editor-facing landing before the user approves the preview direction.
- If a full rendered panel is being treated as a shell or reusable asset, stop and explain why that is invalid.

## Deliverables

When relevant, always produce both:

1. A resource asset set
2. A preview composite set

The resource asset set should list:

- asset name
- intended use
- target size
- transparent background required or not
- nine-slice required or not
- state variants required or not
- text bake-in forbidden or allowed

## Routing

- If the user needs Y3 panel structure or JSON, hand off to `y3-ui-generator`.
- If the user needs bitmap generation or bitmap edits, hand off to `imagegen`.
- Keep this skill focused on classification, splitting, preview gating, and review.

## References

Read these files as needed:

- `references/asset-rules.md` for reusable Y3 art constraints
- `references/prompt-templates.md` for resource and preview prompt skeletons
- `references/review-checklist.md` for preview approval and rejection checks
```

- [ ] **Step 3: Write the asset rules reference**

Write this content to `C:\Users\裴浩然\.codex\skills\y3-ui-art-pipeline\references\asset-rules.md`:

```md
# Asset Rules

## Reusable Y3 Resource Art

Use this category for:

- button bases
- card frames
- panel shells
- borders
- ribbons
- ornaments
- icon backplates
- slot backgrounds
- nine-slice backgrounds

Rules:

- Do not bake in dynamic labels.
- Do not bake in prices or mutable numbers.
- Do not bake in effect text or localization-sensitive text.
- Prefer transparent background unless the asset is a full background plate.
- Mark whether the asset must support nine-slice stretching.
- Mark whether the asset needs hover, press, disabled, selected, or rarity variants.

## Display Art

Use this category for:

- banners
- chapter art
- atmosphere illustrations
- activity posters
- preview-only assembled UI shots

Rules:

- This art may contain full composition and sample text.
- This art is not a reusable editor asset by default.
- If a display image looks like a panel mockup, do not import it as a shell without splitting it first.

## Automatic Rejection Signals

Flag an image as invalid for reusable Y3 import if:

- the full panel is flattened into one bitmap
- the button label is baked into the button base
- counters, costs, or dynamic stats are baked in
- the image is expected to stretch but has no nine-slice plan
- one asset is pretending to cover multiple UI states without variants
```

- [ ] **Step 4: Write the prompt template reference**

Write this content to `C:\Users\裴浩然\.codex\skills\y3-ui-art-pipeline\references\prompt-templates.md`:

```md
# Prompt Templates

## Reusable Resource Asset Prompt

Use this skeleton for source assets:

```text
Resource type: <button base / card frame / panel shell / ornament / icon backplate>
Use in Y3: reusable editor-facing asset
Background: <transparent / opaque>
Nine-slice: <required / not required>
State variants: <normal / hover / press / disabled / selected / rarity variants>
Allowed baked content: decorative visuals only
Forbidden baked content: dynamic text, prices, counters, localized strings, hotkeys, mutable icons
Target size: <width x height>
Style direction: <theme>
Material cues: <metal / glass / painted enamel / arcane glow / etc>
Notes: isolate the asset, centered, clean silhouette, suitable for reuse
```

## Preview Composite Prompt

Use this skeleton for review-only previews:

```text
Preview type: assembled Y3 UI mockup
Purpose: review composition before editor landing
Asset set shown: <list>
May include sample text: yes
May include sample numbers: yes
Do not treat output as reusable source asset
Target scene: <panel / card trio / button row / popup>
Style direction: <theme>
Review focus: readability, composition, visual hierarchy, cohesion
```
```

- [ ] **Step 5: Write the review checklist reference**

Write this content to `C:\Users\裴浩然\.codex\skills\y3-ui-art-pipeline\references\review-checklist.md`:

```md
# Review Checklist

Run this checklist before treating any UI art direction as ready:

- Is this output a reusable asset, a preview composite, or both?
- Does any reusable asset bake in dynamic text?
- Does any reusable asset bake in prices, counters, or mutable values?
- Is any full composite panel being mislabeled as a shell?
- Does any stretchable frame or background need nine-slice handling?
- Does any interactive asset need state variants?
- Does the preview composite look good enough to justify editor landing?

## Approval Gate

Do not proceed to editor-facing work until the user has approved the preview direction.
```

- [ ] **Step 6: Inspect the created files**

Run: `Get-ChildItem -Recurse 'C:\Users\裴浩然\.codex\skills\y3-ui-art-pipeline' | Select-Object FullName`
Expected: the skill directory lists `SKILL.md` and the three reference files.

- [ ] **Step 7: Commit the skill skeleton**

Run:

```powershell
git add -- 'C:\Users\裴浩然\.codex\skills\y3-ui-art-pipeline'
git commit -m "feat: add y3 ui art pipeline skill skeleton"
```

Expected: git creates a commit containing the new skill folder.

### Task 2: Tighten Triggering and Routing Language

**Files:**
- Modify: `C:\Users\裴浩然\.codex\skills\y3-ui-art-pipeline\SKILL.md`
- Test: `C:\Users\裴浩然\.codex\skills\y3-ui-art-pipeline\SKILL.md`

- [ ] **Step 1: Add explicit trigger phrases to `SKILL.md`**

Update the opening body section so it includes these trigger examples:

```md
Trigger this skill when the user asks for things like:

- "做 UI 资源图"
- "做按钮底图"
- "做卡片壳子"
- "做面板框"
- "判断这张图能不能导入 Y3"
- "先出素材图，再给我看成品预览"
- "同时给我资源图和预览效果图"
```

- [ ] **Step 2: Add explicit routing wording**

Append this section to `SKILL.md`:

```md
## Downstream Handoff Contract

When handing off to `imagegen`, provide two separate prompt intents:

- reusable source asset prompt
- preview composite prompt

When handing off to `y3-ui-generator`, provide:

- approved asset list
- which elements must stay as widgets
- nine-slice and background constraints
- any preview-approved visual notes
```

- [ ] **Step 3: Re-read the skill file**

Run: `Get-Content -Raw 'C:\Users\裴浩然\.codex\skills\y3-ui-art-pipeline\SKILL.md'`
Expected: the file reads clearly, keeps routing explicit, and does not absorb image generation or panel JSON implementation details.

- [ ] **Step 4: Commit the trigger and routing update**

Run:

```powershell
git add -- 'C:\Users\裴浩然\.codex\skills\y3-ui-art-pipeline\SKILL.md'
git commit -m "refactor: tighten y3 ui art pipeline triggers"
```

Expected: git creates a small follow-up commit.

### Task 3: Add Preview-Gate and Dual-Deliverable Guidance

**Files:**
- Modify: `C:\Users\裴浩然\.codex\skills\y3-ui-art-pipeline\SKILL.md`
- Modify: `C:\Users\裴浩然\.codex\skills\y3-ui-art-pipeline\references\review-checklist.md`
- Test: `C:\Users\裴浩然\.codex\skills\y3-ui-art-pipeline\SKILL.md`

- [ ] **Step 1: Add a fixed workflow block to `SKILL.md`**

Insert this workflow block after the hard rules:

```md
## Workflow

1. Classify the request
2. Split reusable assets from widget-owned content
3. Validate any user-provided candidate images
4. Produce the resource asset list
5. Produce the preview composite plan
6. Stop for user approval
7. Only after approval, route downstream
```

- [ ] **Step 2: Add dual-deliverable wording**

Append this section to `SKILL.md`:

```md
## Dual Deliverables

When relevant, provide both:

- source assets for actual Y3 import or import planning
- preview composites for visual review

Preview composites are allowed to contain sample text and sample numbers. Source assets are not.
```

- [ ] **Step 3: Expand the review checklist with a stop condition**

Append this section to `references/review-checklist.md`:

```md
## Stop Conditions

Stop and explain the issue if:

- the user is about to import a preview composite as a reusable source asset
- the current result still bakes dynamic text into a reusable asset
- the preview direction has not been approved yet
```

- [ ] **Step 4: Re-read the updated files**

Run:

```powershell
Get-Content -Raw 'C:\Users\裴浩然\.codex\skills\y3-ui-art-pipeline\SKILL.md'
Get-Content -Raw 'C:\Users\裴浩然\.codex\skills\y3-ui-art-pipeline\references\review-checklist.md'
```

Expected: the dual-deliverable model and approval gate are obvious and cannot be missed by a future agent.

- [ ] **Step 5: Commit the preview-gate update**

Run:

```powershell
git add -- 'C:\Users\裴浩然\.codex\skills\y3-ui-art-pipeline\SKILL.md' 'C:\Users\裴浩然\.codex\skills\y3-ui-art-pipeline\references\review-checklist.md'
git commit -m "feat: add preview gate to y3 ui art pipeline"
```

Expected: git creates a commit focused on the approval gate and dual outputs.

### Task 4: Validate Skill Structure and Frontmatter

**Files:**
- Test: `C:\Users\裴浩然\.codex\skills\y3-ui-art-pipeline\SKILL.md`
- Test: `C:\Users\裴浩然\.codex\skills\y3-ui-art-pipeline\references\asset-rules.md`
- Test: `C:\Users\裴浩然\.codex\skills\y3-ui-art-pipeline\references\prompt-templates.md`
- Test: `C:\Users\裴浩然\.codex\skills\y3-ui-art-pipeline\references\review-checklist.md`

- [ ] **Step 1: Run a frontmatter sanity check**

Run:

```powershell
$content = Get-Content -Raw 'C:\Users\裴浩然\.codex\skills\y3-ui-art-pipeline\SKILL.md'
$content.Substring(0, [Math]::Min($content.Length, 400))
```

Expected: the file starts with YAML frontmatter containing only `name` and `description`.

- [ ] **Step 2: Run a quick keyword search**

Run:

```powershell
rg -n "preview|resource|dynamic text|y3-ui-generator|imagegen|mixed|nine-slice" 'C:\Users\裴浩然\.codex\skills\y3-ui-art-pipeline'
```

Expected: matches appear in the skill and reference files, proving the key routing and review concepts are represented.

- [ ] **Step 3: Verify the folder contents**

Run:

```powershell
Get-ChildItem -Recurse 'C:\Users\裴浩然\.codex\skills\y3-ui-art-pipeline' | Format-Table FullName
```

Expected: exactly the intended small skill structure is present.

- [ ] **Step 4: Commit any final validation-only touchups**

Run:

```powershell
git status --short
```

Expected: either no further edits are needed, or only tiny cleanup edits remain before the final commit.

### Task 5: Record the Skill in Project Docs

**Files:**
- Modify: `docs/superpowers/specs/2026-04-14-y3-ui-art-pipeline-design.md`
- Test: `docs/superpowers/specs/2026-04-14-y3-ui-art-pipeline-design.md`

- [ ] **Step 1: Add an implementation status note to the design spec**

Append this note to `docs/superpowers/specs/2026-04-14-y3-ui-art-pipeline-design.md` after implementation begins:

```md
## Implementation Status

- Skill folder created
- Core `SKILL.md` authored
- Reference files authored
- Validation completed
```

- [ ] **Step 2: Re-read the design spec**

Run: `Get-Content -Raw 'docs\superpowers\specs\2026-04-14-y3-ui-art-pipeline-design.md'`
Expected: the spec still matches the implemented scope and does not drift from the created skill.

- [ ] **Step 3: Commit the documentation sync**

Run:

```powershell
git add -- 'docs/superpowers/specs/2026-04-14-y3-ui-art-pipeline-design.md'
git commit -m "docs: sync y3 ui art pipeline implementation status"
```

Expected: git creates a commit recording that the spec and implementation are aligned.

## Self-Review

### Spec coverage

This plan covers the required pieces from the spec:

- new skill folder and naming
- coordinator-only scope
- asset taxonomy through `SKILL.md` and references
- resource vs preview split
- review gate before editor-facing landing
- handoff to `y3-ui-generator`
- handoff to `imagegen`
- validation of triggering and frontmatter

No spec requirement is currently uncovered.

### Placeholder scan

The plan includes exact file paths, concrete file contents, concrete commands, and expected outcomes. There are no `TBD`, `TODO`, or "implement later" placeholders.

### Type consistency

The file names, skill name, routing targets, and deliverable terms are consistent across all tasks:

- skill name: `y3-ui-art-pipeline`
- routing targets: `y3-ui-generator`, `imagegen`
- deliverables: resource assets and preview composites
