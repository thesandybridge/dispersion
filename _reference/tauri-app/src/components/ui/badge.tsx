import * as React from "react";
import { Slot } from "@radix-ui/react-slot";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/cn";

const badgeVariants = cva(
    "inline-flex items-center justify-center gap-1 px-2 py-0.5 rounded-full font-mono text-[10px] tracking-[0.18em] uppercase select-none whitespace-nowrap [&>svg]:size-3 [&>svg]:shrink-0",
    {
        variants: {
            variant: {
                default: "bg-primary/15 text-primary border border-primary/25",
                secondary:
                    "bg-secondary text-secondary-foreground border border-border",
                outline: "border border-border text-muted-foreground",
                solid: "bg-foreground text-background",
                accent: "bg-accent/20 text-accent border border-accent/30",
                destructive:
                    "bg-destructive/15 text-destructive border border-destructive/30",
            },
        },
        defaultVariants: { variant: "default" },
    },
);

function Badge({
    className,
    variant,
    asChild = false,
    ...props
}: React.ComponentProps<"span"> &
    VariantProps<typeof badgeVariants> & { asChild?: boolean }) {
    const Comp = asChild ? Slot : "span";
    return (
        <Comp
            data-slot="badge"
            className={cn(badgeVariants({ variant }), className)}
            {...props}
        />
    );
}

export { Badge, badgeVariants };
