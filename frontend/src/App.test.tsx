import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import { App } from "./App.js";

describe("App", () => {
  it("renders the heading", () => {
    render(<App />);
    expect(screen.getByRole("heading", { level: 1 })).toHaveTextContent(
      "STR Platform"
    );
  });

  it("displays the app name from shared constants", () => {
    render(<App />);
    expect(screen.getByText(/str-platform/i)).toBeDefined();
  });
});
