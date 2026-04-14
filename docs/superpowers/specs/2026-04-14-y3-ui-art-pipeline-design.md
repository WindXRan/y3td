---
title: Y3 UI Art Pipeline Design
date: 2026-04-14
status: draft-for-review
---

# Y3 UI Art Pipeline Design

## Goal

Create a new skill named `y3-ui-art-pipeline` that serves as the front door for Y3 UI art work.

The skill must prevent a common failure mode in the current workflow: treating a full rendered UI mockup as if it were a reusable Y3 UI resource image. It should classify the request, split the visual work into correct asset types, produce both reusable source assets and preview composites, and only allow editor-facing output after the user approves the preview result.

## Problem

Current UI art requests can easily collapse several different artifact types into one image:

- reusable UI resource images
- preview-only composite mockups
- dynamic text baked into bitmaps
- button labels and prices baked into button backgrounds
- full panel screenshots mislabeled as panel shells

This creates assets that may look acceptable in a static preview but are poor Y3 editor resources because they are not reusable, not localizable, not stateful, and not easy to adapt in the UI editor.

## Non-Goals

- Replacing `y3-ui-generator` for panel JSON generation
- Replacing `imagegen` as the general bitmap generation skill
- Automatically importing generated assets into the Y3 editor as part of the first version
- Solving all UI implementation problems inside one skill

## Recommended Architecture

Use a coordinator skill plus existing specialists.

Primary new skill:

- `y3-ui-art-pipeline`

Existing linked skills:

- `y3-ui-generator` for Y3 UI structure and JSON generation
- `imagegen` for bitmap generation and editing

The new skill is responsible for classification, decomposition, validation, review gates, and routing. It should not duplicate the detailed implementation workflows already covered by the linked skills.

## Asset Taxonomy

The skill must classify every request into one of three buckets:

1. `ui-resource-art`
Used for reusable editor-facing assets such as button bases, card frames, panel shells, borders, ribbons, slots, ornaments, icon backplates, and nine-slice backgrounds.

2. `display-art`
Used for preview, promotion, or atmosphere assets such as banners, chapter art, full-screen backdrops, activity posters, and decorative scene illustrations.

3. `mixed`
Used when a single feature needs both reusable UI assets and a composite preview image.

The default assumption should be `mixed` when the user is designing a new UI visual system or a new panel style.

## Core Principles

### 1. Resource images and composite previews are different deliverables

The skill must treat these as separate outputs.

- Resource images are editor-facing and reusable.
- Composite previews are review-facing and disposable unless explicitly kept.

### 2. Dynamic data must stay out of reusable resource images

The skill must explicitly forbid baking these into reusable assets:

- dynamic titles
- prices
- counters
- effect text
- level values
- localized strings
- hotkeys
- mutable icons

These should stay in Y3 controls unless the user explicitly asks for a preview composite.

### 3. No editor write before preview approval

The skill must enforce a human review gate:

- generate the resource plan
- generate the preview composite
- iterate until the user says it is worth landing
- only then continue toward editor-facing output

### 4. Every request produces a split plan

The skill should always produce a structured split:

- what must be a reusable image
- what must stay as Y3 text or widget data
- what is optional decorative bitmap work

## Workflow

### Step 1. Classify the request

Determine whether the work is:

- `ui-resource-art`
- `display-art`
- `mixed`

If unclear, prefer `mixed`.

### Step 2. Split the visual layers

Produce a decomposition table with at least these columns:

- item name
- category
- purpose
- should be bitmap or Y3 widget
- transparent background required or not
- nine-slice required or not
- text allowed to be baked in or not

### Step 3. Validate existing user-provided images

If the user provides candidate images, inspect them and label them as:

- valid resource image
- valid display image
- invalid for Y3 resource use

Common invalid patterns:

- whole panel rendered into one bitmap
- card art with dynamic labels baked in
- button image with price or action text baked in
- image intended to stretch but not designed for nine-slice use
- image meant for multiple states but only one state exists

### Step 4. Produce the asset list

For each required asset, output:

- asset id suggestion
- target use
- target size
- whether transparent background is required
- whether nine-slice is required
- whether state variants are required
- whether text bake-in is forbidden

### Step 5. Produce preview composites

Create one or more composite preview images that show the likely in-editor result.

These previews are not the assets themselves. They are review tools that help the user decide whether the art direction is worth landing.

The preview may contain text and layout composition that would be forbidden in the reusable source assets.

### Step 6. Review gate

The skill must stop and ask for approval after preview generation.

Only after the user confirms the preview direction is acceptable should the workflow continue to final asset generation or downstream editor work.

