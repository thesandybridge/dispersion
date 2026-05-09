import type { Metadata } from "next";
import Link from "next/link";
import { PageLayout } from "@/components/PageLayout";

export const metadata: Metadata = {
  title: "Privacy",
  description:
    "Dispersion is local-first. Your bag, your shots, your courses, and your rounds live on your phone. No accounts, no servers, no telemetry.",
  alternates: { canonical: "/privacy" },
  openGraph: {
    title: "Privacy — Dispersion",
    description:
      "Local-first. No accounts, no servers, no telemetry.",
    url: "/privacy",
  },
};

const accentStrong = { color: "var(--accent-strong)" };

const LAST_UPDATED = "May 9, 2026";

export default function PrivacyPage() {
  return (
    <PageLayout
      eyebrow="Privacy"
      title={
        <>
          Your data stays on{" "}
          <span className="italic" style={{ color: "var(--accent)" }}>
            your phone
          </span>
          .
        </>
      }
      lede="Dispersion was built local-first by design. There are no accounts to sign up for, no servers to send data to, and no analytics to opt out of. This page describes what that means in practice."
    >
      <article className="container-prose pt-16 pb-20 sm:pt-20">
        <div className="prose prose-lg max-w-3xl space-y-12">
          {/* Summary card */}
          <div className="rounded-2xl surface-elev p-6">
            <div className="font-mono text-xs uppercase tracking-widest surface-muted">
              Tl;dr
            </div>
            <ul className="surface-soft mt-3 space-y-2 text-base">
              <li>
                <strong style={accentStrong}>·</strong> Every shot, club,
                round, and course you create is stored on-device only.
              </li>
              <li>
                <strong style={accentStrong}>·</strong> No account is required
                to use the app. We never ask for an email or phone number.
              </li>
              <li>
                <strong style={accentStrong}>·</strong> No analytics, no
                crash-reporting SDKs, no advertising IDs. Zero third-party
                trackers ship in the binary.
              </li>
              <li>
                <strong style={accentStrong}>·</strong> The only network calls
                the app makes are the optional ones <em>you</em> trigger:
                Apple Maps for course search, and (on supported devices) iOS
                location services to capture a shot's GPS position.
              </li>
            </ul>
          </div>

          {/* What we collect */}
          <section>
            <h2
              className="font-display text-display-xs font-semibold tracking-display-tight"
              style={accentStrong}
            >
              What Dispersion stores
            </h2>
            <p className="surface-soft mt-4 leading-relaxed">
              The app keeps the following on your device, in Apple's
              SwiftData store inside the app sandbox:
            </p>
            <ul className="surface-soft mt-4 list-disc space-y-2 pl-6 leading-relaxed">
              <li>
                Your <strong style={accentStrong}>bag</strong> — clubs, their
                stored carry distances, and σ values you enter or calibrate.
              </li>
              <li>
                Your <strong style={accentStrong}>shots</strong> — distance,
                lateral miss, swing type, outcome tags, optional face-strike
                position, and the session each shot belonged to.
              </li>
              <li>
                Your <strong style={accentStrong}>sessions and rounds</strong> — start time,
                club used, scoring data, GPS coordinates of recorded shots
                (if you enable location).
              </li>
              <li>
                Your <strong style={accentStrong}>courses</strong> — names,
                tee box and pin positions, polygons you traced for fairways
                / greens / hazards.
              </li>
              <li>
                Your <strong style={accentStrong}>preferences</strong> —
                units, theme accent, palette mode, lie multipliers, the
                tuning sliders, and onboarding completion state.
              </li>
            </ul>
            <p className="surface-soft mt-4 leading-relaxed">
              Nothing in this list is transmitted off-device by the app
              itself. If you tap <em>Share</em> on a course or bag tag, iOS
              hands the file to whatever destination <em>you</em> pick (Mail,
              Messages, AirDrop, etc.), and standard share-sheet rules
              apply from that point on.
            </p>
          </section>

          {/* Network */}
          <section>
            <h2
              className="font-display text-display-xs font-semibold tracking-display-tight"
              style={accentStrong}
            >
              Network usage
            </h2>
            <p className="surface-soft mt-4 leading-relaxed">
              Dispersion makes two kinds of outbound requests, both
              first-party Apple services:
            </p>
            <ul className="surface-soft mt-4 list-disc space-y-2 pl-6 leading-relaxed">
              <li>
                <strong style={accentStrong}>Apple Maps</strong> — when you
                search for a course or build a course on satellite imagery,
                Apple's MapKit handles the request. Apple's privacy policy
                applies to those interactions.
              </li>
              <li>
                <strong style={accentStrong}>Location services</strong> —
                purely opt-in. Used during a round if you tap the GPS shot
                button to capture your current position. Disable system-wide
                in iOS Settings → Privacy → Location Services if you'd
                rather not grant the permission.
              </li>
            </ul>
            <p className="surface-soft mt-4 leading-relaxed">
              The app does not sync to iCloud (today) and does not contain
              any background-fetch or background-location code. If iCloud
              sync is added in a future version, we will publish a clear
              opt-in toggle and an updated privacy notice before shipping it.
            </p>
          </section>

          {/* Tracking */}
          <section>
            <h2
              className="font-display text-display-xs font-semibold tracking-display-tight"
              style={accentStrong}
            >
              Tracking and analytics
            </h2>
            <p className="surface-soft mt-4 leading-relaxed">
              There is none. No Firebase, no Sentry, no Mixpanel, no
              Amplitude, no Facebook SDK, no Google Analytics, no
              custom ping-home telemetry. The App Store privacy nutrition
              label reflects this — Dispersion declares "Data Not Collected".
            </p>
            <p className="surface-soft mt-4 leading-relaxed">
              The marketing site you're reading right now uses one
              first-party traffic counter (no cookies, no IP retention) so
              we can see whether anyone visited. It does not identify you.
            </p>
          </section>

          {/* Children */}
          <section>
            <h2
              className="font-display text-display-xs font-semibold tracking-display-tight"
              style={accentStrong}
            >
              Children
            </h2>
            <p className="surface-soft mt-4 leading-relaxed">
              Dispersion is not directed at children under 13 and does not
              knowingly collect personal information from anyone — adult or
              child. Because no information leaves the device, there's
              nothing for us to inadvertently retain.
            </p>
          </section>

          {/* Export / delete */}
          <section>
            <h2
              className="font-display text-display-xs font-semibold tracking-display-tight"
              style={accentStrong}
            >
              Exporting and deleting
            </h2>
            <p className="surface-soft mt-4 leading-relaxed">
              Settings → Data lets you export a complete JSON snapshot of
              your bag, shots, sessions, courses, and rounds. Deleting the
              app from your iOS home screen wipes the SwiftData store with
              it — there is no server-side copy to also wipe.
            </p>
          </section>

          {/* Contact */}
          <section>
            <h2
              className="font-display text-display-xs font-semibold tracking-display-tight"
              style={accentStrong}
            >
              Questions
            </h2>
            <p className="surface-soft mt-4 leading-relaxed">
              If anything here is unclear or you'd like more detail about
              what the app does or doesn't do, the documentation in-app
              under Settings → About spells it out further. This page is
              the source of truth for how Dispersion treats your data.
            </p>
            <p className="surface-muted mt-8 font-mono text-xs uppercase tracking-widest">
              Last updated: {LAST_UPDATED}
            </p>
          </section>

          <section className="border-t pt-10" style={{ borderColor: "var(--border)" }}>
            <Link
              href="/"
              className="inline-flex items-center gap-2 text-base font-medium transition hover:text-[color:var(--accent)]"
              style={accentStrong}
            >
              <svg viewBox="0 0 24 24" fill="none" strokeWidth="2" stroke="currentColor" className="h-4 w-4">
                <path d="M19 12H5M12 5l-7 7 7 7" strokeLinecap="round" strokeLinejoin="round" />
              </svg>
              Back to the app
            </Link>
          </section>
        </div>
      </article>
    </PageLayout>
  );
}
