import type { Metadata, Viewport } from "next";
import "./globals.css";
import { ThemeProvider } from "@/components/ThemeProvider";
import { NoiseTexture } from "@/components/NoiseTexture";

const SITE_URL = "https://dispersion.app";
const APP_NAME = "Dispersion";
const TAGLINE = "Probability-first golf club selection.";
const DESCRIPTION =
  "Dispersion is an iOS app that picks the club most likely to land where you want it. Calibrate your bag with sigma values, model conditions, and stop guessing.";

export const metadata: Metadata = {
  metadataBase: new URL(SITE_URL),
  title: {
    default: `${APP_NAME} — ${TAGLINE}`,
    template: `%s · ${APP_NAME}`,
  },
  description: DESCRIPTION,
  applicationName: APP_NAME,
  authors: [{ name: "Dispersion" }],
  keywords: [
    "golf shot dispersion",
    "DECADE methodology",
    "golf club selection",
    "probability-based golf",
    "sigma golf",
    "shot pattern analysis",
    "iOS golf app",
  ],
  openGraph: {
    type: "website",
    url: SITE_URL,
    siteName: APP_NAME,
    title: `${APP_NAME} — ${TAGLINE}`,
    description: DESCRIPTION,
    images: [
      {
        url: "/og-image.png",
        width: 1200,
        height: 630,
        alt: `${APP_NAME} — ${TAGLINE}`,
      },
    ],
  },
  twitter: {
    card: "summary_large_image",
    title: `${APP_NAME} — ${TAGLINE}`,
    description: DESCRIPTION,
    images: ["/og-image.png"],
  },
  robots: {
    index: true,
    follow: true,
  },
};

export const viewport: Viewport = {
  themeColor: "#0b3d2e",
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        {/* Editorial display + body fonts. Loaded from Google Fonts so we
            don't have to ship binary font files in the repo. */}
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link
          rel="preconnect"
          href="https://fonts.gstatic.com"
          crossOrigin="anonymous"
        />
        <link
          href="https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,400;9..144,500;9..144,600&family=Inter:wght@400;500;600;700&display=swap"
          rel="stylesheet"
        />
        {/* SoftwareApplication structured data — the SEO money-maker */}
        <script
          type="application/ld+json"
          dangerouslySetInnerHTML={{
            __html: JSON.stringify({
              "@context": "https://schema.org",
              "@type": "SoftwareApplication",
              name: APP_NAME,
              applicationCategory: "SportsApplication",
              operatingSystem: "iOS 18.0",
              offers: {
                "@type": "Offer",
                price: "0",
                priceCurrency: "USD",
              },
              description: DESCRIPTION,
              url: SITE_URL,
            }),
          }}
        />
      </head>
      <body>
        <ThemeProvider>
          <NoiseTexture opacity={0.05} />
          {children}
        </ThemeProvider>
      </body>
    </html>
  );
}
