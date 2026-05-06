import * as React from "react";
import * as SliderPrimitive from "@radix-ui/react-slider";
import { cn } from "@/lib/cn";

function Slider({
    className,
    defaultValue,
    value,
    min = 0,
    max = 100,
    ...props
}: React.ComponentProps<typeof SliderPrimitive.Root>) {
    const _values = React.useMemo(
        () =>
            Array.isArray(value)
                ? value
                : Array.isArray(defaultValue)
                  ? defaultValue
                  : [min, max],
        [value, defaultValue, min, max],
    );

    return (
        <SliderPrimitive.Root
            data-slot="slider"
            defaultValue={defaultValue}
            value={value}
            min={min}
            max={max}
            className={cn(
                "relative flex w-full touch-none select-none items-center",
                "data-[disabled]:opacity-50",
                className,
            )}
            {...props}
        >
            <SliderPrimitive.Track
                data-slot="slider-track"
                className="relative h-1.5 w-full grow overflow-hidden rounded-full bg-input"
            >
                <SliderPrimitive.Range
                    data-slot="slider-range"
                    className="absolute h-full bg-primary"
                />
            </SliderPrimitive.Track>
            {Array.from({ length: _values.length }, (_, i) => (
                <SliderPrimitive.Thumb
                    data-slot="slider-thumb"
                    key={i}
                    className="block size-5 rounded-full border-2 border-primary bg-background shadow-[0_2px_6px_rgba(0,0,0,0.35)] transition-transform hover:scale-110 active:scale-110 focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-ring/30 disabled:pointer-events-none"
                />
            ))}
        </SliderPrimitive.Root>
    );
}

export { Slider };
