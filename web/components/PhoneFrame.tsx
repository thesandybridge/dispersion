"use client";

// Lightweight iPhone-ish device frame for showcasing the app's UI on
// the marketing site. Pure CSS — no images. The frame's chrome reads
// as iOS without claiming to be a 1:1 reproduction.

import type { ReactNode } from "react";

interface Props {
  children: ReactNode;
  /// Side-by-side floating: a soft drop shadow + slight rotation feel
  /// great in a hero. For inline use (e.g. inside DemoSection) pass
  /// floating={false} for a flat presentation.
  floating?: boolean;
  className?: string;
}

export function PhoneFrame({ children, floating = true, className = "" }: Props) {
  return (
    <div
      className={`relative ${className}`}
      style={
        floating
          ? {
              filter: "drop-shadow(0 50px 60px rgba(11, 61, 46, 0.25))",
            }
          : undefined
      }
    >
      <div
        className="relative mx-auto overflow-hidden"
        style={{
          width: "min(100%, 320px)",
          aspectRatio: "9 / 19.5",
          borderRadius: "44px",
          padding: "10px",
          background:
            "linear-gradient(160deg, #1a2419 0%, #0a1410 60%, #1a2419 100%)",
          boxShadow:
            "inset 0 0 0 1.5px rgba(255, 255, 255, 0.08), inset 0 0 0 4px rgba(0, 0, 0, 0.45)",
        }}
      >
        {/* Screen */}
        <div
          className="relative h-full w-full overflow-hidden"
          style={{
            borderRadius: "34px",
            background: "#0e1a13",
          }}
        >
          {/* Dynamic Island */}
          <div
            className="absolute left-1/2 top-2 z-20 -translate-x-1/2"
            style={{
              width: "94px",
              height: "30px",
              borderRadius: "20px",
              background: "#000",
            }}
            aria-hidden
          />
          {/* Content */}
          <div className="relative z-10 h-full w-full">{children}</div>
        </div>

        {/* Side buttons (purely cosmetic) */}
        <span
          aria-hidden
          className="absolute"
          style={{
            left: "-2px",
            top: "120px",
            width: "3px",
            height: "32px",
            borderRadius: "2px 0 0 2px",
            background: "rgba(255,255,255,0.10)",
          }}
        />
        <span
          aria-hidden
          className="absolute"
          style={{
            left: "-2px",
            top: "168px",
            width: "3px",
            height: "56px",
            borderRadius: "2px 0 0 2px",
            background: "rgba(255,255,255,0.10)",
          }}
        />
        <span
          aria-hidden
          className="absolute"
          style={{
            right: "-2px",
            top: "150px",
            width: "3px",
            height: "84px",
            borderRadius: "0 2px 2px 0",
            background: "rgba(255,255,255,0.10)",
          }}
        />
      </div>
    </div>
  );
}
