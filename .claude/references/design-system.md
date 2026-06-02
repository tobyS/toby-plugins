# Design System Reference

> **Placeholder:** Replace this with your project's actual design system tokens. This file is used by the `/design_explore` command to create faithful mockups.

Stable atomic design patterns for creating faithful mockups. This file covers **tokens and conventions** that rarely change. Component structure and layout are researched from the live codebase at runtime by the `/design_explore` command.

## Colors — Read from Source

**Do NOT use hardcoded color values.** Always read the Tailwind config (or the project's CSS/theme source) to get the current color palettes.

### How to build the Tailwind CDN config

1. Read your project's CSS entry point for CSS custom properties (e.g. `globals.css`, `main.css`)
2. Read your project's Tailwind config (e.g. `tailwind.config.js` / `tailwind.config.ts`) for any extended theme
3. Extract all color values from CSS variables and theme extensions
4. Construct the CDN config block:

```javascript
tailwind.config = {
  darkMode: "class",
  theme: {
    extend: {
      colors: {
        // Paste color objects extracted from your config
      },
    },
  },
};
```

### Semantic Color Aliases

Define your project's semantic aliases here (verify mapping in CSS/config):

| Semantic      | Usage                                   |
| ------------- | --------------------------------------- |
| `primary`     | Main brand actions, links, focus rings  |
| `accent`      | Highlights, attention-grabbing elements |
| `destructive` | Destructive actions, error states       |
| `muted`       | Subtle backgrounds and text             |

## Typography

### Font Stack

Document your project's font stack here. Check your CSS entry point and root layout for the actual fonts in use.

### Text Patterns

Document your text patterns here. Example:

| Context         | Classes                             |
| --------------- | ----------------------------------- |
| Page heading    | `text-2xl font-bold tracking-tight` |
| Section heading | `text-xl font-semibold`             |
| Body text       | `text-sm text-muted-foreground`     |
| Form label      | `text-sm font-medium`               |

## Buttons

Document your button variants here (primary, secondary, destructive, outline, ghost, etc.) with the classes or component API your project uses.

## Form Inputs

Document your input styles here (text inputs, textareas, selects, checkboxes, etc.).

## Icons

Document your icon library here (e.g., the icon set and how icons are imported/used).

## Spacing Conventions

Document your spacing conventions here. Example:

| Element           | Values                                                       |
| ----------------- | ------------------------------------------------------------ |
| Page padding      | `px-4 sm:px-6 lg:px-8`                                        |
| Content max-width | `max-w-7xl` (main), `max-w-3xl` (settings)                   |
| Border radius     | `rounded-md` (buttons, inputs), `rounded-lg` (cards, modals) |

## Dark Mode

Document your dark mode strategy and key mappings here if applicable.

## Mock Data Guidelines

When creating mockups for this application, use realistic, domain-appropriate data (not "Lorem ipsum"). Document your domain's conventions here, for example:

- **User names**: [realistic names for your domain]
- **Entities**: [the core objects your app manages]
- **Topics / labels**: [domain-specific categories or tags]
- **Organizations**: [the kinds of organizations your users belong to]
