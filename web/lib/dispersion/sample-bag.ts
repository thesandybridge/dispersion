// A reasonable mid-handicap bag for the marketing demo. Numbers are
// representative — handicap ~10, σ↕ ~6y, σ↔ ~9y across the irons.

import type { Club } from "./types";

export const SAMPLE_BAG: Club[] = [
  { id: "driver", name: "Driver",     carryYards: 245, carrySd: 12, lateralSd: 18 },
  { id: "3w",     name: "3 Wood",     carryYards: 225, carrySd: 11, lateralSd: 16 },
  { id: "5w",     name: "5 Wood",     carryYards: 210, carrySd: 10, lateralSd: 14 },
  { id: "4i",     name: "4 Iron",     carryYards: 195, carrySd:  9, lateralSd: 13 },
  { id: "5i",     name: "5 Iron",     carryYards: 182, carrySd:  8, lateralSd: 12 },
  { id: "6i",     name: "6 Iron",     carryYards: 170, carrySd:  7, lateralSd: 11 },
  { id: "7i",     name: "7 Iron",     carryYards: 158, carrySd:  6, lateralSd: 10 },
  { id: "8i",     name: "8 Iron",     carryYards: 145, carrySd:  6, lateralSd:  9 },
  { id: "9i",     name: "9 Iron",     carryYards: 132, carrySd:  5, lateralSd:  8 },
  { id: "pw",     name: "PW",         carryYards: 118, carrySd:  5, lateralSd:  7 },
  { id: "gw",     name: "GW (50°)",   carryYards: 105, carrySd:  4, lateralSd:  6 },
  { id: "sw",     name: "SW (56°)",   carryYards:  88, carrySd:  4, lateralSd:  5 },
  { id: "lw",     name: "LW (60°)",   carryYards:  72, carrySd:  4, lateralSd:  5 },
];
