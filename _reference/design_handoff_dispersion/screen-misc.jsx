// Onboarding + Settings screens.

function OnboardingScreen({ device = 'mobile', step = 1 }) {
    const isMobile = device === 'mobile';
    const totalSteps = 4;

    return (
        <div data-screen-label={`Onboarding · ${device} · step ${step}`} style={{
            width: '100%', height: '100%',
            background: '#0e1a13', color: '#f6f1e1',
            fontFamily: 'var(--ui-font, "Inter", system-ui, sans-serif)',
            display: 'flex', flexDirection: 'column', overflow: 'hidden',
            position: 'relative',
        }}>
            {/* topo decoration */}
            <div style={{ position: 'absolute', inset: 0, opacity: 0.5, pointerEvents: 'none' }}>
                <TopoBg width={isMobile ? 360 : 520} height={isMobile ? 600 : 760} seed={step * 7} color="rgba(98,179,117,0.12)" accent="rgba(232,93,77,0.4)" />
            </div>

            {/* progress dots */}
            <div style={{ display: 'flex', gap: 6, padding: '20px 22px 0', position: 'relative', zIndex: 1 }}>
                {Array.from({ length: totalSteps }).map((_, i) => (
                    <div key={i} style={{
                        flex: 1, height: 3, borderRadius: 999,
                        background: i < step ? '#62b375' : 'rgba(246,241,225,0.12)',
                    }} />
                ))}
            </div>

            <div style={{ flex: '1 1 auto', display: 'flex', flexDirection: 'column', padding: '40px 22px 22px', position: 'relative', zIndex: 1, minHeight: 0 }}>
                {step === 1 && <OnboardingHello />}
                {step === 2 && <OnboardingMath />}
                {step === 3 && <OnboardingFirstClub />}
                {step === 4 && <OnboardingReady />}
            </div>

            <div style={{ padding: '0 22px 26px', display: 'flex', gap: 10, position: 'relative', zIndex: 1 }}>
                {step > 1 && (
                    <button style={{
                        flex: '0 0 auto', padding: '14px 18px', borderRadius: 10,
                        background: 'transparent', color: 'rgba(246,241,225,0.7)',
                        border: '1px solid rgba(246,241,225,0.18)', fontFamily: 'inherit', fontSize: 14, cursor: 'pointer',
                    }}>Back</button>
                )}
                <button style={{
                    flex: '1 1 auto', padding: '14px', borderRadius: 10,
                    background: '#62b375', color: '#0a1410',
                    border: 'none', fontFamily: 'inherit', fontSize: 14, fontWeight: 600, cursor: 'pointer',
                    display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
                }}>
                    {step === totalSteps ? 'Open the bag' : 'Continue'}
                    <Icon.ChevronRight size={14} color="#0a1410" />
                </button>
            </div>
        </div>
    );
}

function OnboardingHello() {
    return (
        <div>
            <div style={{ fontSize: 11, letterSpacing: '0.24em', textTransform: 'uppercase', color: '#62b375', marginBottom: 18 }}>
                ◆ Dispersion · v1
            </div>
            <div style={{ fontFamily: 'var(--display-font, "Fraunces", serif)', fontSize: 44, lineHeight: 1.05, letterSpacing: '-0.02em', textWrap: 'pretty' }}>
                Hit the club <em style={{ color: '#a9d18e' }}>most likely</em> to land where you want it.
            </div>
            <div style={{ fontSize: 14, lineHeight: 1.55, color: 'rgba(246,241,225,0.65)', marginTop: 18, maxWidth: 320, textWrap: 'pretty' }}>
                A probability-first club selector for serious amateurs. You teach it your dispersion. It does the math.
            </div>
        </div>
    );
}

function OnboardingMath() {
    return (
        <div>
            <div style={{ fontSize: 11, letterSpacing: '0.24em', textTransform: 'uppercase', color: 'rgba(246,241,225,0.55)', marginBottom: 18 }}>
                Step 1 of 3 · How it thinks
            </div>
            <div style={{ fontFamily: 'var(--display-font, "Fraunces", serif)', fontSize: 32, lineHeight: 1.1, letterSpacing: '-0.02em', textWrap: 'pretty' }}>
                Every shot is a distribution. Not a number.
            </div>
            <div style={{ display: 'flex', justifyContent: 'center', margin: '28px 0' }}>
                <DispersionViz
                    width={260} height={220} carry={150} carrySd={8} lateralSd={6}
                    distanceToTarget={150} zoneWidth={28} zoneDepth={30}
                    showLabels={false} showGrid={true}
                />
            </div>
            <div style={{ fontSize: 13, lineHeight: 1.55, color: 'rgba(246,241,225,0.65)', textWrap: 'pretty' }}>
                We model carry and lateral as independent normals, then compute the probability your shot lands in your safe zone. Bigger zone, more clubs work. Tighter zone, fewer.
            </div>
        </div>
    );
}

