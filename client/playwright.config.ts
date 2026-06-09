import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./tests/e2e",
  timeout: 30_000,
  expect: {
    timeout: 8_000,
  },
  use: {
    baseURL: "http://127.0.0.1:5173",
    trace: "retain-on-failure",
  },
  webServer: [
    {
      command: "GIC_MOCK_SERVICES=1 uv run uvicorn app.main:app --host 127.0.0.1 --port 8000",
      cwd: "../server",
      url: "http://127.0.0.1:8000/api/health",
      reuseExistingServer: true,
      timeout: 20_000,
    },
    {
      command: "VITE_GIC_DEFAULT_BASE_URL=http://127.0.0.1:8000 pnpm dev",
      url: "http://127.0.0.1:5173",
      reuseExistingServer: true,
      timeout: 20_000,
    },
  ],
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
});
