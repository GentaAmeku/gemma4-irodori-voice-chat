import { expect, test } from "@playwright/test";

test.beforeEach(async ({ page }) => {
  await page.request.delete("http://127.0.0.1:8000/api/history");
  await page.addInitScript(() => {
    (window as Window & { __audioPlayCalls?: number }).__audioPlayCalls = 0;
    Object.defineProperty(window.HTMLMediaElement.prototype, "play", {
      configurable: true,
      value() {
        (window as Window & { __audioPlayCalls?: number }).__audioPlayCalls =
          ((window as Window & { __audioPlayCalls?: number }).__audioPlayCalls ?? 0) + 1;
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
  await expect(page.getByText("すべて接続済み")).toBeVisible();

  await page.getByRole("button", { name: "設定" }).click();
  await expect(page.getByRole("dialog", { name: "設定" })).toBeVisible();
  await expect(page.locator(".status-item").filter({ hasText: "会話サーバー" }).getByText("接続済み")).toBeVisible();
  await expect(page.locator(".status-item").filter({ hasText: "Ollama" }).getByText("接続済み")).toBeVisible();
  await expect(page.locator(".status-item").filter({ hasText: "irodori-TTS" }).getByText("接続済み")).toBeVisible();
  await page.getByRole("button", { name: "設定を閉じる" }).click();
  await expect(page.getByRole("dialog", { name: "設定" })).toBeHidden();

  await page.getByLabel("テキスト入力").fill("クライアントE2Eの確認です");
  await page.getByRole("button", { name: "送信" }).click();

  await expect(page.getByText("クライアントE2Eの確認です", { exact: true })).toBeVisible();
  await expect(page.getByText("リノンです。『クライアントE2Eの確認です』について、まずは短く返すね。")).toBeVisible();
  await expect(page.locator(".msg.assistant audio")).toHaveAttribute("src", /\/media\/audio\/.+\.wav$/);
  await expect(page.locator(".msg.assistant .audiochip")).toBeVisible();
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
  await expect(page.getByText("リノンが返答生成中…")).toBeVisible();

  releaseResponse();
  await expect(page.getByText("今日もおつかれさま。少しだけ休もうね。")).toBeVisible();
});

test("cancels a pending text turn without showing the late response", async ({ page }) => {
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
        user_text: "キャンセルする発話です",
        assistant_text: "この返答は表示されません。",
        audio_url: "/media/audio/cancelled-test.wav",
      }),
    });
  });

  await page.goto("/");
  await page.getByLabel("テキスト入力").fill("キャンセルする発話です");
  await page.getByRole("button", { name: "送信" }).click();

  await expect(page.getByText("キャンセルする発話です", { exact: true })).toBeVisible();
  await expect(page.getByRole("button", { name: "キャンセル" })).toBeVisible();

  await page.getByRole("button", { name: "キャンセル" }).click();
  await expect(page.getByText("キャンセルしました")).toBeVisible();
  await expect(page.getByText("キャンセルする発話です", { exact: true })).toBeHidden();
  await expect(page.getByLabel("テキスト入力")).toBeEnabled();

  releaseResponse();
  await expect(page.getByText("この返答は表示されません。")).toBeHidden();
});

test("shows a dependency-specific connection error", async ({ page }) => {
  await page.route("http://127.0.0.1:8000/api/health", async (route) => {
    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({
        server_ok: true,
        ready: false,
        model: "gemma4:12b",
        mock_services: true,
        ollama: { ok: false, detail: "connection refused" },
        tts: { ok: true, detail: null },
      }),
    });
  });

  await page.goto("/");

  await expect(page.getByText("Ollamaに接続できません: connection refused")).toBeVisible();
  await page.getByRole("button", { name: "設定", exact: true }).click();
  await expect(page.locator(".status-item").filter({ hasText: "Ollama" }).getByText("要確認")).toBeVisible();
});

test("does not autoplay audio when autoplay is disabled", async ({ page }) => {
  await page.goto("/");

  await page.getByRole("button", { name: "設定", exact: true }).click();
  await page.getByRole("switch", { name: "自動で読み上げ" }).click();
  await page.getByRole("button", { name: "設定を閉じる" }).click();

  await page.getByLabel("テキスト入力").fill("自動再生オフの確認です");
  await page.getByRole("button", { name: "送信" }).click();

  await expect(page.getByText("リノンです。『自動再生オフの確認です』について、まずは短く返すね。")).toBeVisible();
  await expect(page.locator(".msg.assistant .audiochip")).toBeVisible();
  await expect
    .poll(() => page.evaluate(() => (window as Window & { __audioPlayCalls?: number }).__audioPlayCalls ?? 0))
    .toBe(0);
});

