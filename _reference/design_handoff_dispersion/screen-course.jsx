// Course view — premium tier with real course data via API.
// Hole map (low-poly polygons of fairway/green/rough/hazards), GPS distances,
// shot history overlaid as dots, recommended dispersion polygon over the
// pin/zone, and an upgrade prompt for the free tier.

function CourseScreen({ device = 'mobile', mode = 'play' }) {
    const isMobile = device === 'mobile';

    return (
        <div data-screen-label={`Course · ${device} · ${mode}`} style={{
            width: '100%', height: '100%', background: '#0a1410',
            color: '#f6f1e1', fontFamily: 'var(--ui-font, "Inter", system-ui, sans-serif)',
            display: 'flex', flexDirection: 'column', overflow: 'hidden',
            position: 'relative',
        }}>
            {/* header */}
            <div style={{
                display: 'flex', alignItems: 'center', justifyContent: 'space-between',
                padding: isMobile ? '14px 18px 10px' : '20px 28px 14px',
                background: 'rgba(7,13,10,0.95)',
                borderBottom: '1px solid rgba(246,241,225,0.06)',
                zIndex: 2, position: 'relative',
            }}>
                <div>
                    <div style={{ fontSize: 10, letterSpacing: '0.2em', color: '#a9d18e', textTransform: 'uppercase', display: 'flex', alignItems: 'center', gap: 6 }}>
                        <span style={{ width: 5, height: 5, borderRadius: '50%', background: '#a9d18e' }} />
                        Live · GPS locked
                    </div>
                    <div style={{ fontFamily: 'var(--display-font, "Fraunces", serif)', fontSize: isMobile ? 22 : 28, marginTop: 2, letterSpacing: '-0.01em' }}>
                        Pebble Hills · Hole 7
                    </div>
                </div>
                <div style={{ textAlign: 'right' }}>
                    <div style={{ fontSize: 10, letterSpacing: '0.18em', color: 'rgba(246,241,225,0.5)', textTransform: 'uppercase' }}>Par 4</div>
                    <div style={{ fontFamily: 'ui-monospace, monospace', fontSize: 12, color: 'rgba(246,241,225,0.75)' }}>438y · HCP 5</div>
                </div>
            </div>

            {/* the hole map */}
            <div style={{ flex: '1 1 auto', position: 'relative', minHeight: 0 }}>
                <HoleMap isMobile={isMobile} />

                {/* GPS distance overlay — top-right floating chip */}
                <div style={{
                    position: 'absolute', top: 14, right: 14,
                    background: 'rgba(7,13,10,0.7)', backdropFilter: 'blur(12px)',
                    border: '1px solid rgba(246,241,225,0.12)',
                    borderRadius: 12, padding: '10px 14px',
                    zIndex: 2,
                }}>
                    <div style={{ fontSize: 9, letterSpacing: '0.2em', color: 'rgba(246,241,225,0.5)', textTransform: 'uppercase' }}>To pin</div>
                    <div style={{
                        fontFamily: 'var(--display-font, "Fraunces", serif)',
                        fontSize: 36, lineHeight: 1, fontFeatureSettings: '"tnum"', color: '#f6f1e1',
                    }}>
                        168<span style={{ fontSize: '0.4em', color: 'rgba(246,241,225,0.6)', marginLeft: 2 }}>y</span>
                    </div>
                    <div style={{ display: 'flex', gap: 10, marginTop: 6, fontFamily: 'ui-monospace, monospace', fontSize: 10, color: 'rgba(246,241,225,0.6)' }}>
                        <span>F 152</span>
                        <span>C 168</span>
                        <span>B 184</span>
                    </div>
                </div>

                {/* premium badge bottom-left */}
                <div style={{
                    position: 'absolute', top: 14, left: 14,
                    background: 'rgba(232,93,77,0.18)',
                    border: '1px solid rgba(232,93,77,0.4)',
                    borderRadius: 999, padding: '5px 10px',
                    fontSize: 10, letterSpacing: '0.18em', textTransform: 'uppercase',
                    color: '#e85d4d', display: 'flex', alignItems: 'center', gap: 5, fontWeight: 600,
                    zIndex: 2,
                }}>
                    ◆ Premium
                </div>
            </div>

            {/* bottom recommendation strip */}
            <div style={{
                background: '#0e1a13',
                borderTop: '1px solid rgba(246,241,225,0.08)',
                padding: isMobile ? '14px 18px 10px' : '18px 28px 14px',
            }}>
                <div style={{
                    display: 'flex', alignItems: 'baseline', justifyContent: 'space-between',
                    marginBottom: 10,
                }}>
                    <div style={{ display: 'flex', alignItems: 'baseline', gap: 12 }}>
                        <span style={{
                            fontFamily: 'var(--display-font, "Fraunces", serif)',
                            fontSize: isMobile ? 32 : 40, fontWeight: 400, letterSpacing: '-0.02em',
                        }}>
                            7 Iron
                        </span>
                        <span style={{
                            fontFamily: 'var(--display-font, "Fraunces", serif)',
                            fontSize: isMobile ? 24 : 30, color: '#a9d18e',
                            fontFeatureSettings: '"tnum"',
                        }}>
                            71<span style={{ fontSize: '0.55em', color: 'rgba(169,209,142,0.7)' }}>%</span>
                        </span>
                    </div>
                    <span style={{ fontSize: 10, letterSpacing: '0.2em', color: '#a9d18e', textTransform: 'uppercase' }}>
                        ◆ Recommended
                    </span>
                </div>
                <div style={{ fontSize: 11, color: 'rgba(246,241,225,0.55)', fontFamily: 'ui-monospace, monospace', marginBottom: 12 }}>
                    Avoid bunker R · Account for 6mph crosswind L→R · Adj +4y
                </div>
                <div style={{ display: 'flex', gap: 8 }}>
                    <button style={{
                        flex: '0 0 auto', padding: '12px 14px', borderRadius: 10,
                        background: 'rgba(246,241,225,0.06)', color: '#f6f1e1',
                        border: '1px solid rgba(246,241,225,0.12)', fontFamily: 'inherit',
                        fontSize: 12, cursor: 'pointer', display: 'flex', alignItems: 'center', gap: 5,
                    }}>
                        See alts
                    </button>
                    <button style={{
                        flex: '1 1 auto', padding: '12px 14px', borderRadius: 10,
                        background: '#62b375', color: '#0a1410',
                        border: 'none', fontFamily: 'inherit',
                        fontSize: 13, fontWeight: 600, cursor: 'pointer',
                        display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6,
                    }}>
                        <Icon.Plus size={11} color="#0a1410" /> Log shot · 7 Iron
                    </button>
                </div>
            </div>

            {isMobile && <BottomTabs active="zones" />}
        </div>
    );
}

