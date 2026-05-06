// Calculator screen — heat-map IS the screen. Full-bleed dispersion polygon
// behind everything, recommendation + alts float as glass cards over it.

function CalcScreen({ device = 'mobile', distance = 168, zone = MOCK_PRESETS[0], showLog = false }) {
    const isMobile = device === 'mobile';

    const sorted = [...MOCK_BAG].map((c) => ({
        ...c,
        prob: Math.max(0.01, c.prob * Math.exp(-Math.pow((c.carry - distance) / 18, 2))),
    })).sort((a, b) => b.prob - a.prob);
    const recommended = sorted[0];
    const rest = sorted.slice(1, isMobile ? 4 : 6);

    return (
        <div data-screen-label={`Calculator · ${device}`} style={{
            position: 'relative',
            width: '100%', height: '100%', background: '#0a1410',
            color: '#f6f1e1', fontFamily: 'var(--ui-font, "Inter", system-ui, sans-serif)',
            overflow: 'hidden',
        }}>
            {/* Full-bleed heat map */}
            <div style={{ position: 'absolute', inset: 0 }}>
                <DispersionViz
                    width={isMobile ? 390 : 1100}
                    height={isMobile ? 780 : 720}
                    carry={recommended.carry}
                    carrySd={recommended.carrySd}
                    lateralSd={recommended.lateralSd}
                    distanceToTarget={distance}
                    zoneWidth={zone.width}
                    zoneDepth={zone.depth}
                    contours={7}
                    facets={28}
                    bleed={true}
                    showLabels={false}
                    bg="#0a1410"
                    style={{ width: '100%', height: '100%' }}
                />
            </div>

            {/* Top scrim — keeps top text readable over heat map */}
            <div style={{
                position: 'absolute', top: 0, left: 0, right: 0, height: 200,
                background: 'linear-gradient(to bottom, rgba(10,20,16,0.85) 0%, rgba(10,20,16,0) 100%)',
                pointerEvents: 'none',
            }} />
            {/* Bottom scrim */}
            <div style={{
                position: 'absolute', bottom: 0, left: 0, right: 0, height: '55%',
                background: 'linear-gradient(to top, rgba(10,20,16,0.92) 30%, rgba(10,20,16,0) 100%)',
                pointerEvents: 'none',
            }} />

            {/* Top header — distance + zone */}
            <div style={{
                position: 'absolute', top: 0, left: 0, right: 0,
                padding: isMobile ? '14px 18px' : '20px 28px',
                zIndex: 2,
            }}>
                <div style={{
                    display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                    fontSize: 11, letterSpacing: '0.16em', textTransform: 'uppercase',
                    color: 'rgba(246,241,225,0.55)', marginBottom: 8,
                }}>
                    <span style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                        <Icon.Target size={12} color="rgba(246,241,225,0.55)" /> Hole 7 · Par 4
                    </span>
                    <span style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                        <Icon.Wind size={12} color="rgba(246,241,225,0.55)" /> 6mph NE
                    </span>
                </div>
                <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between' }}>
                    <div>
                        <div style={{
                            fontFamily: 'var(--display-font, "Fraunces", serif)',
                            fontSize: isMobile ? 64 : 88, fontWeight: 400, fontFeatureSettings: '"tnum"',
                            lineHeight: 1, letterSpacing: '-0.03em',
                        }}>
                            {distance}<span style={{ fontSize: '0.34em', color: 'rgba(246,241,225,0.5)', marginLeft: 4 }}>YDS</span>
                        </div>
                        <div style={{ fontSize: 11, letterSpacing: '0.18em', color: 'rgba(246,241,225,0.5)', textTransform: 'uppercase', marginTop: 6 }}>
                            to target
                        </div>
                    </div>
                    <button style={{
                        background: 'rgba(246,241,225,0.06)',
                        backdropFilter: 'blur(12px)',
                        border: '1px solid rgba(246,241,225,0.12)',
                        borderRadius: 10, padding: '10px 14px',
                        textAlign: 'right', cursor: 'pointer', color: '#f6f1e1', fontFamily: 'inherit',
                    }}>
                        <div style={{ fontSize: 9, letterSpacing: '0.18em', color: 'rgba(246,241,225,0.5)', textTransform: 'uppercase' }}>
                            zone
                        </div>
                        <div style={{ fontSize: 13, fontWeight: 500, marginTop: 2 }}>{zone.name}</div>
                        <div style={{ fontSize: 11, color: 'rgba(246,241,225,0.55)', fontFamily: 'ui-monospace, monospace', marginTop: 2 }}>
                            {zone.width}w × {zone.depth}d
                        </div>
                    </button>
                </div>
            </div>

            {/* Bottom — recommendation + alts in a glass stack */}
            <div style={{
                position: 'absolute', bottom: 0, left: 0, right: 0,
                zIndex: 2,
                padding: isMobile ? '0 12px 0' : '0 24px 0',
                display: 'flex', flexDirection: 'column', gap: 10,
            }}>
                {/* Recommended — primary glass card */}
                <div style={{
                    background: 'rgba(246,241,225,0.07)',
                    backdropFilter: 'blur(16px)',
                    border: '1px solid rgba(246,241,225,0.14)',
                    borderRadius: 16,
                    padding: isMobile ? '16px 18px' : '20px 24px',
                }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 10, letterSpacing: '0.22em', textTransform: 'uppercase', color: '#a9d18e', marginBottom: 8 }}>
                        <span style={{ width: 4, height: 4, borderRadius: '50%', background: '#a9d18e' }} />
                        Recommended
                    </div>
                    <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', gap: 12 }}>
                        <div style={{
                            fontFamily: 'var(--display-font, "Fraunces", serif)',
                            fontSize: isMobile ? 42 : 52, fontWeight: 400, lineHeight: 1, letterSpacing: '-0.02em',
                        }}>
                            {recommended.name}
                        </div>
                        <div style={{
                            fontFamily: 'var(--display-font, "Fraunces", serif)',
                            fontSize: isMobile ? 38 : 50, fontWeight: 400, lineHeight: 1,
                            color: '#a9d18e', fontFeatureSettings: '"tnum"',
                        }}>
                            {Math.round(recommended.prob * 100)}<span style={{ fontSize: '0.5em', color: 'rgba(169,209,142,0.7)' }}>%</span>
                        </div>
                    </div>
                    <div style={{ display: 'flex', gap: 14, marginTop: 12, fontFamily: 'ui-monospace, monospace', fontSize: 11, color: 'rgba(246,241,225,0.55)', alignItems: 'center' }}>
                        <span>EXP {recommended.carry}y</span>
                        <span>σ↕ {recommended.carrySd}</span>
                        <span>σ↔ {recommended.lateralSd}</span>
                    </div>
                </div>

                {/* Compact alts strip */}
                <div style={{
                    background: 'rgba(246,241,225,0.04)',
                    backdropFilter: 'blur(16px)',
                    border: '1px solid rgba(246,241,225,0.08)',
                    borderRadius: 12,
                    padding: '4px 0',
                    maxHeight: isMobile ? 165 : 200, overflow: 'auto',
                }}>
                    {rest.map((c, i) => {
                        const lbl = probLabel(c.prob);
                        return (
                            <div key={c.id} style={{
                                display: 'grid',
                                gridTemplateColumns: '24px 1fr auto auto',
                                alignItems: 'center', gap: 12,
                                padding: '10px 16px',
                                borderTop: i > 0 ? '1px solid rgba(246,241,225,0.05)' : 'none',
                            }}>
                                <span style={{ fontFamily: 'ui-monospace, monospace', fontSize: 10, color: 'rgba(246,241,225,0.4)' }}>
                                    {String(i + 2).padStart(2, '0')}
                                </span>
                                <div style={{ fontSize: 14, fontWeight: 500 }}>
                                    {c.name}
                                    <span style={{ fontFamily: 'ui-monospace, monospace', fontSize: 10, color: 'rgba(246,241,225,0.4)', marginLeft: 8 }}>
                                        {c.carry}y · σ {c.carrySd}×{c.lateralSd}
                                    </span>
                                </div>
                                <div style={{ width: 44, height: 4, background: 'rgba(246,241,225,0.08)', borderRadius: 999, overflow: 'hidden' }}>
                                    <div style={{ width: `${c.prob * 100}%`, height: '100%', background: lbl.color }} />
                                </div>
                                <div style={{
                                    fontFamily: 'var(--display-font, "Fraunces", serif)',
                                    fontSize: 18, fontFeatureSettings: '"tnum"', minWidth: 38, textAlign: 'right',
                                }}>
                                    {Math.round(c.prob * 100)}<span style={{ fontSize: '0.55em', color: 'rgba(246,241,225,0.4)' }}>%</span>
                                </div>
                            </div>
                        );
                    })}
                </div>

                {/* Quick log shot bar — THE primary action on course */}
                <div style={{
                    display: 'flex', gap: 8,
                    paddingBottom: isMobile ? 0 : 18,
                }}>
                    <button style={{
                        flex: '0 0 auto', padding: '13px 14px', borderRadius: 12,
                        background: 'rgba(246,241,225,0.06)', backdropFilter: 'blur(12px)',
                        color: '#f6f1e1', border: '1px solid rgba(246,241,225,0.12)',
                        fontFamily: 'inherit', fontSize: 13, cursor: 'pointer',
                        display: 'flex', alignItems: 'center', gap: 6,
                    }}>
                        <Icon.Sliders size={14} /> Zone
                    </button>
                    <button style={{
                        flex: '1 1 auto', padding: '13px 14px', borderRadius: 12,
                        background: '#62b375', color: '#0a1410',
                        border: 'none', fontFamily: 'inherit',
                        fontSize: 14, fontWeight: 600, cursor: 'pointer', letterSpacing: '0.04em',
                        display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
                    }}>
                        <span style={{
                            width: 18, height: 18, borderRadius: '50%',
                            background: 'rgba(10,20,16,0.18)', display: 'flex',
                            alignItems: 'center', justifyContent: 'center',
                        }}>
                            <Icon.Plus size={11} color="#0a1410" />
                        </span>
                        Log shot · {recommended.name}
                    </button>
                </div>

                {isMobile && (
                    <div style={{
                        flex: '0 0 auto',
                        display: 'flex', justifyContent: 'space-around',
                        padding: '8px 0 14px',
                    }}>
                        {[
                            { icon: Icon.Target, label: 'Calc', active: true },
                            { icon: Icon.Bag, label: 'Clubs' },
                            { icon: Icon.Flag, label: 'Range' },
                            { icon: Icon.Settings, label: 'Settings' },
                        ].map((t) => (
                            <div key={t.label} style={{
                                display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 3,
                                color: t.active ? '#a9d18e' : 'rgba(246,241,225,0.4)',
                                fontSize: 9, letterSpacing: '0.14em', textTransform: 'uppercase',
                            }}>
                                <t.icon size={18} />
                                {t.label}
                            </div>
                        ))}
                    </div>
                )}
            </div>

            {/* Optional: log-shot bottom sheet overlay */}
            {showLog && <QuickLogSheet club={recommended} />}
        </div>
    );
}

