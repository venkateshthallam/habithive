# Deployment Guide

## Deploy to Vercel (Recommended)

### Option 1: Via Vercel Dashboard (Easiest)

1. **Push to GitHub**
   ```bash
   cd frontend/landing_page
   git init
   git add .
   git commit -m "Initial commit"
   git remote add origin <your-repo-url>
   git push -u origin main
   ```

2. **Import to Vercel**
   - Go to [vercel.com](https://vercel.com)
   - Click "Add New Project"
   - Import your GitHub repository
   - Vercel will auto-detect Next.js settings
   - Click "Deploy"

3. **Custom Domain (Optional)**
   - Go to Project Settings → Domains
   - Add your custom domain (e.g., `habithive.app`)
   - Update DNS records as instructed

### Option 2: Via Vercel CLI

```bash
# Install Vercel CLI
npm i -g vercel

# Navigate to the landing page directory
cd frontend/landing_page

# Deploy
vercel

# For production deployment
vercel --prod
```

## Environment Setup

No environment variables are required for the current setup. If you add email service integration later:

```bash
# In Vercel Dashboard → Settings → Environment Variables
NEXT_PUBLIC_API_URL=your-api-url
EMAIL_SERVICE_KEY=your-key
```

## Root Directory Configuration

If deploying from a monorepo:
- In Vercel project settings, set **Root Directory** to `frontend/landing_page`
- Build Command: `npm run build`
- Output Directory: `.next`
- Install Command: `npm install`

## Post-Deployment Checklist

After deploying, update these URLs in your App Store Connect listing:

✅ **Privacy Policy URL**: `https://yourdomain.com/privacy`
✅ **Support URL**: `https://yourdomain.com/support`
✅ **Terms of Service URL**: `https://yourdomain.com/terms`
✅ **Marketing URL**: `https://yourdomain.com`

### App Store Specific URLs

For **Account Deletion** (required by Apple):
- URL: `https://yourdomain.com/account-deletion`
- Add this to App Privacy section in App Store Connect

## Updating Content

### To update the landing page:

1. Edit files in `app/page.tsx`
2. Commit and push to GitHub
3. Vercel auto-deploys on every push to main

### To update legal pages:

- Privacy Policy: `app/privacy/page.tsx`
- Terms of Service: `app/terms/page.tsx`
- Support: `app/support/page.tsx`
- Account Deletion: `app/account-deletion/page.tsx`

## Performance Optimization

The site is already optimized:
- ✅ Static generation (instant loading)
- ✅ Tailwind CSS (minimal bundle size)
- ✅ No external dependencies
- ✅ Responsive images ready

To add images:
1. Place in `/public` folder
2. Use Next.js `<Image>` component for optimization

## Custom Domain Setup

### DNS Configuration

If using a custom domain (e.g., `habithive.app`):

**For Apex Domain (habithive.app):**
```
Type: A
Name: @
Value: 76.76.21.21
```

**For www subdomain:**
```
Type: CNAME
Name: www
Value: cname.vercel-dns.com
```

### SSL Certificate

Vercel automatically provisions SSL certificates. Your site will be HTTPS within minutes of adding the domain.

## Monitoring & Analytics

Add analytics in `app/layout.tsx`:

```typescript
// Google Analytics example
import Script from 'next/script'

export default function RootLayout({ children }) {
  return (
    <html>
      <head>
        <Script src="https://www.googletagmanager.com/gtag/js?id=GA_ID" />
      </head>
      <body>{children}</body>
    </html>
  )
}
```

## Troubleshooting

### Build fails on Vercel
- Check Node version (should be 18+)
- Verify all dependencies are in package.json
- Check build logs for specific errors

### Custom domain not working
- Wait 24-48 hours for DNS propagation
- Verify DNS records in your domain provider
- Check Vercel domain settings

### Email forms not working
- Current forms are placeholders (log to console)
- Integrate with email service (e.g., SendGrid, Mailchimp)
- Add API routes in `app/api/` folder

## Support

For deployment issues:
- Vercel Docs: https://vercel.com/docs
- Next.js Docs: https://nextjs.org/docs
- GitHub Issues: Create an issue in your repo

## Cost

- **Vercel Free Tier**:
  - Perfect for landing pages
  - 100GB bandwidth/month
  - Unlimited static sites
  - Custom domains included

- **Pro Tier** ($20/month): Only needed for heavy traffic or analytics