function HoleMap({ isMobile }) {
    // Stylized low-poly hole rendered top-down. Tee bottom, green top.
    // All shapes are coarse polygons — feels like the topographic motif.

    // Past shots from this round (in screen-relative %)
    const pastShots = [
        { x: 50, y: 90, club: 'D', label: 'Drive' },
        { x: 47, y: 58, club: '7i', label: '7 Iron · current' },
    ];

    return (
        <svg width="100%" height="100%" viewBox="0 0 400 700" preserveAspectRatio="xMidYMid slice" style={{ display: 'block', background: '#1a2419' }}>
            <defs>
                <pattern id="topo-rough" width="20" height="20" patternUnits="userSpaceOnUse" patternTransform="rotate(35)">
                    <path d="M0 10 L20 10" stroke="rgba(98,179,117,0.08)" strokeWidth="0.5" />
                </pattern>
                <radialGradient id="green-grad" cx="50%" cy="50%" r="50%">
                    <stop offset="0%" stopColor="#a9d18e" />
                    <stop offset="100%" stopColor="#62b375" />
                </radialGradient>
            </defs>

            {/* rough background */}
            <rect width="400" height="700" fill="#1f3324" />
            <rect width="400" height="700" fill="url(#topo-rough)" />

            {/* fairway — coarse low-poly polygon */}
            <polygon points="170,680 230,680 245,640 250,580 240,520 220,460 195,400 175,330 160,260 155,180 165,130 195,90 235,75 240,70 175,68 130,90 110,130 105,180 115,260 130,330 150,400 165,460 175,520 175,580 170,640" fill="#3a6b3e" stroke="#2c4f30" strokeWidth="0.5" />

            {/* fairway texture lines */}
            <g stroke="rgba(98,179,117,0.15)" strokeWidth="0.4" fill="none">
                <path d="M165,650 Q200,500 175,300 Q150,150 200,80" />
                <path d="M195,650 Q220,500 200,300 Q180,150 220,75" />
            </g>

            {/* bunkers — sand polygons */}
            <polygon points="100,180 130,170 145,190 140,215 110,220 90,200" fill="#e8d8a0" stroke="#c8b878" strokeWidth="0.5" />
            <polygon points="240,210 270,200 290,220 285,245 260,255 235,240" fill="#e8d8a0" stroke="#c8b878" strokeWidth="0.5" />
            <polygon points="135,90 155,88 165,100 160,115 140,118 125,108" fill="#e8d8a0" stroke="#c8b878" strokeWidth="0.5" />

            {/* water hazard — left of fairway */}
            <polygon points="50,400 80,380 90,420 75,470 50,490 30,460 25,420" fill="#1f3a5f" stroke="#13294a" strokeWidth="0.5" opacity="0.85" />
            <text x="55" y="440" fill="rgba(246,241,225,0.5)" fontSize="9" fontFamily="ui-monospace, monospace">~</text>

            {/* trees — abstract dots */}
            <g fill="#1a3320" stroke="#0e1a13" strokeWidth="0.5">
                {[
                    [60, 150], [70, 250], [55, 320], [65, 550], [75, 620],
                    [330, 130], [340, 200], [350, 280], [330, 370], [340, 480], [325, 580],
                ].map(([cx, cy], i) => (
                    <circle key={i} cx={cx} cy={cy} r={6 + (i % 3)} />
                ))}
            </g>

            {/* green */}
            <ellipse cx="200" cy="100" rx="42" ry="32" fill="url(#green-grad)" stroke="#7c9a5e" strokeWidth="0.5" />
            {/* green contours */}
            <ellipse cx="200" cy="100" rx="28" ry="22" fill="none" stroke="rgba(98,179,117,0.5)" strokeWidth="0.5" />
            <ellipse cx="200" cy="100" rx="14" ry="11" fill="none" stroke="rgba(98,179,117,0.4)" strokeWidth="0.5" />

            {/* pin */}
            <line x1="200" y1="105" x2="200" y2="78" stroke="#e85d4d" strokeWidth="1.2" />
            <polygon points="200,78 213,82 200,86" fill="#e85d4d" />
            <circle cx="200" cy="105" r="2" fill="#0a1410" />

            {/* The recommended dispersion polygon — over the green */}
            <g style={{ mixBlendMode: 'screen' }}>
                {[
                    { rx: 36, ry: 50, fill: '#0b3d2e', op: 0.5 },
                    { rx: 28, ry: 38, fill: '#16624a', op: 0.6 },
                    { rx: 20, ry: 26, fill: '#2c8a5e', op: 0.6 },
                    { rx: 12, ry: 16, fill: '#62b375', op: 0.7 },
                    { rx: 6, ry: 8, fill: '#a9d18e', op: 0.8 },
                ].map((r, i) => {
                    const facets = 22;
                    const pts = [];
                    for (let j = 0; j < facets; j++) {
                        const t = (j / facets) * Math.PI * 2;
                        pts.push(`${(200 + Math.cos(t) * r.rx).toFixed(1)},${(105 + Math.sin(t) * r.ry).toFixed(1)}`);
                    }
                    return <polygon key={i} points={pts.join(' ')} fill={r.fill} fillOpacity={r.op} />;
                })}
            </g>
            <g fill="none" stroke="rgba(246,241,225,0.3)" strokeWidth="0.5">
                {[36, 28, 20, 12].map((rx, i) => {
                    const ry = [50, 38, 26, 16][i];
                    const facets = 22;
                    const pts = [];
                    for (let j = 0; j < facets; j++) {
                        const t = (j / facets) * Math.PI * 2;
                        pts.push(`${(200 + Math.cos(t) * rx).toFixed(1)},${(105 + Math.sin(t) * ry).toFixed(1)}`);
                    }
                    return <polygon key={i} points={pts.join(' ')} />;
                })}
            </g>

            {/* shot path — past shots connected */}
            <g>
                <path d={`M ${pastShots.map((s) => `${s.x * 4},${s.y * 7}`).join(' L ')}`}
                      stroke="rgba(246,241,225,0.5)" strokeWidth="1" strokeDasharray="3 4" fill="none" />
                {pastShots.map((s, i) => (
                    <g key={i}>
                        <circle cx={s.x * 4} cy={s.y * 7} r="6" fill="rgba(246,241,225,0.15)" />
                        <circle cx={s.x * 4} cy={s.y * 7} r="3" fill="#f6f1e1" />
                        <text x={s.x * 4 + 9} y={s.y * 7 + 3} fill="rgba(246,241,225,0.85)" fontSize="9" fontFamily="ui-monospace, monospace">
                            {s.label}
                        </text>
                    </g>
                ))}
            </g>

            {/* tee marker (off-screen below in this view, hint at top edge) */}
            <text x="200" y="695" textAnchor="middle" fill="rgba(246,241,225,0.4)" fontSize="9" fontFamily="ui-monospace, monospace" letterSpacing="0.1em">
                ↓ TEE · 438Y
            </text>
        </svg>
    );
}

