# HabitHive Landing Page

A beautiful, engaging landing page for HabitHive - the social habit tracking app that helps you build better habits together with friends.

## Features

- 🎨 Beautiful gradient design with honey/hive theme colors
- 🐝 Animated honeycomb grid visualizations
- 📱 Fully responsive design
- ⚡ Built with Next.js 14, TypeScript, and Tailwind CSS
- 🚀 Optimized for Vercel deployment
- 🎯 Conversion-optimized with multiple CTAs

## Getting Started

### Install Dependencies

```bash
npm install
```

### Run Development Server

```bash
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) to see the landing page.

### Build for Production

```bash
npm run build
npm start
```

## Deploy to Vercel

The easiest way to deploy this landing page is using [Vercel](https://vercel.com):

1. Push your code to a Git repository (GitHub, GitLab, or Bitbucket)
2. Import your repository to Vercel
3. Vercel will automatically detect Next.js and configure the build settings
4. Click "Deploy" and your landing page will be live!

Alternatively, use the Vercel CLI:

```bash
npm i -g vercel
vercel
```

## Project Structure

```
landing_page/
├── app/
│   ├── globals.css          # Global styles and Tailwind utilities
│   ├── layout.tsx           # Root layout with metadata
│   └── page.tsx             # Main landing page
├── components/              # Reusable components (add as needed)
├── public/                  # Static assets
├── tailwind.config.ts       # Tailwind configuration with custom colors
├── tsconfig.json           # TypeScript configuration
└── package.json            # Dependencies and scripts
```

## Customization

### Colors

The landing page uses custom honey and hive color palettes defined in `tailwind.config.ts`. Modify these to match your brand:

```typescript
colors: {
  honey: { /* shades of yellow/gold */ },
  hive: { /* shades of orange */ },
}
```

### Content

Edit `app/page.tsx` to update:
- Hero section text and stats
- Feature descriptions
- Social proof elements
- CTA buttons and forms

### Email Collection

The waitlist form currently logs to console. Connect it to your email service:

```typescript
const handleSubmit = async (e: React.FormEvent) => {
  e.preventDefault();
  // Add your email service integration here
  // Examples: Mailchimp, ConvertKit, SendGrid, etc.
};
```

## Performance

- Uses Next.js App Router for optimal performance
- Implements proper meta tags for SEO
- Optimized animations with CSS
- Lazy loading ready for images (add when needed)

## License

Private - HabitHive
