import { Component, type ErrorInfo, type ReactNode } from "react";
import { useGameStore } from "../stores/gameStore";

interface Props {
	children: ReactNode;
	fallback?: ReactNode;
	onError?: (error: Error, errorInfo: ErrorInfo) => void;
	/** When true, show "Return to Lobby" that leaves the game room */
	returnToLobby?: boolean;
}

interface State {
	hasError: boolean;
	error: Error | null;
}

/**
 * Catches errors in the child tree and shows a fallback UI instead of crashing.
 */
export class ErrorBoundary extends Component<Props, State> {
	constructor(props: Props) {
		super(props);
		this.state = { hasError: false, error: null };
	}

	static getDerivedStateFromError(error: Error): State {
		return { hasError: true, error };
	}

	componentDidCatch(error: Error, errorInfo: ErrorInfo): void {
		this.props.onError?.(error, errorInfo);
	}

	render(): ReactNode {
		if (this.state.hasError && this.state.error) {
			if (this.props.fallback) {
				return this.props.fallback;
			}
			return (
				<div
					style={{
						padding: "40px",
						textAlign: "center",
						backgroundColor: "#0f0f23",
						minHeight: "100vh",
						color: "#fff",
						display: "flex",
						flexDirection: "column",
						alignItems: "center",
						justifyContent: "center",
					}}
				>
					<h2 style={{ margin: "0 0 16px 0" }}>Something went wrong</h2>
					<p style={{ margin: "0 0 24px 0", color: "#aaa" }}>
						{this.state.error instanceof Error
							? this.state.error.message
							: String(this.state.error)}
					</p>
					<div
						style={{ display: "flex", gap: "12px", justifyContent: "center" }}
					>
						{this.props.returnToLobby && (
							<button
								type="button"
								onClick={() => {
									useGameStore.getState().leaveRoom();
									this.setState({ hasError: false, error: null });
								}}
								style={{
									padding: "10px 20px",
									backgroundColor: "#dc3545",
									color: "#fff",
									border: "none",
									borderRadius: "4px",
									cursor: "pointer",
								}}
							>
								Return to Lobby
							</button>
						)}
						<button
							type="button"
							onClick={() => this.setState({ hasError: false, error: null })}
							style={{
								padding: "10px 20px",
								backgroundColor: "#007bff",
								color: "#fff",
								border: "none",
								borderRadius: "4px",
								cursor: "pointer",
							}}
						>
							Try again
						</button>
					</div>
				</div>
			);
		}
		return this.props.children;
	}
}