test("closing the settings panel without changes keeps history and does not save", async ({ page }) => {
  await page.goto("/");

  await page.getByLabel("テキスト入力").fill("変更なしで閉じる前の発話です");
  await page.getByRole("button", { name: "送信" }).click();
  await expect(page.getByText("変更なしで閉じる前の発話です", { exact: true })).toBeVisible();

  await page.getByRole("button", { name: "設定", exact: true }).click();
  await page.getByRole("button", { name: "設定を閉じる" }).click();
  await expect(page.getByRole("dialog", { name: "設定" })).toBeHidden();

  await expect(page.getByText("設定を保存しました")).toBeHidden();
  await expect(page.getByText("変更なしで閉じる前の発話です", { exact: true })).toBeVisible();
});

test("saves settings when the panel closes and clears conversation history", async ({ page }) => {
  // 前回実行の保存値が残っていると差分なし(=保存されない)になるため、既知の状態へ戻す
  const reset = await page.request.put("http://127.0.0.1:8000/api/settings", {
    data: {
      character_name: "リノン",
      character_prompt: "あなたはリノン。短くやさしく返す。",
      read_aloud_prompt: "Native Japanese young adult woman, warm conversational voice.",
      speaker_id: "none",
      speech_speed: 1.0,
      tone_preset: "calm",
      distance: 40,
    },
  });
  expect(reset.ok()).toBeTruthy();

  await page.goto("/");

  await page.getByLabel("テキスト入力").fill("履歴クリア前の発話です");
  await page.getByRole("button", { name: "送信" }).click();
  await expect(page.getByText("履歴クリア前の発話です", { exact: true })).toBeVisible();

  await page.getByRole("button", { name: "設定", exact: true }).click();
  await page.getByLabel("キャラクター名").fill("リノン");
  await page.getByLabel("キャラクター設定").fill("リノンは若い女性の会話相手として、やわらかく短く返す。");
  await expect(page.locator(".persona-line")).toContainText("リノンは若い女性の会話相手として、やわらかく短く返す。");
  await page.getByRole("button", { name: "フレンドリー" }).click();
  await page.getByLabel("距離感").fill("75");
  await expect(page.locator(".slider-row").filter({ hasText: "距離感" }).locator(".v")).toHaveText("親しい");
  await expect(page.locator(".persona-line")).toContainText("口調: フレンドリー / 距離感: 親しい");
  await page.getByLabel("話す速さ").fill("1.15");
  await expect(page.getByText("1.15×")).toBeVisible();
  await page.getByRole("button", { name: "設定を閉じる" }).click();

  await expect(page.getByText("設定を保存しました")).toBeVisible();
  await expect(page.getByText("まだ会話はありません。")).toBeVisible();
  // 閉じたあともトップ画面(キャラクターレール)に変更後の設定が反映される
  await expect(page.locator(".persona-line")).toContainText("リノンは若い女性の会話相手として、やわらかく短く返す。");
  await expect(page.locator(".persona-line")).toContainText("口調: フレンドリー / 距離感: 親しい");
  const settingsResponse = await page.request.get("http://127.0.0.1:8000/api/settings");
  await expect(settingsResponse).toBeOK();
  expect(
    (await settingsResponse.json()) as { speech_speed: number; tone_preset: string; distance: number },
  ).toMatchObject({
    speech_speed: 1.15,
    tone_preset: "friendly",
    distance: 75,
  });

  await page.getByLabel("テキスト入力").fill("もう一度話します");
  await page.getByRole("button", { name: "送信" }).click();
  await expect(page.getByText("もう一度話します", { exact: true })).toBeVisible();

  await page.getByRole("button", { name: "設定", exact: true }).click();
  await page.getByRole("button", { name: "会話履歴をクリア" }).click();
  await expect(page.getByText("履歴をクリアしました")).toBeVisible();

  await page.getByRole("button", { name: "設定を閉じる" }).click();
  await expect(page.getByText("まだ会話はありません。")).toBeVisible();
});
