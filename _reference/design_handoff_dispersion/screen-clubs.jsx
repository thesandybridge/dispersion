// Clubs screen — list / form. Two states: list view, detail/edit view.

function ClubsScreen({ device = 'mobile', mode = 'list' }) {
    const isMobile = device === 'mobile';
    const editing = mode === 'edit' ? MOCK_BAG[6] : null;

    return (
        <div data-screen-label={`Clubs · ${device} · ${mode}`} style={{
            width: '100%', height: '100%',
            background: '#f4efe3', color: '#1a2419',
            fontFamily: 'var(--ui-font, "Inter", system-ui, sans-serif)',
            display: 'flex', flexDirection: 'column', overflow: 'hidden',
        }}>
            {/* header */}
            <div style={{
                display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                padding: isMobile ? '14px 18px 12px' : '20px 28px 16px',
                borderBottom: '1px solid rgba(26,36,25,0.08)',
            }}>
                <div>
                    <div style={{ fontSize: 10, letterSpacing: '0.2em', color: 'rgba(26,36,25,0.5)', textTransform: 'uppercase' }}>
                        {mode === 'edit' ? 'Editing' : 'My bag'}
                    </div>
                    <div style={{ fontFamily: 'var(--display-font, "Fraunces", serif)', fontSize: isMobile ? 28 : 36, fontWeight: 400, marginTop: 2, letterSpacing: '-0.02em' }}>
                        {mode === 'edit' ? editing.name : 'Clubs'}
                    </div>
                </div>
                {mode === 'list' && (
                    <button style={{
                        display: 'flex', alignItems: 'center', gap: 6,
                        padding: '9px 14px', borderRadius: 999,
                        background: '#1a2419', color: '#f4efe3',
                        border: 'none', fontFamily: 'inherit', fontSize: 13, fontWeight: 500, cursor: 'pointer',
                    }}>
                        <Icon.Plus size={14} color="#f4efe3" /> Add club
                    </button>
                )}
            </div>

            {/* body */}
            <div style={{ flex: '1 1 auto', overflow: 'auto', minHeight: 0 }}>
                {mode === 'list' ? <ClubsList /> : <ClubEditForm club={editing} />}
            </div>

            {isMobile && <BottomTabs active="clubs" />}
        </div>
    );
}

function ClubsList() {
    return (
        <div>
            <div style={{ padding: '14px 18px 6px', fontSize: 10, letterSpacing: '0.2em', textTransform: 'uppercase', color: 'rgba(26,36,25,0.45)' }}>
                13 clubs · sorted by carry
            </div>
            {MOCK_BAG.map((c) => (
                <div key={c.id} style={{
                    display: 'grid',
                    gridTemplateColumns: '1fr auto auto',
                    alignItems: 'center', gap: 14,
                    padding: '14px 18px',
                    borderTop: '1px solid rgba(26,36,25,0.06)',
                    background: '#f4efe3',
                }}>
                    <div>
                        <div style={{ fontSize: 15, fontWeight: 500 }}>{c.name}</div>
                        <div style={{ fontSize: 11, color: 'rgba(26,36,25,0.55)', fontFamily: 'ui-monospace, monospace', marginTop: 2 }}>
                            σ↕ {c.carrySd} · σ↔ {c.lateralSd}
                        </div>
                    </div>
                    {/* mini dispersion glyph */}
                    <DispersionGlyph carry={c.carry} carrySd={c.carrySd} lateralSd={c.lateralSd} />
                    <div style={{ fontFamily: 'var(--display-font, "Fraunces", serif)', fontSize: 24, fontFeatureSettings: '"tnum"', minWidth: 64, textAlign: 'right' }}>
                        {c.carry}<span style={{ fontSize: '0.5em', color: 'rgba(26,36,25,0.45)', marginLeft: 2 }}>y</span>
                    </div>
                </div>
            ))}
        </div>
    );
}

function DispersionGlyph({ carry, carrySd, lateralSd }) {
    const w = 44, h = 28;
    // tiny faceted oval
    const facets = 12;
    const cx = w / 2, cy = h / 2;
    const rx = Math.min(14, lateralSd * 0.7);
    const ry = Math.min(10, carrySd * 0.5);
    const pts = [];
    for (let i = 0; i < facets; i++) {
        const t = (i / facets) * Math.PI * 2;
        pts.push(`${cx + Math.cos(t) * rx},${cy + Math.sin(t) * ry}`);
    }
    return (
        <svg width={w} height={h} viewBox={`0 0 ${w} ${h}`}>
            <polygon points={pts.join(' ')} fill="#62b375" fillOpacity="0.25" stroke="#2c8a5e" strokeWidth="0.8" />
            <circle cx={cx} cy={cy} r="1.4" fill="#2c8a5e" />
        </svg>
    );
}

