import { spawnSync } from "node:child_process";

const platformCommand = process.env.E2E_PLATFORM_COMMAND?.trim();
if (platformCommand) {
  const platform = spawnSync(platformCommand, {
    cwd: process.cwd(),
    env: process.env,
    shell: true,
    stdio: "inherit",
  });
  if (platform.status === 0) {
    process.exit(0);
  }
  console.warn("Plataforma E2E indisponível; usando Playwright.");
}

const command = process.platform === "win32" ? "npx.cmd" : "npx";
const fallback = spawnSync(command, ["playwright", "test"], {
  cwd: process.cwd(),
  env: process.env,
  stdio: "inherit",
});
process.exit(fallback.status ?? 1);
