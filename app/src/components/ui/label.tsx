import * as React from "react";
import * as LabelPrimitive from "@radix-ui/react-label";
import { cn } from "@/lib/cn";

function Label({
    className,
    ...props
}: React.ComponentProps<typeof LabelPrimitive.Root>) {
    return (
        <LabelPrimitive.Root
            data-slot="label"
            className={cn(
                "font-mono text-[10px] tracking-[0.22em] uppercase text-muted-foreground select-none",
                className,
            )}
            {...props}
        />
    );
}

export { Label };
