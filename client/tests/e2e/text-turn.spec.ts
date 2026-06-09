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

  await page.getByLabel("テキスト入力").fill("クライアントE2Eの確認です");
  await page.getByRole("button", { name: "送信" }).click();

  await expect(page.getByText("クライアントE2Eの確認です", { exact: true })).toBeVisible();
  await expect(page.getByText("リノンです。『クライアントE2Eの確認です』について、まずは短く返すね。")).toBeVisible();
  await expect(page.getByLabel("最後の読み上げ").locator("audio")).toHaveAttribute("src", /\/media\/audio\/.+\.wav$/);
  await expect(page.locator(".assistant-bubble audio")).toHaveAttribute("src", /\/media\/audio\/.+\.wav$/);
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
