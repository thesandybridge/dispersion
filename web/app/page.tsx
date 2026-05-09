import { Header } from "@/components/Header";
import { Hero } from "@/components/Hero";
import { FeatureGrid } from "@/components/FeatureGrid";
import { DemoSection } from "@/components/DemoSection";
import { CallToAction } from "@/components/CallToAction";
import { Footer } from "@/components/Footer";

export default function HomePage() {
  return (
    <main className="relative">
      <Header />
      <Hero />
      <FeatureGrid />
      <DemoSection />
      <CallToAction />
      <Footer />
    </main>
  );
}
