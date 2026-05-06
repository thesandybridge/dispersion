// Range / practice mode + Shot log history screen.
// Both center on tap-to-log: at the range you tap where the ball landed
// relative to a target; the app builds dispersion automatically.

function RangeScreen({ device = 'mobile', shots = null }) {
    const isMobile = device === 'mobile';
    const club = MOCK_BAG[6]; // 7-iron

    // Simulated logged shots, in (lat, longDelta) yards from expected.
    const defaultShots = [
        [-3, 4], [2, -2], [-1, 8], [4, -5], [-5, 1], [0, 3], [3, 6],
        [-2, -8], [1, 11], [6, -1], [-4, -3], [2, 7], [-3, -2], [5, 4],
        [0, -6], [-1, 2], [3, -4], [-6, 5], [1, -1], [4, 9], [-2, 0],
        [2, 3], [-3, -5], [0, 1],
    ];
    const data = shots || defaultShots;

    const carry = club.carry;
    const carrySd = computeSd(data.map((d) => d[1]));
    const lateralSd = computeSd(data.map((d) => d[0]));

    return (
        <div data-screen-label={`Range · ${device}`} style={{
            width: '100%', height: '100%',
            background: '#0a1410', color: '#f6f1e1',
            fontFamily: 'var(--ui-font, "Inter", system-ui, sans-serif)',
            display: 'flex', flexDirection: 'column', overflow: 'hidden',
        }}>
            {/* header */}
            <div style={{ padding: isMobile ? '14px 18px 12px' : '20px 28px 14px', borderBottom: '1px solid rgba(246,241,225,0.06)' }}>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 8 }}>
                    <div style={{ fontSize: 10, letterSpacing: '0.22em', color: '#a9d18e', textTransform: 'uppercase', display: 'flex', alignItems: 'center', gap: 6 }}>
                        <span style={{ width: 6, height: 6, borderRadius: '50%', background: '#a9d18e' }} />
                        Range mode · live
                    </div>
                    <span style={{ fontFamily: 'ui-monospace, monospace', fontSize: 11, color: 'rgba(246,241,225,0.5)' }}>
                        Bay 12 · Golf Galaxy
                    </span>
                </div>
                <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
                    <div>
                        <div style={{ fontFamily: 'var(--display-font, "Fraunces", serif)', fontSize: isMobile ? 32 : 40, fontWeight: 400, letterSpacing: '-0.02em' }}>
                            {club.name}
                        </div>
                        <div style={{ fontSize: 11, color: 'rgba(246,241,225,0.5)', marginTop: 2 }}>
                            Tap the grid where each ball landed
                        </div>
                    </div>
                    <button style={{
                        background: 'rgba(246,241,225,0.06)', border: '1px solid rgba(246,241,225,0.12)',
                        borderRadius: 8, padding: '8px 12px', color: '#f6f1e1', fontFamily: 'inherit',
                        fontSize: 12, cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 4,
                    }}>
                        Switch club <Icon.ChevronRight size={11} color="#f6f1e1" />
                    </button>
                </div>
            </div>

            {/* the tap-grid — heat map building live */}
            <div style={{ flex: '1 1 auto', position: 'relative', minHeight: 0 }}>
                <RangeTapGrid carry={carry} carrySd={carrySd} lateralSd={lateralSd} shots={data} isMobile={isMobile} />
            </div>

            {/* live stats strip */}
            <div style={{
                background: '#070d0a',
                borderTop: '1px solid rgba(246,241,225,0.08)',
                padding: isMobile ? '14px 18px' : '18px 28px',
            }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 12 }}>
                    <div style={{ fontSize: 10, letterSpacing: '0.22em', textTransform: 'uppercase', color: 'rgba(246,241,225,0.5)' }}>
                        Live dispersion · {data.length} shots
                    </div>
                    <button style={{
                        background: 'transparent', color: '#a9d18e', border: 'none',
                        fontFamily: 'inherit', fontSize: 11, letterSpacing: '0.16em',
                        textTransform: 'uppercase', cursor: 'pointer',
                    }}>
                        Save to club ◆
                    </button>
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 10 }}>
                    <Stat label="Avg carry" value={`${Math.round(carry + avg(data.map((d) => d[1])))}y`} />
                    <Stat label="σ ↕" value={`${carrySd.toFixed(1)}y`} delta={`-0.4`} />
                    <Stat label="σ ↔" value={`${lateralSd.toFixed(1)}y`} delta={`-0.2`} />
                    <Stat label="68% in" value={`${Math.round(carrySd * 2)}×${Math.round(lateralSd * 2)}`} mono />
                </div>
            </div>

            {isMobile && <BottomTabs active="zones" />}
        </div>
    );
}

