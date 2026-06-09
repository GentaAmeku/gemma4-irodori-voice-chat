import { expect, test } from "@playwright/test";

test.beforeEach(async ({ page }) => {
  await page.request.delete("http://127.0.0.1:8000/api/history");
  await page.addInitScript(() => {
    Object.defineProperty(window.HTMLMediaElement.prototype, "play", {
      configurable: true,
      value() {
        return Promise.resolve();
      },
    });
  });
});

test("connects to the mock conversation server and completes a text turn", async ({ page }) => {
  await page.goto("/");

  await expect(page.locator("#character-title")).toHaveText("リノン");
  await expect(page.getByText("gemma4:12b / mock")).toBeVisible();
  await expect(page.getByText("接続しました")).toBeVisible();
  await expect(page.locator(".status-tile").filter({ hasText: "会話サーバー" }).getByText("接続済み")).toBeVisible();
  await expect(page.locator(".status-tile").filter({ hasText: "Ollama" }).getByText("接続済み")).toBeVisible();
  await expect(page.locator(".status-tile").filter({ hasText: "irodori-TTS" }).getByText("接続済み")).toBeVisible();

  await page.getByLabel("テキスト入力").fill("クライアントE2Eの確認です");
  await page.getByRole("button", { name: "送信" }).click();

  await expect(page.getByText("クライアントE2Eの確認です", { exact: true })).toBeVisible();
  await expect(page.getByText("リノンです。『クライアントE2Eの確認です』について、まずは短く返すね。")).toBeVisible();
  await expect(page.getByLabel("最後の読み上げ").locator("audio")).toHaveAttribute("src", /\/media\/audio\/.+\.wav$/);
  await expect(page.locator(".assistant-bubble audio")).toHaveAttribute("src", /\/media\/audio\/.+\.wav$/);
});

test("shows the user message while waiting for the assistant response", async ({ page }) => {
  let releaseResponse!: () => void;
  const responseReady = new Promise<void>((resolve) => {
    releaseResponse = resolve;
  });

  await page.route("http://127.0.0.1:8000/api/turns/text", async (route) => {
    await responseReady;
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({
        user_text: "今日も疲れたね",
        assistant_text: "今日もおつかれさま。少しだけ休もうね。",
        audio_url: "/media/audio/pending-test.wav",
      }),
    });
  });

  await page.goto("/");
  await page.getByLabel("テキスト入力").fill("今日も疲れたね");
  await page.getByRole("button", { name: "送信" }).click();

  await expect(page.getByText("今日も疲れたね", { exact: true })).toBeVisible();
  await expect(page.getByText("リノンが返答中...")).toBeVisible();

  releaseResponse();
  await expect(page.getByText("今日もおつかれさま。少しだけ休もうね。")).toBeVisible();
});

test("saves settings and clears conversation history", async ({ page }) => {
  await page.goto("/");

  await page.getByLabel("テキスト入力").fill("履歴クリア前の発話です");
  await page.getByRole("button", { name: "送信" }).click();
  await expect(page.getByText("履歴クリア前の発話です", { exact: true })).toBeVisible();

  await page.getByRole("button", { name: "Options" }).click();
  await page.getByLabel("キャラクター名").fill("リノン");
  await page.getByRole("button", { name: "保存" }).click();

  await expect(page.getByText("設定を保存しました")).toBeVisible();
  await expect(page.getByText("まだ会話はありません。")).toBeVisible();

  await page.getByLabel("テキスト入力").fill("もう一度話します");
  await page.getByRole("button", { name: "送信" }).click();
  await expect(page.getByText("もう一度話します", { exact: true })).toBeVisible();

  await page.getByRole("button", { name: "履歴クリア" }).click();
  await expect(page.getByText("履歴をクリアしました")).toBeVisible();
  await expect(page.getByText("まだ会話はありません。")).toBeVisible();
});
