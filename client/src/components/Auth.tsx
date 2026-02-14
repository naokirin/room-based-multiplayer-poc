import { useState } from "react";
import { useAuthStore } from "../stores/authStore";

export function Auth() {
	const [mode, setMode] = useState<"login" | "register">("login");
	const [email, setEmail] = useState("");
	const [password, setPassword] = useState("");
	const [displayName, setDisplayName] = useState("");

	const { login, register, isLoading, error } = useAuthStore();

	const handleSubmit = async (e: React.FormEvent) => {
		e.preventDefault();

		try {
			if (mode === "login") {
				await login(email, password);
			} else {
				await register(email, password, displayName);
			}
			// Success - parent App component will handle navigation
		} catch (err) {
			// Error is already set in store
			console.error("Auth error:", err);
		}
	};

	const toggleMode = () => {
		setMode(mode === "login" ? "register" : "login");
		setEmail("");
		setPassword("");
		setDisplayName("");
	};

	return (
		<div
			style={{
				maxWidth: "400px",
				margin: "100px auto",
				padding: "30px",
				border: "1px solid #ccc",
				borderRadius: "8px",
				backgroundColor: "#fff",
			}}
		>
			<h2 style={{ textAlign: "center", marginBottom: "20px" }}>
				{mode === "login" ? "Login" : "Register"}
			</h2>

			<form onSubmit={handleSubmit}>
				<div style={{ marginBottom: "15px" }}>
					<label
						htmlFor="email"
						style={{ display: "block", marginBottom: "5px" }}
					>
						Email
					</label>
					<input
						id="email"
						type="email"
						value={email}
						onChange={(e) => setEmail(e.target.value)}
						required
						style={{
							width: "100%",
							padding: "8px",
							fontSize: "14px",
							borderRadius: "4px",
							border: "1px solid #ccc",
						}}
					/>
				</div>

				<div style={{ marginBottom: "15px" }}>
					<label
						htmlFor="password"
						style={{ display: "block", marginBottom: "5px" }}
					>
						Password
					</label>
					<input
						id="password"
						type="password"
						value={password}
						onChange={(e) => setPassword(e.target.value)}
						required
						style={{
							width: "100%",
							padding: "8px",
							fontSize: "14px",
							borderRadius: "4px",
							border: "1px solid #ccc",
						}}
					/>
				</div>

				{mode === "register" && (
					<div style={{ marginBottom: "15px" }}>
						<label
							htmlFor="displayName"
							style={{ display: "block", marginBottom: "5px" }}
						>
							Display Name
						</label>
						<input
							id="displayName"
							type="text"
							value={displayName}
							onChange={(e) => setDisplayName(e.target.value)}
							required
							style={{
								width: "100%",
								padding: "8px",
								fontSize: "14px",
								borderRadius: "4px",
								border: "1px solid #ccc",
							}}
						/>
					</div>
				)}

				{error && (
					<div
						style={{
							padding: "10px",
							marginBottom: "15px",
							backgroundColor: "#fee",
							color: "#c00",
							borderRadius: "4px",
							fontSize: "14px",
						}}
					>
						{error}
					</div>
				)}

				<button
					type="submit"
					disabled={isLoading}
					style={{
						width: "100%",
						padding: "10px",
						fontSize: "16px",
						backgroundColor: isLoading ? "#ccc" : "#007bff",
						color: "#fff",
						border: "none",
						borderRadius: "4px",
						cursor: isLoading ? "not-allowed" : "pointer",
					}}
				>
					{isLoading ? "Loading..." : mode === "login" ? "Login" : "Register"}
				</button>
			</form>

			<div style={{ marginTop: "15px", textAlign: "center" }}>
				<button
					type="button"
					onClick={toggleMode}
					disabled={isLoading}
					style={{
						background: "none",
						border: "none",
						color: "#007bff",
						textDecoration: "underline",
						cursor: isLoading ? "not-allowed" : "pointer",
					}}
				>
					{mode === "login"
						? "Need an account? Register"
						: "Have an account? Login"}
				</button>
			</div>
		</div>
	);
}