function RangeTapGrid({ carry, carrySd, lateralSd, shots, isMobile }) {
    // Render a target-centric grid with the live polygon under the dots.
    const w = isMobile ? 360 : 800;
    const h = isMobile ? 420 : 480;
    const padX = 20, padY = 24;

    // Bounds: ~3σ of the live data
    const longSpan = Math.max(carrySd * 3, 25);
    const latSpan = Math.max(lateralSd * 3, 18);

    const sxScale = (w - padX * 2) / (latSpan * 2);
    const syScale = (h - padY * 2) / (longSpan * 2);
    const sx = (lat) => padX + (lat + latSpan) * sxScale;
    const sy = (lng) => padY + (longSpan - lng) * syScale;

    return (
        <div style={{ position: 'absolute', inset: 0, display: 'flex', justifyContent: 'center', alignItems: 'center' }}>
            <svg width={w} height={h} viewBox={`0 0 ${w} ${h}`} style={{ display: 'block' }}>
                <defs>
                    <radialGradient id="rg-target" cx="50%" cy="50%" r="50%">
                        <stop offset="0%" stopColor="#e85d4d" stopOpacity="0.18" />
                        <stop offset="60%" stopColor="#e85d4d" stopOpacity="0" />
                    </radialGradient>
                </defs>
                <rect x="0" y="0" width={w} height={h} fill="#0e1a13" />

                {/* yardage rings around the target (concentric distances) */}
                {[5, 10, 15, 20, 25, 30].map((r) => (
                    <ellipse key={r} cx={sx(0)} cy={sy(0)} rx={r * sxScale} ry={r * syScale}
                             fill="none" stroke="rgba(246,241,225,0.06)" strokeWidth="0.5" />
                ))}

                {/* axis */}
                <line x1={sx(0)} y1={padY} x2={sx(0)} y2={h - padY} stroke="rgba(246,241,225,0.15)" strokeWidth="0.5" strokeDasharray="3 4" />
                <line x1={padX} y1={sy(0)} x2={w - padX} y2={sy(0)} stroke="rgba(246,241,225,0.15)" strokeWidth="0.5" strokeDasharray="3 4" />

                {/* faceted dispersion polygon, computed live */}
                {[2.5, 1.8, 1.2, 0.7].map((k, i) => {
                    const facets = 24;
                    const pts = [];
                    for (let j = 0; j < facets; j++) {
                        const t = (j / facets) * Math.PI * 2;
                        pts.push(`${sx(Math.cos(t) * k * lateralSd)},${sy(Math.sin(t) * k * carrySd)}`);
                    }
                    const colors = ['#0b3d2e', '#2c8a5e', '#62b375', '#a9d18e'];
                    return <polygon key={i} points={pts.join(' ')} fill={colors[i]} fillOpacity="0.6" style={{ mixBlendMode: 'screen' }} />;
                })}

                {/* target reticle */}
                <circle cx={sx(0)} cy={sy(0)} r="40" fill="url(#rg-target)" />
                <circle cx={sx(0)} cy={sy(0)} r="5" fill="none" stroke="#e85d4d" strokeWidth="1.4" />
                <line x1={sx(0) - 12} y1={sy(0)} x2={sx(0) + 12} y2={sy(0)} stroke="#e85d4d" strokeWidth="1" />
                <line x1={sx(0)} y1={sy(0) - 12} x2={sx(0)} y2={sy(0) + 12} stroke="#e85d4d" strokeWidth="1" />

                {/* logged shots */}
                {shots.map(([lat, lng], i) => (
                    <g key={i}>
                        <circle cx={sx(lat)} cy={sy(lng)} r="3.5" fill="#f6f1e1" />
                        <circle cx={sx(lat)} cy={sy(lng)} r="3.5" fill="none" stroke="#0a1410" strokeWidth="1" />
                    </g>
                ))}

                {/* most recent shot pulse */}
                <circle cx={sx(shots[shots.length - 1][0])} cy={sy(shots[shots.length - 1][1])} r="9"
                        fill="none" stroke="#a9d18e" strokeWidth="1.2" opacity="0.6" />

                {/* hint cursor */}
                <g opacity="0.4">
                    <circle cx={sx(2)} cy={sy(-3)} r="10" fill="none" stroke="#f6f1e1" strokeWidth="0.8" strokeDasharray="2 3" />
                </g>

                {/* yard labels */}
                <g fill="rgba(246,241,225,0.4)" fontFamily="ui-monospace, monospace" fontSize="9">
                    <text x={sx(0) + 6} y={sy(10) + 3}>+10y</text>
                    <text x={sx(0) + 6} y={sy(-10) + 3}>−10y</text>
                    <text x={sx(10) + 4} y={sy(0) + 3}>+10y</text>
                    <text x={sx(-10) - 26} y={sy(0) + 3}>−10y</text>
                </g>
            </svg>
        </div>
    );
}

