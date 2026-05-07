import { create } from "zustand";
import { persist } from "zustand/middleware";

export const TAG_ACCENTS = [
    { id: "bentgrass", label: "Bentgrass", value: "#62b375" },
    { id: "flag", label: "Flag", value: "#e85d4d" },
    { id: "sand", label: "Sand", value: "#f0e7b8" },
    { id: "water", label: "Water", value: "#1f3a5f" },
    { id: "pine", label: "Pine", value: "#0b3d2e" },
    { id: "sage", label: "Sage", value: "#a9d18e" },
] as const;

export type ProfileAccent = (typeof TAG_ACCENTS)[number]["id"];

export const TAG_FONTS = [
    { id: "fraunces", label: "Fraunces", family: 'var(--font-display)' },
    { id: "inter", label: "Inter", family: 'var(--font-sans)' },
    { id: "mono", label: "Mono", family: 'var(--font-mono)' },
] as const;

export type ProfileFont = (typeof TAG_FONTS)[number]["id"];

export const TAG_MATERIALS = [
    {
        id: "brass",
        label: "Brass",
        strapTop: "#c39a4a",
        strapBottom: "#7e5c1d",
        grommet: "#3a2a0e",
        accent: "#d4b25a",
    },
    {
        id: "silver",
        label: "Silver",
        strapTop: "#d8dadf",
        strapBottom: "#7a7d83",
        grommet: "#22252b",
        accent: "#c4c8cf",
    },
    {
        id: "copper",
        label: "Copper",
        strapTop: "#c97a4d",
        strapBottom: "#724224",
        grommet: "#2c1c12",
        accent: "#d68a5d",
    },
    {
        id: "leather",
        label: "Leather",
        strapTop: "#6b5840",
        strapBottom: "#4a3c2c",
        grommet: "#0a1410",
        accent: "#8b6f4d",
    },
    {
        id: "carbon",
        label: "Carbon",
        strapTop: "#2a2d33",
        strapBottom: "#15171b",
        grommet: "#000000",
        accent: "#3a3d44",
    },
] as const;

export type ProfileMaterial = (typeof TAG_MATERIALS)[number]["id"];

export type ProfileState = {
    name: string;
    handicap: string;
    homeCourse: string;
    motto: string;
    accent: ProfileAccent;
    contact: string;
    font: ProfileFont;
    material: ProfileMaterial;
    setProfile: (patch: Partial<Omit<ProfileState, "setProfile">>) => void;
};

export const useProfile = create<ProfileState>()(
    persist(
        (set) => ({
            name: "",
            handicap: "",
            homeCourse: "",
            motto: "",
            accent: "bentgrass",
            contact: "",
            font: "fraunces",
            material: "leather",
            setProfile: (patch) => set(patch),
        }),
        {
            name: "dispersion.profile.v1",
            partialize: (s) => ({
                name: s.name,
                handicap: s.handicap,
                homeCourse: s.homeCourse,
                motto: s.motto,
                accent: s.accent,
                contact: s.contact,
                font: s.font,
                material: s.material,
            }),
        },
    ),
);

export function accentColor(id: ProfileAccent): string {
    return TAG_ACCENTS.find((a) => a.id === id)?.value ?? "#62b375";
}

export function fontFamily(id: ProfileFont): string {
    return (
        TAG_FONTS.find((f) => f.id === id)?.family ?? "var(--font-display)"
    );
}

export function material(id: ProfileMaterial) {
    return (
        TAG_MATERIALS.find((m) => m.id === id) ??
        TAG_MATERIALS[3]
    );
}
