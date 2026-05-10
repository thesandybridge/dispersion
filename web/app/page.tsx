import { Header } from "@/components/Header";
import { Hero } from "@/components/Hero";
import { MarqueeStrip } from "@/components/MarqueeStrip";
import { BentoGrid } from "@/components/BentoGrid";
import { HowItWorks } from "@/components/HowItWorks";
import { DemoSection } from "@/components/DemoSection";
import { CallToAction } from "@/components/CallToAction";
import { Footer } from "@/components/Footer";

export default function HomePage() {
  return (
    <main className="relative">
      <Header />
      <Hero />
      <MarqueeStrip />
      <BentoGrid />
      <HowItWorks />
      <DemoSection />
      <CallToAction />
      <Footer />
    </main>
  );
}
