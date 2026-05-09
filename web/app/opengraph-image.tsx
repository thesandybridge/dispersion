// Auto-generated OpenGraph image for the landing page. Next.js renders this
// React component to a 1200×630 PNG at build time and serves it from
// /opengraph-image. Picked up by Twitter and Facebook scrapers automatically.

import { ImageResponse } from "next/og";

export const runtime = "edge";
export const alt = "Dispersion — probability-first golf";
export const size = { width: 1200, height: 630 };
export const contentType = "image/png";

export default function OGImage() {
  return new ImageResponse(
    (
      <div
        style={{
          height: "100%",
          width: "100%",
          display: "flex",
          flexDirection: "column",
          background:
            "linear-gradient(135deg, #0e1a13 0%, #16624a 60%, #2c8a5e 100%)",
          color: "#f6f1e1",
          padding: "80px 96px",
          fontFamily: '"Inter", system-ui, sans-serif',
        }}
      >
        <div
          style={{
            display: "flex",
            alignItems: "center",
            gap: 14,
            fontSize: 22,
            color: "#a9d18e",
            letterSpacing: 4,
            textTransform: "uppercase",
          }}
        >
          <div
            style={{
              width: 14,
              height: 14,
              borderRadius: 999,
              background: "#62b375",
            }}
          />
          Dispersion
        </div>
        <div
          style={{
            marginTop: "auto",
            display: "flex",
            flexDirection: "column",
            gap: 24,
          }}
        >
          <div
            style={{
              fontSize: 88,
              fontWeight: 600,
              letterSpacing: -3,
              lineHeight: 1.02,
              fontFamily: '"Fraunces", Georgia, serif',
              maxWidth: 980,
            }}
          >
            Hit the club{" "}
            <span style={{ color: "#a9d18e", fontStyle: "italic" }}>
              most likely
            </span>{" "}
            to land where you want it.
          </div>
          <div
            style={{
              fontSize: 24,
              color: "#cfcabc",
              maxWidth: 720,
              lineHeight: 1.4,
            }}
          >
            Probability-first club selection. Honest math. Local-first
            on iOS.
          </div>
        </div>
      </div>
    ),
    { ...size }
  );
}