function Stat({ label, value, delta, mono }) {
    return (
        <div>
            <div style={{ fontSize: 10, letterSpacing: '0.16em', color: 'rgba(246,241,225,0.45)', textTransform: 'uppercase', marginBottom: 4 }}>
                {label}
            </div>
            <div style={{ display: 'flex', alignItems: 'baseline', gap: 6 }}>
                <span style={{
                    fontFamily: mono ? 'ui-monospace, monospace' : 'var(--display-font, "Fraunces", serif)',
                    fontSize: mono ? 16 : 22, fontFeatureSettings: '"tnum"', fontWeight: 400,
                    color: '#f6f1e1',
                }}>
                    {value}
                </span>
                {delta && (
                    <span style={{ fontSize: 10, color: '#62b375', fontFamily: 'ui-monospace, monospace' }}>
                        {delta}
                    </span>
                )}
            </div>
        </div>
    );
}

function ShotLogScreen({ device = 'mobile' }) {
    const isMobile = device === 'mobile';

    // Simulated history grouped by session.
    const sessions = [
        { id: 's1', date: 'Today · 2:14 PM', label: 'Range · Golf Galaxy', shots: 38, clubs: 4, accent: '#a9d18e' },
        { id: 's2', date: 'May 3 · Round', label: 'Pebble Hills · 18 holes', shots: 72, clubs: 11, accent: '#e6c068' },
        { id: 's3', date: 'May 1 · 5:40 PM', label: 'Range · Golf Galaxy', shots: 52, clubs: 6, accent: '#a9d18e' },
        { id: 's4', date: 'Apr 28 · Round', label: 'Quarry GC · 9 holes', shots: 41, clubs: 9, accent: '#e6c068' },
    ];

    return (
        <div data-screen-label={`Shot log · ${device}`} style={{
            width: '100%', height: '100%',
            background: '#f4efe3', color: '#1a2419',
            fontFamily: 'var(--ui-font, "Inter", system-ui, sans-serif)',
            display: 'flex', flexDirection: 'column', overflow: 'hidden',
        }}>
            <div style={{ padding: isMobile ? '14px 18px 12px' : '20px 28px 16px', borderBottom: '1px solid rgba(26,36,25,0.08)' }}>
                <div style={{ fontSize: 10, letterSpacing: '0.2em', color: 'rgba(26,36,25,0.5)', textTransform: 'uppercase' }}>
                    Shot log
                </div>
                <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
                    <div style={{ fontFamily: 'var(--display-font, "Fraunces", serif)', fontSize: isMobile ? 28 : 36, fontWeight: 400, marginTop: 2, letterSpacing: '-0.02em' }}>
                        203 shots
                    </div>
                    <div style={{ fontSize: 12, color: 'rgba(26,36,25,0.55)', fontFamily: 'ui-monospace, monospace' }}>
                        last 30 days
                    </div>
                </div>
            </div>

            {/* per-club summary row — sparkline of σ over time */}
            <div style={{ padding: '14px 18px 0', display: 'flex', gap: 8, overflowX: 'auto' }}>
                {MOCK_BAG.slice(4, 11).map((c) => (
                    <div key={c.id} style={{
                        flex: '0 0 auto', minWidth: 110,
                        background: '#fff', borderRadius: 10, padding: 12,
                        border: '1px solid rgba(26,36,25,0.08)',
                    }}>
                        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                            <span style={{ fontSize: 13, fontWeight: 500 }}>{c.name}</span>
                            <span style={{ fontSize: 10, color: 'rgba(26,36,25,0.45)', fontFamily: 'ui-monospace, monospace' }}>
                                {Math.floor(20 + Math.random() * 30)}
                            </span>
                        </div>
                        <SigmaSparkline />
                        <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 4, fontFamily: 'ui-monospace, monospace', fontSize: 10, color: 'rgba(26,36,25,0.55)' }}>
                            <span>σ {c.carrySd}</span>
                            <span style={{ color: '#2c8a5e' }}>↓0.3</span>
                        </div>
                    </div>
                ))}
            </div>

            <div style={{ padding: '18px 18px 8px', fontSize: 10, letterSpacing: '0.2em', textTransform: 'uppercase', color: 'rgba(26,36,25,0.45)' }}>
                Sessions
            </div>
            <div style={{ flex: '1 1 auto', overflow: 'auto', minHeight: 0 }}>
                {sessions.map((s) => (
                    <div key={s.id} style={{
                        display: 'grid', gridTemplateColumns: '4px 1fr auto',
                        gap: 14, alignItems: 'center',
                        padding: '14px 18px',
                        borderTop: '1px solid rgba(26,36,25,0.06)',
                        background: '#f4efe3',
                    }}>
                        <div style={{ width: 4, height: 36, background: s.accent, borderRadius: 2 }} />
                        <div>
                            <div style={{ fontSize: 13, fontWeight: 500 }}>{s.label}</div>
                            <div style={{ fontSize: 11, color: 'rgba(26,36,25,0.55)', marginTop: 2, fontFamily: 'ui-monospace, monospace' }}>
                                {s.date} · {s.shots} shots · {s.clubs} clubs
                            </div>
                        </div>
                        <Icon.ChevronRight size={14} color="rgba(26,36,25,0.4)" />
                    </div>
                ))}
            </div>

            {isMobile && <BottomTabs active="zones" />}
        </div>
    );
}

