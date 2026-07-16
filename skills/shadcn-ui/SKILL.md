---
name: shadcn-ui
description: Provides complete shadcn/ui component library patterns including installation, configuration, and implementation of accessible React components. Use when setting up shadcn/ui, installing components, building forms with React Hook Form and Zod, customizing themes with Tailwind CSS, or implementing UI patterns like buttons, dialogs, dropdowns, tables, and complex form layouts.
allowed-tools: Read, Write, Bash, Edit, Glob
---

# shadcn/ui Component Patterns

## Overview

Expert guide for building accessible, customizable UI components with shadcn/ui, Radix UI, and Tailwind CSS. This skill provides comprehensive patterns for implementing production-ready components with full accessibility support.

## Table of Contents

- [When to Use](#when-to-use)
- [Quick Start](#quick-start)
- [Installation & Setup](#installation--setup)
- [Project Configuration](#project-configuration)
- [Core Components](#core-components)
  - [Button](#button-component)
  - [Input & Form Fields](#input--form-fields)
  - [Forms with Validation](#forms-with-validation)
  - [Card](#card-component)
  - [Dialog (Modal)](#dialog-modal-component)
  - [Select (Dropdown)](#select-dropdown-component)
  - [Sheet (Slide-over)](#sheet-slide-over-component)
  - [Menubar & Navigation](#menubar--navigation)
  - [Table](#table-component)
  - [Toast Notifications](#toast-notifications)
  - [Charts](#charts-component)
- [Advanced Patterns](#advanced-patterns)
- [Customization](#customization)
- [Next.js Integration](#nextjs-integration)
- [Best Practices](#best-practices)
- [Common Component Combinations](#common-component-combinations)

## When to Use

- Setting up a new project with shadcn/ui
- Installing or configuring individual components
- Building forms with React Hook Form and Zod validation
- Creating accessible UI components (buttons, dialogs, dropdowns, sheets)
- Customizing component styling with Tailwind CSS
- Implementing design systems with shadcn/ui
- Building Next.js applications with TypeScript
- Creating complex layouts and data displays

## Instructions

1. **Initialize Project**: Run `npx shadcn@latest init` to configure shadcn/ui
2. **Install Components**: Add components with `npx shadcn@latest add <component>`
3. **Configure Theme**: Customize CSS variables in globals.css for theming
4. **Import Components**: Use components from `@/components/ui/` directory
5. **Customize as Needed**: Modify component code directly in your project
6. **Add Form Validation**: Integrate React Hook Form with Zod schemas
7. **Test Accessibility**: Verify ARIA attributes and keyboard navigation

## Examples

### Complete Form with Validation

```tsx
"use client"

import { zodResolver } from "@hookform/resolvers/zod"
import { useForm } from "react-hook-form"
import { z } from "zod"
import { Button } from "@/components/ui/button"
import { Form, FormControl, FormField, FormItem, FormLabel, FormMessage } from "@/components/ui/form"
import { Input } from "@/components/ui/input"

const formSchema = z.object({
  email: z.string().email("Invalid email"),
  password: z.string().min(8, "Password must be at least 8 characters"),
})

export function LoginForm() {
  const form = useForm<z.infer<typeof formSchema>>({
    resolver: zodResolver(formSchema),
    defaultValues: { email: "", password: "" },
  })

  return (
    <Form {...form}>
      <form onSubmit={form.handleSubmit(console.log)} className="space-y-4">
        <FormField name="email" render={({ field }) => (
          <FormItem>
            <FormLabel>Email</FormLabel>
            <FormControl><Input type="email" {...field} /></FormControl>
            <FormMessage />
          </FormItem>
        )} />
        <Button type="submit">Login</Button>
      </form>
    </Form>
  )
}
```

## Constraints and Warnings

- **Not an NPM Package**: Components are copied to your project; you own the code
- **Registry Security**: Components installed via `npx shadcn@latest add` are fetched from remote registries (e.g., `ui.shadcn.com`); always verify the registry source is trusted before installation, and review generated component code before use in production
- **Custom Registry Validation**: When configuring custom registries in `components.json`, only use trusted private registry URLs; never point to untrusted third-party registry endpoints as they could inject malicious code
- **Client Components**: Most components require "use client" directive
- **Radix Dependencies**: Ensure all @radix-ui packages are installed
- **Tailwind Required**: Components rely on Tailwind CSS utilities
- **TypeScript**: Designed for TypeScript projects; type definitions included
- **Path Aliases**: Configure @ alias in tsconfig.json for imports
- **Dark Mode**: Set up dark mode with CSS variables or class strategy

## Quick Start

For new projects, use the automated setup:

```bash
# Create Next.js project with shadcn/ui
npx create-next-app@latest my-app --typescript --tailwind --eslint --app
cd my-app
npx shadcn@latest init

# Install essential components
npx shadcn@latest add button input form card dialog select
```

For existing projects:

```bash
# Install dependencies
npm install tailwindcss-animate class-variance-authority clsx tailwind-merge lucide-react

# Initialize shadcn/ui
npx shadcn@latest init
```

## What is shadcn/ui?

shadcn/ui is **not** a traditional component library or npm package. Instead:

- It's a **collection of reusable components** that you can copy into your project
- Components are **yours to customize** - you own the code
- Built with **Radix UI** primitives for accessibility
- Styled with **Tailwind CSS** utilities
- Includes CLI tool for easy component installation

## Installation & Setup

### Initial Setup

```bash
# Initialize shadcn/ui in your project
npx shadcn@latest init
```

During setup, you'll configure:
- TypeScript or JavaScript
- Style (Default, New York, etc.)
- Base color theme
- CSS variables or Tailwind CSS classes
- Component installation path

### Installing Individual Components

```bash
# Install a single component
npx shadcn@latest add button

# Install multiple components
npx shadcn@latest add button input form

# Install all components
npx shadcn@latest add --all
```

### Manual Installation

If you prefer manual setup:

```bash
# Install dependencies for a specific component
npm install @radix-ui/react-slot

# Copy component code from ui.shadcn.com
# Place in src/components/ui/
```

## Project Configuration

### Required Dependencies

```json
{
  "dependencies": {
    "@radix-ui/react-accordion": "^1.1.2",
    "@radix-ui/react-alert-dialog": "^1.0.5",
    "@radix-ui/react-dialog": "^1.0.5",
    "@radix-ui/react-dropdown-menu": "^2.0.6",
    "@radix-ui/react-label": "^2.0.2",
    "@radix-ui/react-select": "^2.0.0",
    "@radix-ui/react-separator": "^1.0.3",
    "@radix-ui/react-slot": "^1.0.2",
    "@radix-ui/react-toast": "^1.1.5",
    "class-variance-authority": "^0.7.0",
    "clsx": "^2.0.0",
    "lucide-react": "^0.294.0",
    "tailwind-merge": "^2.0.0",
    "tailwindcss-animate": "^1.0.7"
  }
}
```

### TSConfig Configuration

```json
{
  "compilerOptions": {
    "target": "es5",
    "lib": ["dom", "dom.iterable", "es6"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "forceConsistentCasingInFileNames": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "node",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [
      {
        "name": "next"
      }
    ],
    "baseUrl": ".",
    "paths": {
      "@/components/*": ["./src/components/*"],
      "@/lib/*": ["./src/lib/*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
```

### Tailwind Configuration

```js
// tailwind.config.js
/** @type {import('tailwindcss').Config} */
module.exports = {
  darkMode: ["class"],
  content: [
    './pages/**/*.{ts,tsx}',
    './components/**/*.{ts,tsx}',
    './app/**/*.{ts,tsx}',
    './src/**/*.{ts,tsx}',
  ],
  prefix: "",
  theme: {
    container: {
      center: true,
      padding: "2rem",
      screens: {
        "2xl": "1400px",
      },
    },
    extend: {
      colors: {
        border: "hsl(var(--border))",
        input: "hsl(var(--input))",
        ring: "hsl(var(--ring))",
        background: "hsl(var(--background))",
        foreground: "hsl(var(--foreground))",
        primary: {
          DEFAULT: "hsl(var(--primary))",
          foreground: "hsl(var(--primary-foreground))",
        },
        secondary: {
          DEFAULT: "hsl(var(--secondary))",
          foreground: "hsl(var(--secondary-foreground))",
        },
        destructive: {
          DEFAULT: "hsl(var(--destructive))",
          foreground: "hsl(var(--destructive-foreground))",
        },
        muted: {
          DEFAULT: "hsl(var(--muted))",
          foreground: "hsl(var(--muted-foreground))",
        },
        accent: {
          DEFAULT: "hsl(var(--accent))",
          foreground: "hsl(var(--accent-foreground))",
        },
        popover: {
          DEFAULT: "hsl(var(--popover))",
          foreground: "hsl(var(--popover-foreground))",
        },
        card: {
          DEFAULT: "hsl(var(--card))",
          foreground: "hsl(var(--card-foreground))",
        },
      },
      borderRadius: {
        lg: "var(--radius)",
        md: "calc(var(--radius) - 2px)",
        sm: "calc(var(--radius) - 4px)",
      },
      keyframes: {
        "accordion-down": {
          from: { height: "0" },
          to: { height: "var(--radix-accordion-content-height)" },
        },
        "accordion-up": {
          from: { height: "var(--radix-accordion-content-height)" },
          to: { height: "0" },
        },
      },
      animation: {
        "accordion-down": "accordion-down 0.2s ease-out",
        "accordion-up": "accordion-up 0.2s ease-out",
      },
    },
  },
  plugins: [require("tailwindcss-animate")],
}
```

### CSS Variables (globals.css)

```css
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  :root {
    --background: 0 0% 100%;
    --foreground: 222.2 84% 4.9%;
    --card: 0 0% 100%;
    --card-foreground: 222.2 84% 4.9%;
    --popover: 0 0% 100%;
    --popover-foreground: 222.2 84% 4.9%;
    --primary: 222.2 47.4% 11.2%;
    --primary-foreground: 210 40% 98%;
    --secondary: 210 40% 96.1%;
    --secondary-foreground: 222.2 47.4% 11.2%;
    --muted: 210 40% 96.1%;
    --muted-foreground: 215.4 16.3% 46.9%;
    --accent: 210 40% 96.1%;
    --accent-foreground: 222.2 47.4% 11.2%;
    --destructive: 0 84.2% 60.2%;
    --destructive-foreground: 210 40% 98%;
    --border: 214.3 31.8% 91.4%;
    --input: 214.3 31.8% 91.4%;
    --ring: 222.2 84% 4.9%;
    --radius: 0.5rem;
  }

  .dark {
    --background: 222.2 84% 4.9%;
    --foreground: 210 40% 98%;
    --card: 222.2 84% 4.9%;
    --card-foreground: 210 40% 98%;
    --popover: 222.2 84% 4.9%;
    --popover-foreground: 210 40% 98%;
    --primary: 210 40% 98%;
    --primary-foreground: 222.2 47.4% 11.2%;
    --secondary: 217.2 32.6% 17.5%;
    --secondary-foreground: 210 40% 98%;
    --muted: 217.2 32.6% 17.5%;
    --muted-foreground: 215 20.2% 65.1%;
    --accent: 217.2 32.6% 17.5%;
    --accent-foreground: 210 40% 98%;
    --destructive: 0 62.8% 30.6%;
    --destructive-foreground: 210 40% 98%;
    --border: 217.2 32.6% 17.5%;
    --input: 217.2 32.6% 17.5%;
    --ring: 212.7 26.8% 83.9%;
  }
}

@layer base {
  * {
    @apply border-border;
  }
  body {
    @apply bg-background text-foreground;
  }
}
```


---

## Reference Files

Detailed component code, patterns, and configuration are in the `references/` folder:

- **[Core Components](references/components.md)** - Button, Input, Form (with Zod validation), Card, Dialog, Select, Sheet, Menubar, Table, Toast, Charts - with full code examples
- **[Customization](references/customization.md)** - CSS variables, Tailwind config, dark mode, component theming
- **[Next.js Integration](references/nextjs-integration.md)** - App Router setup, Server Components, layout patterns, data fetching with shadcn/ui
- **[Advanced Patterns](references/advanced-patterns.md)** - Compound components, controlled/uncontrolled, portal usage, animation with Framer Motion
- **[Best Practices & Common Combinations](references/best-practices.md)** - Accessibility, type safety, login form, dashboard layout, data table patterns
