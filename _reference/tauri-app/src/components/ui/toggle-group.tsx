import * as React from "react";
import * as ToggleGroupPrimitive from "@radix-ui/react-toggle-group";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/cn";

const toggleGroupVariants = cva("flex items-center gap-1.5 flex-wrap", {
    variants: {
        variant: {
            default: "",
            outline: "rounded-full border border-border p-1 bg-muted/30",
        },
    },
    defaultVariants: { variant: "default" },
});

const ToggleGroupContext = React.createContext<
    VariantProps<typeof toggleGroupVariants>
>({ variant: "default" });

function ToggleGroup({
    className,
    variant,
    children,
    ...props
}: React.ComponentProps<typeof ToggleGroupPrimitive.Root> &
    VariantProps<typeof toggleGroupVariants>) {
    return (
        <ToggleGroupPrimitive.Root
            data-slot="toggle-group"
            className={cn(toggleGroupVariants({ variant }), className)}
            {...props}
        >
            <ToggleGroupContext.Provider value={{ variant }}>
                {children}
            </ToggleGroupContext.Provider>
        </ToggleGroupPrimitive.Root>
    );
}

function ToggleGroupItem({
    className,
    children,
    ...props
}: React.ComponentProps<typeof ToggleGroupPrimitive.Item>) {
    const ctx = React.useContext(ToggleGroupContext);
    return (
        <ToggleGroupPrimitive.Item
            data-slot="toggle-group-item"
            className={cn(
                "inline-flex items-center justify-center gap-1.5 rounded-full px-4 py-2 text-[13px] font-medium select-none transition-[background,color,box-shadow]",
                "bg-muted/40 text-muted-foreground hover:bg-muted/70",
                "data-[state=on]:bg-foreground data-[state=on]:text-background data-[state=on]:shadow-sm",
                "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring/40",
                "disabled:pointer-events-none disabled:opacity-50",
                ctx.variant === "outline" && "rounded-full",
                className,
            )}
            {...props}
        >
            {children}
        </ToggleGroupPrimitive.Item>
    );
}

export { ToggleGroup, ToggleGroupItem };