function QuickLogSheet({ club }) {
    const outcomes = [
        { id: 'in', label: 'In zone', color: '#62b375', emoji: '◆' },
        { id: 'short', label: 'Short', color: '#e6c068', emoji: '↓' },
        { id: 'long', label: 'Long', color: '#e6c068', emoji: '↑' },
        { id: 'left', label: 'Left', color: '#c87060', emoji: '←' },
        { id: 'right', label: 'Right', color: '#c87060', emoji: '→' },
        { id: 'penalty', label: 'Penalty', color: '#a23939', emoji: '✕' },
    ];
    return (
        <div style={{
            position: 'absolute', inset: 0, zIndex: 5,
            background: 'rgba(10,20,16,0.55)', backdropFilter: 'blur(2px)',
            display: 'flex', flexDirection: 'column', justifyContent: 'flex-end',
        }}>
            <div style={{
                background: '#0e1a13', borderTopLeftRadius: 20, borderTopRightRadius: 20,
                padding: '14px 18px 24px', borderTop: '1px solid rgba(246,241,225,0.12)',
            }}>
                <div style={{
                    width: 36, height: 4, background: 'rgba(246,241,225,0.2)',
                    borderRadius: 999, margin: '0 auto 16px',
                }} />
                <div style={{ fontSize: 10, letterSpacing: '0.22em', textTransform: 'uppercase', color: '#a9d18e', marginBottom: 4 }}>
                    Log shot
                </div>
                <div style={{ fontFamily: 'var(--display-font, "Fraunces", serif)', fontSize: 28, lineHeight: 1.1, letterSpacing: '-0.02em', marginBottom: 18 }}>
                    {club.name} · 168y target
                </div>
                <div style={{ fontSize: 11, letterSpacing: '0.18em', color: 'rgba(246,241,225,0.5)', textTransform: 'uppercase', marginBottom: 10 }}>
                    Outcome
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 8 }}>
                    {outcomes.map((o) => (
                        <button key={o.id} style={{
                            background: 'rgba(246,241,225,0.04)',
                            border: `1px solid ${o.color}40`,
                            borderRadius: 10, padding: '14px 8px',
                            color: '#f6f1e1', fontFamily: 'inherit', cursor: 'pointer',
                            display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4,
                        }}>
                            <span style={{ fontSize: 22, color: o.color }}>{o.emoji}</span>
                            <span style={{ fontSize: 12 }}>{o.label}</span>
                        </button>
                    ))}
                </div>
                <div style={{ marginTop: 16, fontSize: 11, color: 'rgba(246,241,225,0.45)', textAlign: 'center' }}>
                    Tap exact landing spot on the dispersion grid for precise σ tracking
                </div>
            </div>
        </div>
    );
}

window.CalcScreen = CalcScreen;
window.QuickLogSheet = QuickLogSheet;
