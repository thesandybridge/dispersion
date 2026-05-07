type ImpactStyle = "light" | "medium" | "heavy";

let pluginPromise: Promise<typeof import("@tauri-apps/plugin-haptics") | null> | null = null;

async function load() {
    if (pluginPromise) return pluginPromise;
    pluginPromise = import("@tauri-apps/plugin-haptics").catch(() => null);
    return pluginPromise;
}

export async function tap(style: ImpactStyle = "light"): Promise<void> {
    if (typeof window === "undefined") return;
    try {
        const mod = await load();
        if (!mod) return;
        await mod.impactFeedback(style);
    } catch {
        /* ignored — desktop / unsupported */
    }
}

export async function notify(
    type: "success" | "warning" | "error" = "success",
): Promise<void> {
    if (typeof window === "undefined") return;
    try {
        const mod = await load();
        if (!mod) return;
        await mod.notificationFeedback(type);
    } catch {
        /* ignored */
    }
}

export async function selection(): Promise<void> {
    if (typeof window === "undefined") return;
    try {
        const mod = await load();
        if (!mod) return;
        await mod.selectionFeedback();
    } catch {
        /* ignored */
    }
}
