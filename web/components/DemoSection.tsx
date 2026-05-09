import Link from "next/link";
import { InteractiveDemo } from "./InteractiveDemo";

export function DemoSection() {
  return (
    <section
      id="demo"
      className="section surface-inverse pt-24 pb-28 sm:pt-32 sm:pb-36"
    >
      <div className="container-prose">
        <div className="max-w-2xl">
          <span
            className="eyebrow"
            style={{ color: "#a9d18e" }}
          >
            Try the math
          </span>
          <h2 className="mt-3 font-display text-display-xs font-semibold tracking-display-tight text-[#f6f1e1] sm:text-display-sm">
            Drag to set the shot. Watch the recommendation update.
          </h2>
          <p className="mt-4 text-lg leading-relaxed text-[#f6f1e1]/70">
            This runs the actual algorithm from the iOS app — same{" "}
            <Link
              href="/math"
              className="border-b border-[#62b375]/40 text-[#62b375] hover:border-[#62b375]"
            >
              probability calc
            </Link>
            , same DECADE bias, same sample bag. Move the slider, switch the
            target, see which club leads.
          </p>
        </div>

        <div className="mt-12">
          <InteractiveDemo />
        </div>
      </div>
    </section>
  );
}
