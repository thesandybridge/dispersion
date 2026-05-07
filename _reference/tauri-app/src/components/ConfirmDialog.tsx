import * as AlertDialog from "@radix-ui/react-alert-dialog";
import type { ReactNode } from "react";
import { tap } from "../lib/haptics";

type Props = {
    open: boolean;
    onOpenChange: (open: boolean) => void;
    title: string;
    description?: ReactNode;
    confirmLabel?: string;
    cancelLabel?: string;
    danger?: boolean;
    onConfirm: () => void;
};

export function ConfirmDialog({
    open,
    onOpenChange,
    title,
    description,
    confirmLabel = "Confirm",
    cancelLabel = "Cancel",
    danger = false,
    onConfirm,
}: Props) {
    return (
        <AlertDialog.Root open={open} onOpenChange={onOpenChange}>
            <AlertDialog.Portal>
                <AlertDialog.Overlay
                    className="fixed inset-0 z-50"
                    style={{
                        background: "rgba(10,20,16,0.55)",
                        backdropFilter: "blur(2px)",
                        WebkitBackdropFilter: "blur(2px)",
                    }}
                />
                <AlertDialog.Content
                    className="fixed left-1/2 top-1/2 z-50 w-[calc(100%-32px)] max-w-md -translate-x-1/2 -translate-y-1/2 rounded-2xl p-6 shadow-xl outline-none"
                    style={{
                        background: "#f4efe3",
                        color: "#1a2419",
                        border: "1px solid rgba(26,36,25,0.08)",
                    }}
                >
                    <AlertDialog.Title
                        className="font-display text-2xl mb-2"
                        style={{ letterSpacing: "-0.02em" }}
                    >
                        {title}
                    </AlertDialog.Title>
                    {description && (
                        <AlertDialog.Description
                            className="text-[13px] leading-relaxed mb-5"
                            style={{ color: "rgba(26,36,25,0.65)" }}
                        >
                            {description}
                        </AlertDialog.Description>
                    )}
                    <div className="flex justify-end gap-2">
                        <AlertDialog.Cancel asChild>
                            <button
                                className="px-4 py-2 rounded-full text-[13px]"
                                style={{
                                    color: "rgba(26,36,25,0.7)",
                                    background: "rgba(26,36,25,0.05)",
                                }}
                            >
                                {cancelLabel}
                            </button>
                        </AlertDialog.Cancel>
                        <AlertDialog.Action asChild>
                            <button
                                onClick={() => {
                                    tap(danger ? "heavy" : "medium");
                                    onConfirm();
                                }}
                                className="px-4 py-2 rounded-full text-[13px] font-medium"
                                style={{
                                    background: danger ? "#a23939" : "#1a2419",
                                    color: "#f4efe3",
                                }}
                            >
                                {confirmLabel}
                            </button>
                        </AlertDialog.Action>
                    </div>
                </AlertDialog.Content>
            </AlertDialog.Portal>
        </AlertDialog.Root>
    );
}