### Step 7. Route to downstream skills

Route according to need:

- bitmap generation or editing -> `imagegen`
- panel structure and JSON generation -> `y3-ui-generator`

## Output Contract

Every successful run of the skill should produce two parallel deliverable sets when relevant:

### A. Resource Asset Set

Examples:

- `choice-panel-shell`
- `choice-card-frame`
- `choice-button-base-blue`
- `choice-rarity-ribbon-r`
- `choice-divider-ornament`

Each item should be editor-usable or editor-plannable.

### B. Composite Preview Set

Examples:

- one full panel preview
- multiple style candidates
- one focused button-row preview
- one card-stack preview

This set exists to support repeated visual review before landing anything into the editor.

## Review Checklist

The skill should use a fixed review checklist before treating any result as ready:

- Does any reusable asset bake in dynamic text?
- Does any reusable asset bake in mutable numbers or prices?
- Is any full panel screenshot being mislabeled as a shell?
- Does any stretchable element need nine-slice but lack a nine-slice plan?
- Do button assets need hover, press, or disabled variants?
- Does the preview composite look coherent enough to justify editor landing?

## Interaction with Existing Skills

### With `y3-ui-generator`

`y3-ui-art-pipeline` should run before `y3-ui-generator` when the request includes new UI visual design.

It should hand off:

- approved asset list
- usage notes
- intended panel composition
- any nine-slice and background rules

### With `imagegen`

`y3-ui-art-pipeline` should call or recommend `imagegen` only after the split plan is clear.

It should provide generation prompts that distinguish:

- reusable source asset prompt
- preview composite prompt

This distinction is mandatory.

## Prompting Strategy

The skill should maintain two prompt families.

### Resource prompt family

Used for reusable assets.

Required characteristics:

- isolated asset
- no dynamic text
- transparent background by default when appropriate
- explicit statement about nine-slice suitability when needed
- explicit statement of state variants when needed

### Preview prompt family

Used for review composites.

Required characteristics:

- realistic assembled panel or section
- may include sample text and placeholder numbers
- framed as preview-only
- should help judge composition, spacing, readability, and style cohesion

## Suggested File Layout

Place the new skill in:

- `C:\Users\裴浩然\.codex\skills\y3-ui-art-pipeline`

Recommended contents:

- `SKILL.md`
- `references/asset-rules.md`
- `references/prompt-templates.md`
- `references/review-checklist.md`

Optional:

- `assets/examples/` for a few positive and negative references

## Triggering Guidance

The skill should trigger for requests involving:

- Y3 UI resource art
- button base art
- card frame art
- panel shell art
- UI decorative assets
- UI visual splitting
- preview composite generation for Y3 UI
- judging whether a UI image is suitable for editor import

It should also trigger when the user gives an existing UI image and asks whether it is a valid Y3 UI resource.

## Risks

### Over-generation risk

The workflow may generate polished preview composites that tempt people to skip proper reusable asset splitting.

Mitigation:

- explicitly label preview outputs as non-editor deliverables
- enforce the split plan before image generation

### Scope creep risk

The skill can become too broad if it starts absorbing all UI implementation and editor automation logic.

Mitigation:

- keep routing boundaries explicit
- leave editor JSON generation to `y3-ui-generator`
- leave bitmap execution to `imagegen`

### Ambiguity risk

Users may say "做个 UI 图" without clarifying whether they mean assets or presentation art.

Mitigation:

- classify into `mixed` by default
- always produce the split plan first

## Success Criteria

The skill is successful if it reliably causes future agents to:

- distinguish reusable assets from display composites
- refuse to treat baked full-screen mockups as reusable Y3 assets
- produce both resource assets and preview composites when useful
- stop for preview approval before editor-facing landing
- route cleanly into existing UI and image skills without duplicated logic

## Open Decisions Resolved

The following choices are fixed by this design:

- skill name: `y3-ui-art-pipeline`
- scope: both reusable UI assets and display-art previews
- default mode when unclear: `mixed`
- required outputs: resource assets plus preview composites when relevant
- required gate: no editor landing before preview approval

## Implementation Readiness

This design is ready to move into implementation planning for:

- creating the new skill folder
- authoring `SKILL.md`
- adding lean references
- defining linked-skill handoff rules
- validating the skill against realistic Y3 UI art requests

## Implementation Status

- Skill folder created at `C:\Users\裴浩然\.codex\skills\y3-ui-art-pipeline`
- Core `SKILL.md` authored
- Reference files authored
- Validation completed with `quick_validate.py` under UTF-8 Python execution
