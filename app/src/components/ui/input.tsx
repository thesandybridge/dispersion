import * as React from "react";
import { cn } from "@/lib/cn";

function Input({ className, type, ...props }: React.ComponentProps<"input">) {
    return (
        <input
            type={type}
            data-slot="input"
            className={cn(
                "flex h-11 w-full min-w-0 rounded-xl border border-border bg-input/40 px-3.5 py-2 text-[14px] shadow-[inset_0_1px_0_rgba(255,255,255,0.02)] outline-none transition-[border-color,box-shadow,background] placeholder:text-muted-foreground/70",
                "focus-visible:border-ring/70 focus-visible:ring-2 focus-visible:ring-ring/30",
                "aria-invalid:border-destructive/70 aria-invalid:ring-destructive/30",
                "disabled:cursor-not-allowed disabled:opacity-50",
                "file:bg-transparent file:text-sm file:font-medium",
                className,
            )}
            {...props}
        />
    );
}

export { Input };
