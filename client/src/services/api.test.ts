import { describe, expect, it } from "vitest";
import { api } from "./api";

describe("ApiClient.isNetworkError", () => {
	it("returns true for object with isNetworkError: true", () => {
		expect(api.isNetworkError({ isNetworkError: true, message: "x" })).toBe(
			true,
		);
	});

	it("returns false for Error instance", () => {
		expect(api.isNetworkError(new Error("network"))).toBe(false);
	});

	it("returns false for object with isNetworkError: false", () => {
		expect(api.isNetworkError({ isNetworkError: false, message: "x" })).toBe(
			false,
		);
	});

	it("returns false for null or primitive", () => {
		expect(api.isNetworkError(null)).toBe(false);
		expect(api.isNetworkError("error")).toBe(false);
	});
});