function ClubEditForm({ club }) {
    return (
        <div style={{ padding: '20px 22px 28px' }}>
            {/* preview */}
            <div style={{
                background: '#0e1a13', borderRadius: 14, padding: 18,
                display: 'flex', alignItems: 'center', gap: 16, marginBottom: 22,
            }}>
                <DispersionViz
                    width={140} height={170}
                    carry={club.carry} carrySd={club.carrySd} lateralSd={club.lateralSd}
                    distanceToTarget={club.carry} zoneWidth={28} zoneDepth={28}
                    showLabels={false} showGrid={false}
                />
                <div style={{ color: '#f6f1e1', flex: 1 }}>
                    <div style={{ fontSize: 10, letterSpacing: '0.2em', color: 'rgba(246,241,225,0.5)', textTransform: 'uppercase' }}>
                        Live preview
                    </div>
                    <div style={{ fontFamily: 'var(--display-font, "Fraunces", serif)', fontSize: 36, marginTop: 4 }}>
                        {club.carry}<span style={{ fontSize: '0.5em', color: 'rgba(246,241,225,0.5)' }}>y</span>
                    </div>
                    <div style={{ fontFamily: 'ui-monospace, monospace', fontSize: 11, color: 'rgba(246,241,225,0.6)', marginTop: 8, lineHeight: 1.6 }}>
                        ~68% within<br />±{club.carrySd}y long, ±{club.lateralSd}y lateral
                    </div>
                </div>
            </div>

            <Field label="Name" value={club.name} />
            <Field label="Carry distance" value={club.carry} suffix="yards" />
            <Field label="Distance σ (carry)" value={club.carrySd} suffix="yards" hint="Standard deviation. ~68% of shots land within ±σ of expected carry." />
            <Field label="Lateral σ" value={club.lateralSd} suffix="yards" hint="Standard deviation perpendicular to target line." />

            <div style={{ display: 'flex', gap: 10, marginTop: 26 }}>
                <button style={{
                    flex: '1 1 auto', padding: '14px', borderRadius: 10,
                    background: '#1a2419', color: '#f4efe3',
                    border: 'none', fontFamily: 'inherit', fontSize: 14, fontWeight: 600, cursor: 'pointer',
                }}>
                    Save changes
                </button>
                <button style={{
                    flex: '0 0 auto', padding: '14px 16px', borderRadius: 10,
                    background: 'transparent', color: '#a23939',
                    border: '1px solid rgba(162,57,57,0.3)', fontFamily: 'inherit', fontSize: 14, cursor: 'pointer',
                }}>
                    Delete
                </button>
            </div>
        </div>
    );
}

function Field({ label, value, suffix, hint }) {
    return (
        <div style={{ marginBottom: 16 }}>
            <label style={{ display: 'block', fontSize: 11, letterSpacing: '0.16em', color: 'rgba(26,36,25,0.55)', textTransform: 'uppercase', marginBottom: 6 }}>
                {label}
            </label>
            <div style={{
                display: 'flex', alignItems: 'center',
                background: '#fff', border: '1px solid rgba(26,36,25,0.12)',
                borderRadius: 10, padding: '12px 14px',
            }}>
                <span style={{ flex: 1, fontSize: 16, fontFamily: 'var(--display-font, "Fraunces", serif)', fontFeatureSettings: '"tnum"' }}>
                    {value}
                </span>
                {suffix && <span style={{ fontSize: 12, color: 'rgba(26,36,25,0.5)', fontFamily: 'ui-monospace, monospace' }}>{suffix}</span>}
            </div>
            {hint && <div style={{ fontSize: 11, color: 'rgba(26,36,25,0.5)', marginTop: 6, lineHeight: 1.4 }}>{hint}</div>}
        </div>
    );
}

function BottomTabs({ active }) {
    const tabs = [
        { id: 'calc', icon: Icon.Target, label: 'Calc' },
        { id: 'clubs', icon: Icon.Bag, label: 'Clubs' },
        { id: 'zones', icon: Icon.Flag, label: 'Zones' },
        { id: 'settings', icon: Icon.Settings, label: 'Settings' },
    ];
    return (
        <div style={{
            flex: '0 0 auto',
            display: 'flex', justifyContent: 'space-around',
            padding: '8px 0 18px',
            background: '#1a2419', borderTop: '1px solid rgba(26,36,25,0.1)',
        }}>
            {tabs.map((t) => (
                <div key={t.id} style={{
                    display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3,
                    color: active === t.id ? '#a9d18e' : 'rgba(244,239,227,0.5)',
                    fontSize: 10, letterSpacing: '0.1em', textTransform: 'uppercase',
                }}>
                    <t.icon size={18} />
                    {t.label}
                </div>
            ))}
        </div>
    );
}

window.ClubsScreen = ClubsScreen;
window.BottomTabs = BottomTabs;
