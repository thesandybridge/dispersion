// Mock data + shared bits used across the prototype screens.

const MOCK_BAG = [
    { id: 'd', name: 'Driver', carry: 268, carrySd: 16, lateralSd: 22, prob: 0.08 },
    { id: '3w', name: '3 Wood', carry: 245, carrySd: 14, lateralSd: 18, prob: 0.12 },
    { id: '5w', name: '5 Wood', carry: 225, carrySd: 12, lateralSd: 15, prob: 0.18 },
    { id: '4i', name: '4 Iron', carry: 205, carrySd: 11, lateralSd: 13, prob: 0.27 },
    { id: '5i', name: '5 Iron', carry: 192, carrySd: 9, lateralSd: 11, prob: 0.41 },
    { id: '6i', name: '6 Iron', carry: 180, carrySd: 8, lateralSd: 10, prob: 0.58 },
    { id: '7i', name: '7 Iron', carry: 168, carrySd: 7, lateralSd: 9, prob: 0.71 },
    { id: '8i', name: '8 Iron', carry: 155, carrySd: 6, lateralSd: 8, prob: 0.62 },
    { id: '9i', name: '9 Iron', carry: 142, carrySd: 6, lateralSd: 7, prob: 0.44 },
    { id: 'pw', name: 'PW', carry: 128, carrySd: 5, lateralSd: 6, prob: 0.31 },
    { id: 'gw', name: 'GW', carry: 115, carrySd: 5, lateralSd: 6, prob: 0.18 },
    { id: 'sw', name: 'SW', carry: 95, carrySd: 5, lateralSd: 5, prob: 0.08 },
    { id: 'lw', name: 'LW', carry: 78, carrySd: 4, lateralSd: 5, prob: 0.03 },
];

const MOCK_PRESETS = [
    { id: 'green', name: 'Average green', width: 28, depth: 30, hint: 'Mid-sized putting surface' },
    { id: 'tight', name: 'Tight fairway', width: 24, depth: 60, hint: 'Trees both sides' },
    { id: 'wide', name: 'Wide fairway', width: 50, depth: 80, hint: 'Generous tee shot' },
    { id: 'pin', name: 'Tucked pin', width: 12, depth: 14, hint: 'Tournament back-right' },
];

const probLabel = (p) => {
    if (p >= 0.6) return { label: 'STRONGLY FAVORED', color: '#62b375' };
    if (p >= 0.4) return { label: 'FAVORED', color: '#a9d18e' };
    if (p >= 0.2) return { label: 'MARGINAL', color: '#e6c068' };
    return { label: 'POOR', color: '#c87060' };
};

window.MOCK_BAG = MOCK_BAG;
window.MOCK_PRESETS = MOCK_PRESETS;
window.probLabel = probLabel;
