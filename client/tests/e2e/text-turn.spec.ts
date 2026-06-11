import { expect, test } from "@playwright/test";

const DEFAULT_SETTINGS = {
  preset_id: "rena",
  character_name: "黒瀬 怜奈",
  character_prompt:
    "あなたは黒瀬 怜奈。利用者より少し年上の、黒髪ロングで落ち着いた雰囲気の女性。" +
    "感情を大きく表に出さず、静かに相手を観察して、必要なことを短く整理して伝える。" +
    "冷たく見えることはあるが、突き放す人ではない。" +
    "利用者が疲れている、迷っている、失敗したと感じているときは、まず一文で受け止めてから、次にできる小さな一手を示す。" +
    "口調は自然な日本語。丁寧さを残しつつ、少しだけくだけた先輩らしい話し方にする。" +
    "語尾は落ち着かせ、「〜だと思う」「〜しておくといい」「無理しなくていい」などを使う。" +
    "過剰に明るくしない。説教、上から目線、依存的な甘さ、露骨な色気、テンションの高い励ましは避ける。" +
    "返答は原則1〜3文。必要なときだけ、短く核心を突く。",
  read_aloud_prompt:
    "Native Japanese mature young woman, cool composed voice, low-to-mid pitch, calm and slightly slow pacing, clear pronunciation, subtle warmth, elegant senpai tone, restrained emotion.",
  speaker_id: "none",
  speech_speed: 0.95,
  tone_preset: "senpai",
  distance: 58,
};

test.beforeEach(async ({ page }) => {
  await page.request.delete("http://127.0.0.1:8000/api/history");
  await page.request.put("http://127.0.0.1:8000/api/settings", {
    data: DEFAULT_SETTINGS,
  });
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

  await expect(page.locator("#character-title")).toHaveText("黒瀬 怜奈");
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
  await expect(
    page.getByText("黒瀬 怜奈です。『クライアントE2Eの確認です』について、まずは短く返すね。"),
  ).toBeVisible();
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
  await expect(page.getByText("黒瀬 怜奈が返答生成中…")).toBeVisible();

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

test("shows a cause-specific message when a text turn fails", async ({ page }) => {
  await page.route("http://127.0.0.1:8000/api/turns/text", async (route) => {
    await route.fulfill({
      status: 502,
      contentType: "application/json",
      body: JSON.stringify({ detail: "llm_unavailable" }),
    });
  });

  await page.goto("/");
  await page.getByLabel("テキスト入力").fill("失敗するはずの発話です");
  await page.getByRole("button", { name: "送信" }).click();

  await expect(page.getByText("失敗するはずの発話です", { exact: true })).toBeVisible();
  await expect(page.locator(".bubble.error")).toContainText("AI（Ollama）に接続できませんでした");
});

test("does not autoplay audio when autoplay is disabled", async ({ page }) => {
  await page.goto("/");

  await page.getByRole("button", { name: "設定", exact: true }).click();
  await page.getByRole("switch", { name: "自動で読み上げ" }).click();
  await page.getByRole("button", { name: "設定を閉じる" }).click();

  await page.getByLabel("テキスト入力").fill("自動再生オフの確認です");
  await page.getByRole("button", { name: "送信" }).click();

  await expect(page.getByText("黒瀬 怜奈です。『自動再生オフの確認です』について、まずは短く返すね。")).toBeVisible();
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

test("switches the character preset and clears conversation history", async ({ page }) => {
  await page.goto("/");

  await page.getByLabel("テキスト入力").fill("プリセット切替前の発話です");
  await page.getByRole("button", { name: "送信" }).click();
  await expect(page.getByText("プリセット切替前の発話です", { exact: true })).toBeVisible();

  await page.getByRole("button", { name: "設定", exact: true }).click();
  await page.getByLabel("プリセット", { exact: true }).selectOption("koharu");
  // プリセット選択で下の設定項目がまとめて切り替わる
  await expect(page.getByLabel("キャラクター名")).toHaveValue("春野 心晴");
  await expect(page.locator(".chip.on")).toHaveText("フレンドリー");
  await page.getByRole("button", { name: "設定を閉じる" }).click();

  await expect(page.getByText("設定を保存しました")).toBeVisible();
  await expect(page.getByText("まだ会話はありません。")).toBeVisible();
  await expect(page.locator("#character-title")).toHaveText("春野 心晴");

  const settingsResponse = await page.request.get("http://127.0.0.1:8000/api/settings");
  await expect(settingsResponse).toBeOK();
  expect((await settingsResponse.json()) as { preset_id: string; speaker_id: string }).toMatchObject({
    preset_id: "koharu",
    speaker_id: "koharu",
  });

  // キャラクター名を編集するとセレクトボックスは「カスタム」表示になる
  await page.getByRole("button", { name: "設定", exact: true }).click();
  await page.getByLabel("キャラクター名").fill("心晴ちゃん");
  await expect(page.getByLabel("プリセット", { exact: true })).toHaveValue("custom");
  await page.getByRole("button", { name: "設定を閉じる" }).click();
  await expect(page.locator("#character-title")).toHaveText("心晴ちゃん");
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
  await page.getByRole("button", { name: "フレンドリー" }).click();
  await page.getByLabel("距離感").fill("75");
  await expect(page.locator(".slider-row").filter({ hasText: "距離感" }).locator(".v")).toHaveText("親しい");
  // パネル操作中は、背景のキャラクター表示(キャラクターレール)へ反映しない
  await expect(page.locator(".persona-line")).not.toContainText(
    "リノンは若い女性の会話相手として、やわらかく短く返す。",
  );
  await expect(page.locator(".persona-line")).not.toContainText("口調: フレンドリー / 距離感: 親しい");
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