function OnboardingFirstClub() {
    return (
        <div>
            <div style={{ fontSize: 11, letterSpacing: '0.24em', textTransform: 'uppercase', color: 'rgba(246,241,225,0.55)', marginBottom: 18 }}>
                Step 2 of 3 · Add your first club
            </div>
            <div style={{ fontFamily: 'var(--display-font, "Fraunces", serif)', fontSize: 32, lineHeight: 1.1, letterSpacing: '-0.02em', marginBottom: 22 }}>
                Start with your 7 iron.
            </div>
            <div style={{ background: 'rgba(246,241,225,0.04)', border: '1px solid rgba(246,241,225,0.08)', borderRadius: 12, padding: 18 }}>
                <div style={{ fontSize: 11, letterSpacing: '0.16em', color: 'rgba(246,241,225,0.5)', textTransform: 'uppercase', marginBottom: 10 }}>
                    Average carry
                </div>
                <div style={{ display: 'flex', alignItems: 'baseline', gap: 8 }}>
                    <span style={{ fontFamily: 'var(--display-font, "Fraunces", serif)', fontSize: 56, lineHeight: 1, color: '#f6f1e1' }}>168</span>
                    <span style={{ fontSize: 14, color: 'rgba(246,241,225,0.55)' }}>yards</span>
                </div>
                <input type="range" defaultValue="168" min="80" max="280" style={{ width: '100%', marginTop: 16, accentColor: '#62b375' }} />
            </div>
            <div style={{ fontSize: 12, lineHeight: 1.55, color: 'rgba(246,241,225,0.5)', marginTop: 14, textWrap: 'pretty' }}>
                Don't overthink it. We'll dial in your dispersion using shot tracker data, or you can edit by feel later.
            </div>
        </div>
    );
}

function OnboardingReady() {
    return (
        <div style={{ display: 'flex', flexDirection: 'column', justifyContent: 'center', height: '100%' }}>
            <div style={{ fontSize: 11, letterSpacing: '0.24em', textTransform: 'uppercase', color: '#62b375', marginBottom: 18 }}>
                ◆ Ready
            </div>
            <div style={{ fontFamily: 'var(--display-font, "Fraunces", serif)', fontSize: 40, lineHeight: 1.05, letterSpacing: '-0.02em', textWrap: 'pretty' }}>
                Your bag is local. Your data is yours.
            </div>
            <div style={{ fontSize: 14, lineHeight: 1.55, color: 'rgba(246,241,225,0.65)', marginTop: 18, textWrap: 'pretty' }}>
                Everything stays on this device. Export to JSON anytime. No accounts, no cloud, no telemetry.
            </div>
            <div style={{ marginTop: 28, display: 'grid', gap: 8 }}>
                {['Local-first storage', 'Export / import as JSON', 'Theme: light · dark · course'].map((t) => (
                    <div key={t} style={{ display: 'flex', alignItems: 'center', gap: 10, fontSize: 13, color: 'rgba(246,241,225,0.75)' }}>
                        <span style={{ width: 6, height: 6, borderRadius: 999, background: '#62b375' }} />
                        {t}
                    </div>
                ))}
            </div>
        </div>
    );
}