function SigmaSparkline() {
    // tiny mock sparkline (declining σ — improvement)
    const pts = [12, 11.5, 11.8, 10.2, 10.5, 9.4, 9.1, 8.6];
    const w = 86, h = 22;
    const max = 13, min = 8;
    const path = pts.map((v, i) => {
        const x = (i / (pts.length - 1)) * w;
        const y = h - ((v - min) / (max - min)) * h;
        return `${i === 0 ? 'M' : 'L'}${x.toFixed(1)},${y.toFixed(1)}`;
    }).join(' ');
    return (
        <svg width={w} height={h} viewBox={`0 0 ${w} ${h}`} style={{ marginTop: 6, display: 'block' }}>
            <path d={path} stroke="#2c8a5e" strokeWidth="1.4" fill="none" strokeLinecap="round" />
            <path d={`${path} L${w},${h} L0,${h} Z`} fill="#62b375" fillOpacity="0.12" />
        </svg>
    );
}

// helpers
function avg(arr) {
    return arr.reduce((s, v) => s + v, 0) / arr.length;
}
function computeSd(arr) {
    const m = avg(arr);
    return Math.sqrt(arr.reduce((s, v) => s + (v - m) ** 2, 0) / arr.length);
}

window.RangeScreen = RangeScreen;
window.ShotLogScreen = ShotLogScreen;
