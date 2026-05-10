// Fine-grain SVG noise overlay used on top of the entire site for tactile
// feel. Pure inline SVG so it ships in the HTML and avoids a network
// roundtrip. Pointer-events disabled so it never blocks interaction.

export function NoiseTexture({ opacity = 0.04 }: { opacity?: number }) {
  return (
    <div
      aria-hidden
      className="pointer-events-none fixed inset-0 z-[1]"
      style={{
        opacity,
        mixBlendMode: "overlay",
        backgroundImage:
          "url(\"data:image/svg+xml;utf8," +
          encodeURIComponent(
            "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 220 220'>" +
              "<filter id='n'>" +
                "<feTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='2' stitchTiles='stitch'/>" +
                "<feColorMatrix values='0 0 0 0 0  0 0 0 0 0  0 0 0 0 0  0 0 0 0.6 0'/>" +
              "</filter>" +
              "<rect width='100%' height='100%' filter='url(%23n)' opacity='1'/>" +
            "</svg>"
          ) +
          "\")",
        backgroundSize: "220px 220px",
      }}
    />
  );
}
