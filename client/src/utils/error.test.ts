import { describe, expect, it } from "vitest";
import { getErrorMessage } from "./error";

describe("getErrorMessage", () => {
	it("returns message for Error instance", () => {
		expect(getErrorMessage(new Error("foo"))).toBe("foo");
	});

	it("returns fallback when Error has empty message", () => {
		expect(getErrorMessage(new Error(""), "default")).toBe("default");
	});

	it("returns message from object with message property", () => {
		expect(getErrorMessage({ message: "api error" })).toBe("api error");
		expect(getErrorMessage({ message: "api error" }, "default")).toBe(
			"api error",
		);
	});

	it("returns fallback for object without string message", () => {
		expect(getErrorMessage({ code: 500 }, "default")).toBe("default");
		expect(getErrorMessage({ message: 123 }, "default")).toBe("default");
	});

	it("returns fallback for primitive", () => {
		expect(getErrorMessage("oops", "default")).toBe("default");
		expect(getErrorMessage(null, "default")).toBe("default");
		expect(getErrorMessage(undefined, "default")).toBe("default");
	});

	it("uses default fallback when not provided", () => {
		expect(getErrorMessage(null)).toBe("An error occurred");
	});
});
