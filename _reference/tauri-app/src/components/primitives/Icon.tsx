type IconProps = {
    size?: number;
    color?: string;
};

export const Icon = {
    Flag: ({ size = 16, color = "currentColor" }: IconProps) => (
        <svg
            width={size}
            height={size}
            viewBox="0 0 16 16"
            fill="none"
            stroke={color}
            strokeWidth="1.4"
            strokeLinecap="round"
            strokeLinejoin="round"
        >
            <line x1="4" y1="2" x2="4" y2="14" />
            <path d="M4 3 L13 5 L4 7" fill={color} fillOpacity="0.2" />
            <circle cx="4" cy="14" r="0.8" fill={color} />
        </svg>
    ),
    Target: ({ size = 16, color = "currentColor" }: IconProps) => (
        <svg
            width={size}
            height={size}
            viewBox="0 0 16 16"
            fill="none"
            stroke={color}
            strokeWidth="1.3"
        >
            <circle cx="8" cy="8" r="6" />
            <circle cx="8" cy="8" r="3" />
            <circle cx="8" cy="8" r="0.8" fill={color} />
        </svg>
    ),
    Bag: ({ size = 16, color = "currentColor" }: IconProps) => (
        <svg
            width={size}
            height={size}
            viewBox="0 0 16 16"
            fill="none"
            stroke={color}
            strokeWidth="1.3"
            strokeLinejoin="round"
        >
            <rect x="3" y="4" width="10" height="10" rx="2" />
            <line x1="6" y1="2" x2="6" y2="6" />
            <line x1="10" y1="2" x2="10" y2="6" />
        </svg>
    ),
    Settings: ({ size = 16, color = "currentColor" }: IconProps) => (
        <svg
            width={size}
            height={size}
            viewBox="0 0 16 16"
            fill="none"
            stroke={color}
            strokeWidth="1.3"
            strokeLinecap="round"
        >
            <circle cx="8" cy="8" r="2" />
            <path d="M8 1 L8 3 M8 13 L8 15 M1 8 L3 8 M13 8 L15 8 M3.5 3.5 L4.9 4.9 M11.1 11.1 L12.5 12.5 M3.5 12.5 L4.9 11.1 M11.1 4.9 L12.5 3.5" />
        </svg>
    ),
    ChevronRight: ({ size = 14, color = "currentColor" }: IconProps) => (
        <svg
            width={size}
            height={size}
            viewBox="0 0 16 16"
            fill="none"
            stroke={color}
            strokeWidth="1.6"
            strokeLinecap="round"
            strokeLinejoin="round"
        >
            <polyline points="6,3 11,8 6,13" />
        </svg>
    ),
    Plus: ({ size = 14, color = "currentColor" }: IconProps) => (
        <svg
            width={size}
            height={size}
            viewBox="0 0 16 16"
            fill="none"
            stroke={color}
            strokeWidth="1.6"
            strokeLinecap="round"
        >
            <line x1="8" y1="3" x2="8" y2="13" />
            <line x1="3" y1="8" x2="13" y2="8" />
        </svg>
    ),
    Sliders: ({ size = 16, color = "currentColor" }: IconProps) => (
        <svg
            width={size}
            height={size}
            viewBox="0 0 16 16"
            fill="none"
            stroke={color}
            strokeWidth="1.3"
            strokeLinecap="round"
        >
            <line x1="3" y1="4" x2="13" y2="4" />
            <circle cx="9" cy="4" r="1.4" fill={color} />
            <line x1="3" y1="12" x2="13" y2="12" />
            <circle cx="6" cy="12" r="1.4" fill={color} />
        </svg>
    ),
    Wind: ({ size = 16, color = "currentColor" }: IconProps) => (
        <svg
            width={size}
            height={size}
            viewBox="0 0 16 16"
            fill="none"
            stroke={color}
            strokeWidth="1.2"
            strokeLinecap="round"
        >
            <path d="M2 5 L9 5 A1.5 1.5 0 1 0 7.5 3.5" />
            <path d="M2 8 L12 8 A2 2 0 1 0 10 6" />
            <path d="M2 11 L7 11" />
        </svg>
    ),
};
