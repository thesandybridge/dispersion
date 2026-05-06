// Handoff cards — design tokens, type stack, math notes, component anatomy.
// These render as DCArtboards on the canvas so the coding agent can read
// them off alongside the visual design.

function TokenCard() {
    const swatches = [
        { name: 'fairway-50', val: '#f4efe3', text: '#1a2419' },
        { name: 'bentgrass', val: '#62b375', text: '#0a1410' },
        { name: 'fairway-shadow', val: '#2c8a5e', text: '#fff' },
        { name: 'rough', val: '#16624a', text: '#fff' },
        { name: 'pine', val: '#0b3d2e', text: '#fff' },
        { name: 'soil-900', val: '#1a2419', text: '#f4efe3' },
        { name: 'sand', val: '#f0e7b8', text: '#1a2419' },
        { name: 'flag', val: '#e85d4d', text: '#fff' },
        { name: 'water', val: '#1f3a5f', text: '#fff' },
        { name: 'ink', val: '#0e1a13', text: '#f4efe3' },
    ];
    return (
        <div style={cardWrap}>
            <CardTitle>Color tokens</CardTitle>
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(2, 1fr)', gap: 8 }}>
                {swatches.map((s) => (
                    <div key={s.name} style={{ background: s.val, color: s.text, padding: 12, borderRadius: 8, fontFamily: 'ui-monospace, monospace', fontSize: 11 }}>
                        <div style={{ fontWeight: 600 }}>--clr-{s.name}</div>
                        <div style={{ opacity: 0.8 }}>{s.val}</div>
                    </div>
                ))}
            </div>
            <div style={{ fontSize: 11, color: 'rgba(26,36,25,0.55)', marginTop: 16, lineHeight: 1.55 }}>
                Heat-map ramp: <code>pine → rough → fairway-shadow → bentgrass → sage → sand</code>. Light theme inverts ink/fairway-50; course theme keeps ink as background.
            </div>
        </div>
    );
}

function TypeCard() {
    return (
        <div style={cardWrap}>
            <CardTitle>Type system</CardTitle>
            <div style={{ borderBottom: '1px solid rgba(26,36,25,0.08)', paddingBottom: 18, marginBottom: 18 }}>
                <div style={{ fontSize: 10, letterSpacing: '0.18em', color: 'rgba(26,36,25,0.5)', textTransform: 'uppercase', marginBottom: 6 }}>
                    Display · Fraunces
                </div>
                <div style={{ fontFamily: '"Fraunces", serif', fontSize: 56, lineHeight: 1, letterSpacing: '-0.02em' }}>
                    168<span style={{ fontSize: 22, color: 'rgba(26,36,25,0.5)', marginLeft: 4 }}>YDS</span>
                </div>
                <div style={{ fontSize: 11, color: 'rgba(26,36,25,0.55)', marginTop: 8, fontFamily: 'ui-monospace, monospace' }}>
                    400, 500 · -0.02em tracking · tabular-nums on numerals
                </div>
            </div>
            <div style={{ borderBottom: '1px solid rgba(26,36,25,0.08)', paddingBottom: 18, marginBottom: 18 }}>
                <div style={{ fontSize: 10, letterSpacing: '0.18em', color: 'rgba(26,36,25,0.5)', textTransform: 'uppercase', marginBottom: 6 }}>
                    UI · Inter
                </div>
                <div style={{ fontFamily: 'Inter, system-ui, sans-serif', fontSize: 16 }}>
                    7 Iron · 71% in zone
                </div>
                <div style={{ fontFamily: 'Inter, system-ui, sans-serif', fontSize: 13, color: 'rgba(26,36,25,0.6)', marginTop: 4 }}>
                    Body, labels, buttons. 13/14/16. Weights 400/500/600.
                </div>
            </div>
            <div>
                <div style={{ fontSize: 10, letterSpacing: '0.18em', color: 'rgba(26,36,25,0.5)', textTransform: 'uppercase', marginBottom: 6 }}>
                    Mono · JetBrains Mono
                </div>
                <div style={{ fontFamily: 'ui-monospace, "JetBrains Mono", monospace', fontSize: 13 }}>
                    σ↕ 7  σ↔ 9  EXP 168y
                </div>
                <div style={{ fontSize: 11, color: 'rgba(26,36,25,0.55)', marginTop: 4, fontFamily: 'ui-monospace, monospace' }}>
                    Stats, deltas, code, system labels.
                </div>
            </div>
        </div>
    );
}