function SettingsScreen({ device = 'mobile' }) {
    const isMobile = device === 'mobile';
    return (
        <div data-screen-label={`Settings · ${device}`} style={{
            width: '100%', height: '100%',
            background: '#f4efe3', color: '#1a2419',
            fontFamily: 'var(--ui-font, "Inter", system-ui, sans-serif)',
            display: 'flex', flexDirection: 'column', overflow: 'hidden',
        }}>
            <div style={{ padding: isMobile ? '14px 18px 12px' : '20px 28px 16px', borderBottom: '1px solid rgba(26,36,25,0.08)' }}>
                <div style={{ fontSize: 10, letterSpacing: '0.2em', color: 'rgba(26,36,25,0.5)', textTransform: 'uppercase' }}>Settings</div>
                <div style={{ fontFamily: 'var(--display-font, "Fraunces", serif)', fontSize: 28, fontWeight: 400, marginTop: 2, letterSpacing: '-0.02em' }}>
                    Preferences
                </div>
            </div>

            <div style={{ flex: '1 1 auto', overflow: 'auto', padding: '14px 18px 28px' }}>
                <SettingsGroup label="Theme">
                    <ThemePicker />
                </SettingsGroup>

                <SettingsGroup label="Units">
                    <Row label="Distance" value="Yards" />
                    <Row label="Wind" value="mph" />
                </SettingsGroup>

                <SettingsGroup label="Data">
                    <Row label="Export bag as JSON" value="13 clubs · 4 zones" cta />
                    <Row label="Import from JSON" value="Replace local data" cta />
                    <Row label="Clear all data" value="13 clubs · 4 zones · 38 logs" danger />
                </SettingsGroup>

                <SettingsGroup label="Developer">
                    <Row label="Show debug overlay" value="Off" toggle />
                    <Row label="Seed sample bag" value="Reset & re-seed" cta />
                    <Row label="Open math notebook" value="↗ Verify probability fn" cta />
                </SettingsGroup>

                <div style={{ marginTop: 26, fontFamily: 'ui-monospace, monospace', fontSize: 11, color: 'rgba(26,36,25,0.4)', textAlign: 'center', lineHeight: 1.6 }}>
                    Dispersion v1.0.0 · local-only build<br />
                    sha 4a8c91d · stored in localStorage
                </div>
            </div>

            {isMobile && <BottomTabs active="settings" />}
        </div>
    );
}

function SettingsGroup({ label, children }) {
    return (
        <div style={{ marginBottom: 20 }}>
            <div style={{ fontSize: 10, letterSpacing: '0.2em', textTransform: 'uppercase', color: 'rgba(26,36,25,0.45)', padding: '12px 4px 8px' }}>
                {label}
            </div>
            <div style={{ background: '#fff', borderRadius: 12, overflow: 'hidden', border: '1px solid rgba(26,36,25,0.08)' }}>
                {children}
            </div>
        </div>
    );
}

function Row({ label, value, cta, danger, toggle }) {
    return (
        <div style={{
            display: 'flex', alignItems: 'center', justifyContent: 'space-between',
            padding: '13px 14px',
            borderTop: '1px solid rgba(26,36,25,0.06)',
        }}>
            <span style={{ fontSize: 14, color: danger ? '#a23939' : '#1a2419' }}>{label}</span>
            <span style={{ fontSize: 12, color: 'rgba(26,36,25,0.55)', fontFamily: cta ? 'inherit' : 'ui-monospace, monospace', display: 'flex', alignItems: 'center', gap: 6 }}>
                {value}
                {toggle && <span style={{ width: 28, height: 16, background: 'rgba(26,36,25,0.15)', borderRadius: 999, position: 'relative' }}>
                    <span style={{ position: 'absolute', left: 2, top: 2, width: 12, height: 12, background: '#fff', borderRadius: '50%' }} />
                </span>}
                {cta && <Icon.ChevronRight size={12} color="rgba(26,36,25,0.4)" />}
            </span>
        </div>
    );
}

function ThemePicker() {
    const themes = [
        { id: 'light', name: 'Light', bg: '#f4efe3', fg: '#1a2419' },
        { id: 'dark', name: 'Dark', bg: '#1a2419', fg: '#f4efe3' },
        { id: 'course', name: 'Course', bg: '#0e1a13', fg: '#62b375', active: true },
    ];
    return (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 8, padding: 12 }}>
            {themes.map((t) => (
                <div key={t.id} style={{
                    border: t.active ? '1.5px solid #62b375' : '1px solid rgba(26,36,25,0.1)',
                    borderRadius: 10, overflow: 'hidden',
                    background: t.bg, color: t.fg,
                    aspectRatio: '1.4', display: 'flex', flexDirection: 'column',
                    justifyContent: 'space-between', padding: 10,
                }}>
                    <div style={{ width: 16, height: 4, borderRadius: 2, background: t.fg, opacity: 0.7 }} />
                    <div style={{ fontSize: 11, letterSpacing: '0.1em', textTransform: 'uppercase' }}>{t.name}</div>
                </div>
            ))}
        </div>
    );
}

window.OnboardingScreen = OnboardingScreen;
window.SettingsScreen = SettingsScreen;
