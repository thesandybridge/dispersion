import { Component, type ReactNode } from "react";

type Props = { children: ReactNode };
type State = { error: Error | null };

export class ErrorBoundary extends Component<Props, State> {
    override state: State = { error: null };

    static getDerivedStateFromError(error: Error): State {
        return { error };
    }

    override componentDidCatch(
        error: Error,
        info: { componentStack?: string | null },
    ) {
        if (import.meta.env.DEV) {
            console.error("ErrorBoundary caught:", error, info.componentStack);
        }
    }

    handleReset = () => {
        this.setState({ error: null });
    };

    override render() {
        if (this.state.error) {
            return (
                <div
                    role="alert"
                    className="min-h-svh bg-[#f4efe3] text-[#1a2419] flex items-center justify-center p-6"
                >
                    <div className="max-w-md w-full rounded-2xl border border-[#1a2419]/10 bg-white/60 p-6">
                        <div className="text-[10px] tracking-[0.2em] uppercase text-[#1a2419]/50">
                            Something broke
                        </div>
                        <h1 className="text-2xl font-serif tracking-tight mt-1 mb-3">
                            Unexpected error
                        </h1>
                        <pre className="text-xs bg-[#1a2419]/5 rounded-lg p-3 overflow-auto whitespace-pre-wrap break-words">
                            {this.state.error.message}
                        </pre>
                        <div className="mt-4 flex justify-end">
                            <button
                                onClick={this.handleReset}
                                className="px-4 py-2 rounded-full text-sm bg-[#1a2419] text-[#f4efe3]"
                            >
                                Reset
                            </button>
                        </div>
                    </div>
                </div>
            );
        }
        return this.props.children;
    }
}
