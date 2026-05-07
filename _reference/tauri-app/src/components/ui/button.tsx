import * as React from "react";
import { Slot } from "@radix-ui/react-slot";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/cn";

const buttonVariants = cva(
    "inline-flex items-center justify-center gap-2 whitespace-nowrap font-medium select-none transition-[background,color,box-shadow,transform] disabled:pointer-events-none disabled:opacity-50 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring/60 [&>svg]:size-4 [&>svg]:shrink-0 active:scale-[0.98]",
    {
        variants: {
            variant: {
                default:
                    "bg-primary text-primary-foreground hover:bg-primary/90 shadow-[0_1px_0_rgba(0,0,0,0.05),0_2px_8px_-2px_rgba(0,0,0,0.25)]",
                solid:
                    "bg-foreground text-background hover:bg-foreground/90",
                accent:
                    "bg-accent text-accent-foreground hover:bg-accent/90",
                destructive:
                    "bg-destructive text-destructive-foreground hover:bg-destructive/90",
                outline:
                    "border border-border bg-transparent hover:bg-muted/50 text-foreground",
                secondary:
                    "bg-secondary text-secondary-foreground hover:bg-secondary/80",
                ghost:
                    "bg-transparent hover:bg-muted/60 text-foreground",
                link:
                    "underline-offset-4 hover:underline text-primary",
            },
            size: {
                default: "h-10 px-4 text-[13px] rounded-full",
                sm: "h-8 px-3 text-[12px] rounded-full",
                lg: "h-12 px-6 text-[14px] rounded-full",
                icon: "size-10 rounded-full",
                "icon-sm": "size-8 rounded-full",
            },
        },
        defaultVariants: { variant: "default", size: "default" },
    },
);

function Button({
    className,
    variant,
    size,
    asChild = false,
    ...props
}: React.ComponentProps<"button"> &
    VariantProps<typeof buttonVariants> & { asChild?: boolean }) {
    const Comp = asChild ? Slot : "button";
    return (
        <Comp
            data-slot="button"
            className={cn(buttonVariants({ variant, size }), className)}
            {...props}
        />
    );
}

export { Button, buttonVariants };
