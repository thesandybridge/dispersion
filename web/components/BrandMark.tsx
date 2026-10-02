export function BrandMark({ className = "h-8 w-8" }: { className?: string }) {
  return (
    <svg viewBox="0 0 100 100" fill="none" className={className} aria-hidden="true">
      <g stroke="currentColor" strokeWidth="3.5">
        <ellipse cx="50" cy="65" rx="34" ry="19" />
        <ellipse cx="50" cy="65" rx="23" ry="12" />
      </g>
      <path d="M50 22V65" stroke="currentColor" strokeWidth="5" strokeLinecap="round" />
      <path d="M50 20L77 31L50 42Z" fill="currentColor" />
    </svg>
  );
}