// Premium upgrade prompt — what the free user sees when tapping "Course mode"
function PremiumUpgradeScreen({ device = 'mobile' }) {
    const isMobile = device === 'mobile';
    return (
        <div data-screen-label={`Premium upgrade · ${device}`} style={{
            width: '100%', height: '100%',
            background: '#0e1a13', color: '#f6f1e1',
            fontFamily: 'var(--ui-font, "Inter", system-ui, sans-serif)',
            display: 'flex', flexDirection: 'column', overflow: 'hidden',
            position: 'relative',
        }}>
            <div style={{ position: 'absolute', inset: 0, opacity: 0.6, pointerEvents: 'none' }}>
                <TopoBg width={400} height={780} seed={3} color="rgba(232,93,77,0.18)" accent="rgba(232,93,77,0.5)" />
            </div>

            <div style={{ padding: '22px 22px 0', position: 'relative', zIndex: 1, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <div style={{
                    background: 'rgba(232,93,77,0.18)',
                    border: '1px solid rgba(232,93,77,0.4)',
                    borderRadius: 999, padding: '5px 12px',
                    fontSize: 10, letterSpacing: '0.2em', textTransform: 'uppercase',
                    color: '#e85d4d', fontWeight: 600,
                }}>
                    ◆ Dispersion Premium
                </div>
                <button style={{ background: 'transparent', border: 'none', color: 'rgba(246,241,225,0.5)', fontSize: 22, cursor: 'pointer' }}>×</button>
            </div>

            <div style={{ flex: '1 1 auto', padding: '32px 22px', position: 'relative', zIndex: 1, display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
                <div style={{ fontFamily: 'var(--display-font, "Fraunces", serif)', fontSize: 44, lineHeight: 1.05, letterSpacing: '-0.02em', textWrap: 'pretty', marginBottom: 16 }}>
                    Bring your <em style={{ color: '#e85d4d' }}>course</em> into the math.
                </div>
                <div style={{ fontSize: 14, lineHeight: 1.55, color: 'rgba(246,241,225,0.7)', marginBottom: 32, textWrap: 'pretty', maxWidth: 320 }}>
                    Real GPS distances, real green shapes, real hazards. Track every shot to its actual landing spot. See your dispersion drawn over the hole you're standing on.
                </div>
                <div style={{ display: 'grid', gap: 14 }}>
                    {[
                        { hd: '40,000+ courses', sub: 'GPS-mapped greens, fairways, hazards. Powered by GolfBert / USGA Course API.' },
                        { hd: 'Per-shot landing tracking', sub: 'Tap on the live hole map to log exactly where it ended up.' },
                        { hd: 'Wind & elevation adjusted', sub: 'Recommendations factor real-time wind and slope from course data.' },
                        { hd: 'Round summary & strokes-gained', sub: 'See where you bled shots vs. the optimal play.' },
                    ].map((f) => (
                        <div key={f.hd} style={{ display: 'grid', gridTemplateColumns: '20px 1fr', gap: 12, alignItems: 'flex-start' }}>
                            <div style={{ width: 6, height: 6, borderRadius: '50%', background: '#e85d4d', marginTop: 8 }} />
                            <div>
                                <div style={{ fontSize: 14, fontWeight: 500 }}>{f.hd}</div>
                                <div style={{ fontSize: 12, color: 'rgba(246,241,225,0.55)', marginTop: 2, lineHeight: 1.5 }}>{f.sub}</div>
                            </div>
                        </div>
                    ))}
                </div>
            </div>

            <div style={{ padding: '0 22px 26px', position: 'relative', zIndex: 1 }}>
                <div style={{
                    background: 'rgba(246,241,225,0.04)',
                    border: '1px solid rgba(246,241,225,0.1)',
                    borderRadius: 14, padding: 18, marginBottom: 12,
                }}>
                    <div style={{ display: 'flex', alignItems: 'baseline', justifyContent: 'space-between', marginBottom: 6 }}>
                        <span style={{ fontFamily: 'var(--display-font, "Fraunces", serif)', fontSize: 32, lineHeight: 1, letterSpacing: '-0.02em' }}>$6<span style={{ fontSize: 14, color: 'rgba(246,241,225,0.6)' }}>/mo</span></span>
                        <span style={{ fontSize: 11, color: 'rgba(246,241,225,0.5)', fontFamily: 'ui-monospace, monospace' }}>or $48/yr</span>
                    </div>
                    <div style={{ fontSize: 12, color: 'rgba(246,241,225,0.55)' }}>14-day free trial · cancel anytime</div>
                </div>
                <button style={{
                    width: '100%', padding: '15px', borderRadius: 12,
                    background: '#e85d4d', color: '#0a1410',
                    border: 'none', fontFamily: 'inherit',
                    fontSize: 14, fontWeight: 600, cursor: 'pointer', letterSpacing: '0.04em',
                }}>
                    Start free trial
                </button>
                <div style={{ textAlign: 'center', marginTop: 14, fontSize: 11, color: 'rgba(246,241,225,0.4)' }}>
                    Free tier — your bag, your math, forever local. Always.
                </div>
            </div>
        </div>
    );
}

window.CourseScreen = CourseScreen;
window.PremiumUpgradeScreen = PremiumUpgradeScreen;
