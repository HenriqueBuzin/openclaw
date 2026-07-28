import { expect, test } from "@playwright/test";

test("gateway responde e entrega uma interface HTTP", async ({ request }) => {
  const response = await request.get("/healthz");
  expect(response.ok()).toBeTruthy();
});
