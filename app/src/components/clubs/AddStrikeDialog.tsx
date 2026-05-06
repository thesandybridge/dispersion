import * as Dialog from "@radix-ui/react-dialog";
import { useEffect, useState } from "react";
import { ClubFaceViz } from "../primitives/ClubFaceViz";

type Props = {
    open: boolean;
    onOpenChange: (open: boolean) => void;
    onAdd: (input: { x: number; y: number; note: string }) => void;
};

export function AddStrikeDialog({ open, onOpenChange, onAdd }: Props) {
    const [point, setPoint] = useState<{ x: number; y: number } | null>(null);
    const [note, setNote] = useState("");

    useEffect(() => {
        if (open) {
            setPoint(null);
            setNote("");
        }
    }, [open]);

    function save() {
        if (!point) return;
        onAdd({ x: point.x, y: point.y, note: note.trim() });
        onOpenChange(false);
    }

    return (
        <Dialog.Root open={open} onOpenChange={onOpenChange}>
            <Dialog.Portal>
                <Dialog.Overlay
                    className="fixed inset-0 z-50"
                    style={{
                        background: "rgba(10,20,16,0.55)",
                        backdropFilter: "blur(2px)",
                        WebkitBackdropFilter: "blur(2px)",
                    }}
                />
                <Dialog.Content
                    className="fixed bottom-0 left-0 right-0 z-50 w-full rounded-t-3xl px-6 pt-6 shadow-xl outline-none animate-sheet-up"
                    style={{
                        background: "#f4efe3",
                        color: "#1a2419",
                        border: "1px solid rgba(26,36,25,0.08)",
                        maxHeight: "min(86vh, 720px)",
                        paddingBottom:
                            "max(env(safe-area-inset-bottom), 18px)",
                        overflow: "auto",
                    }}
                >
                    <div className="flex justify-center -mt-3 mb-2">
                        <div
                            className="rounded-full"
                            style={{
                                width: 36,
                                height: 4,
                                background: "rgba(26,36,25,0.18)",
                            }}
                        />
                    </div>
                    <div
                        className="text-[10px] tracking-[0.2em] uppercase"
                        style={{ color: "rgba(26,36,25,0.5)" }}
                    >
                        Impact tape
                    </div>
                    <Dialog.Title
                        className="font-display text-2xl mt-1 mb-1"
                        style={{ letterSpacing: "-0.02em" }}
                    >
                        Mark a strike
                    </Dialog.Title>
                    <Dialog.Description
                        className="text-[12px] mb-4"
                        style={{ color: "rgba(26,36,25,0.55)" }}
                    >
                        Tap the face where the ball hit. Add a note (swing
                        thought, conditions, miss tendency).
                    </Dialog.Description>

                    <div
                        className="rounded-[10px] overflow-hidden mb-3"
                        style={{
                            aspectRatio: "1.45",
                            background: "#0e1a13",
                        }}
                    >
                        <ClubFaceViz
                            strikes={[]}
                            cursor={point}
                            onTap={(p) => setPoint(p)}
                        />
                    </div>

                    {point ? (
                        <div
                            className="rounded-lg px-3 py-2 mb-3 font-mono text-[11px]"
                            style={{
                                background: "rgba(26,36,25,0.05)",
                                color: "rgba(26,36,25,0.7)",
                            }}
                        >
                            {describeFace(point)}
                        </div>
                    ) : (
                        <div
                            className="rounded-lg px-3 py-2 mb-3 text-[11px]"
                            style={{
                                background: "rgba(26,36,25,0.05)",
                                color: "rgba(26,36,25,0.5)",
                            }}
                        >
                            Tap a position to start.
                        </div>
                    )}

                    <label className="block mb-4">
                        <div
                            className="text-[10px] tracking-[0.18em] uppercase mb-1.5"
                            style={{ color: "rgba(26,36,25,0.55)" }}
                        >
                            Note
                        </div>
                        <textarea
                            value={note}
                            onChange={(e) => setNote(e.target.value)}
                            rows={2}
                            placeholder="e.g. open face, fat strike, kept head still"
                            className="w-full rounded-lg bg-white outline-none px-3 py-2 text-[14px] resize-none"
                            style={{
                                border: "1px solid rgba(26,36,25,0.15)",
                                color: "#1a2419",
                                fontFamily: "inherit",
                            }}
                        />
                    </label>

                    <div className="flex justify-end gap-2">
                        <Dialog.Close asChild>
                            <button
                                className="px-4 py-2 rounded-full text-[13px]"
                                style={{
                                    color: "rgba(26,36,25,0.7)",
                                    background: "rgba(26,36,25,0.05)",
                                }}
                            >
                                Cancel
                            </button>
                        </Dialog.Close>
                        <button
                            onClick={save}
                            disabled={!point}
                            className="px-4 py-2 rounded-full text-[13px] font-medium disabled:opacity-40"
                            style={{
                                background: "#1a2419",
                                color: "#f4efe3",
                            }}
                        >
                            Save strike
                        </button>
                    </div>
                </Dialog.Content>
            </Dialog.Portal>
        </Dialog.Root>
    );
}

export function describeFace({
    x,
    y,
}: {
    x: number;
    y: number;
}): string {
    const lat = describeLat(x);
    const vert = describeVert(y);
    if (Math.abs(x) < 0.18 && Math.abs(y) < 0.2) return "Center";
    return [vert, lat].filter(Boolean).join(" · ");
}

function describeLat(x: number): string {
    if (x < -0.6) return "Heel";
    if (x < -0.2) return "Slight heel";
    if (x > 0.6) return "Toe";
    if (x > 0.2) return "Slight toe";
    return "";
}

function describeVert(y: number): string {
    if (y > 0.6) return "High";
    if (y > 0.2) return "Slightly high";
    if (y < -0.6) return "Low";
    if (y < -0.2) return "Slightly low";
    return "";
}
