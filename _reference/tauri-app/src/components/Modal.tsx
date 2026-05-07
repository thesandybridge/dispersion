import { useEffect, useRef, type ReactNode } from "react";

type Props = {
    onClose: () => void;
    labelledBy: string;
    children: ReactNode;
};

const FOCUSABLE =
    'a[href], button:not([disabled]), textarea:not([disabled]), input:not([disabled]), select:not([disabled]), [tabindex]:not([tabindex="-1"])';

export function Modal({ onClose, labelledBy, children }: Props) {
    const dialogRef = useRef<HTMLDivElement>(null);
    const previousFocus = useRef<HTMLElement | null>(null);

    useEffect(() => {
        previousFocus.current = document.activeElement as HTMLElement | null;
        const dialog = dialogRef.current;
        if (!dialog) return;

        const focusables = dialog.querySelectorAll<HTMLElement>(FOCUSABLE);
        (focusables[0] ?? dialog).focus();

        const prevOverflow = document.body.style.overflow;
        document.body.style.overflow = "hidden";

        function onKeyDown(e: KeyboardEvent) {
            if (e.key === "Escape") {
                e.stopPropagation();
                onClose();
                return;
            }
            if (e.key !== "Tab") return;
            const els = Array.from(
                dialog!.querySelectorAll<HTMLElement>(FOCUSABLE),
            ).filter((el) => !el.hasAttribute("data-focus-skip"));
            if (els.length === 0) {
                e.preventDefault();
                return;
            }
            const first = els[0]!;
            const last = els[els.length - 1]!;
            const active = document.activeElement as HTMLElement | null;
            if (e.shiftKey && active === first) {
                e.preventDefault();
                last.focus();
            } else if (!e.shiftKey && active === last) {
                e.preventDefault();
                first.focus();
            }
        }

        document.addEventListener("keydown", onKeyDown);
        return () => {
            document.removeEventListener("keydown", onKeyDown);
            document.body.style.overflow = prevOverflow;
            previousFocus.current?.focus?.();
        };
    }, [onClose]);

    return (
        <div
            className="fixed inset-0 z-50 flex items-end justify-center bg-black/40"
            onClick={onClose}
            style={{ touchAction: "none" }}
        >
            <div
                ref={dialogRef}
                role="dialog"
                aria-modal="true"
                aria-labelledby={labelledBy}
                tabIndex={-1}
                className="w-full rounded-t-3xl shadow-xl outline-none animate-sheet-up"
                style={{
                    background: "#f4efe3",
                    color: "#1a2419",
                    border: "1px solid rgba(26,36,25,0.08)",
                    maxHeight: "min(86vh, 720px)",
                    paddingBottom:
                        "max(env(safe-area-inset-bottom), 18px)",
                    overflow: "auto",
                }}
                onClick={(e) => e.stopPropagation()}
            >
                <div
                    className="sticky top-0 flex justify-center pt-2.5 pb-1"
                    style={{
                        background: "#f4efe3",
                        zIndex: 1,
                    }}
                >
                    <div
                        className="rounded-full"
                        style={{
                            width: 36,
                            height: 4,
                            background: "rgba(26,36,25,0.18)",
                        }}
                    />
                </div>
                <div className="px-6 pt-4">{children}</div>
            </div>
        </div>
    );
}