function MathCard() {
    return (
        <div style={cardWrap}>
            <CardTitle>Math · probability of in-zone</CardTitle>
            <div style={{ background: '#0e1a13', color: '#f4efe3', padding: 16, borderRadius: 10, fontFamily: 'ui-monospace, "JetBrains Mono", monospace', fontSize: 12, lineHeight: 1.7, overflow: 'auto' }}>
                <div style={{ color: 'rgba(244,239,227,0.5)' }}>// X_long ~ N(carry, carrySd²)</div>
                <div style={{ color: 'rgba(244,239,227,0.5)' }}>// X_lat  ~ N(0, lateralSd²), independent</div>
                <br />
                <div>{`P(in zone) =`}</div>
                <div style={{ paddingLeft: 14, color: '#a9d18e' }}>{`(Φ((longMax − carry)/carrySd) − Φ((longMin − carry)/carrySd))`}</div>
                <div style={{ paddingLeft: 14 }}>{`× (Φ((latMax)/lateralSd) − Φ((latMin)/lateralSd))`}</div>
                <br />
                <div>{`Φ(x) = 0.5 · (1 + erf(x / √2))`}</div>
                <div style={{ color: 'rgba(244,239,227,0.5)' }}>// erf via Abramowitz & Stegun 7.1.26</div>
            </div>
            <div style={{ marginTop: 14, fontSize: 12, color: 'rgba(26,36,25,0.65)', lineHeight: 1.55 }}>
                Implement <code style={code}>phi(z)</code> and <code style={code}>probabilityInZone(club, scenario)</code> as two pure functions. No stats lib. Vitest cases: tighter σ wins on small zones, loses on huge ones; centered + huge zone → 1; far-shifted zone → 0; lateral sign-flip invariance; A&S example.
            </div>
        </div>
    );
}

function AnatomyCard() {
    return (
        <div style={cardWrap}>
            <CardTitle>Components · anatomy</CardTitle>
            <Row2 label="<DispersionViz>" hint="SVG · pure props · no internal state" />
            <Row2 label="<ClubRow>" hint="rank · name · σ·σ · mini-bar · prob" />
            <Row2 label="<ZoneEditor>" hint="W/D sliders · presets row · live preview" />
            <Row2 label="<ProbabilityBadge>" hint="STRONGLY FAVORED / FAVORED / MARGINAL / POOR" />
            <Row2 label="<DispersionGlyph>" hint="44×28 inline SVG, used in club lists" />
            <Row2 label="<ThemePicker>" hint="light · dark · course (default)" />
            <div style={{ marginTop: 18, padding: 14, background: '#fef9eb', borderRadius: 10, fontSize: 12, color: '#5a4a2a', lineHeight: 1.55 }}>
                <strong>Stack note:</strong> All viz is SVG, no canvas. Heat-map ring colors are stops on a single OKLCH ramp — keep the ramp in <code style={code}>tokens.css</code> so light/dark/course themes can swap it independently of the dispersion math.
            </div>
        </div>
    );
}

function PhasesCard() {
    return (
        <div style={cardWrap}>
            <CardTitle>Build phases · per the brief</CardTitle>
            {[
                { n: '01', name: 'Scaffold + types + math + tests', detail: 'Vite + RTS + Tailwind + Vitest. types.ts · math/probability.ts · math/probability.test.ts. Stop here.' },
                { n: '02', name: 'Clubs page', detail: 'CRUD list, validate σ > 0, persist via Zustand + localStorage adapter.' },
                { n: '03', name: 'Calculator page', detail: 'Distance + zone editor + ranked results, viz on top, alternates below.' },
                { n: '04', name: 'Settings + onboarding + polish', detail: 'Export/import JSON, theme switcher, dev tools, 4-step onboarding for empty state.' },
            ].map((p) => (
                <div key={p.n} style={{ display: 'grid', gridTemplateColumns: '40px 1fr', gap: 12, padding: '14px 0', borderTop: '1px solid rgba(26,36,25,0.07)' }}>
                    <div style={{ fontFamily: '"Fraunces", serif', fontSize: 26, color: 'rgba(26,36,25,0.35)', lineHeight: 1 }}>
                        {p.n}
                    </div>
                    <div>
                        <div style={{ fontWeight: 500, fontSize: 14 }}>{p.name}</div>
                        <div style={{ fontSize: 12, color: 'rgba(26,36,25,0.6)', marginTop: 4, lineHeight: 1.5 }}>{p.detail}</div>
                    </div>
                </div>
            ))}
        </div>
    );
}

const cardWrap = {
    width: '100%', height: '100%', overflow: 'auto',
    background: '#fbf8ef', color: '#1a2419',
    fontFamily: 'Inter, system-ui, sans-serif',
    padding: 24,
};

const code = {
    fontFamily: 'ui-monospace, monospace',
    fontSize: '0.92em',
    background: 'rgba(26,36,25,0.06)',
    padding: '1px 5px',
    borderRadius: 4,
};

function CardTitle({ children }) {
    return (
        <div style={{ marginBottom: 18 }}>
            <div style={{ fontSize: 10, letterSpacing: '0.22em', textTransform: 'uppercase', color: '#62b375', marginBottom: 6 }}>
                ◆ Handoff
            </div>
            <div style={{ fontFamily: '"Fraunces", serif', fontSize: 24, fontWeight: 400, letterSpacing: '-0.01em' }}>
                {children}
            </div>
        </div>
    );
}

function Row2({ label, hint }) {
    return (
        <div style={{ display: 'flex', justifyContent: 'space-between', padding: '10px 0', borderTop: '1px solid rgba(26,36,25,0.07)', gap: 16 }}>
            <span style={{ fontFamily: 'ui-monospace, monospace', fontSize: 12, color: '#1a2419', fontWeight: 500 }}>{label}</span>
            <span style={{ fontSize: 12, color: 'rgba(26,36,25,0.6)', textAlign: 'right' }}>{hint}</span>
        </div>
    );
}

window.TokenCard = TokenCard;
window.TypeCard = TypeCard;
window.MathCard = MathCard;
window.AnatomyCard = AnatomyCard;
window.PhasesCard = PhasesCard;
