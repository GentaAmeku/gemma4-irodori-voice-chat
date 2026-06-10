from __future__ import annotations

from contextlib import asynccontextmanager
from pathlib import Path
import tempfile

from fastapi import FastAPI, File, Form, HTTPException, UploadFile

from .config import SttConfig, load_config


MOCK_TRANSCRIPT = "音声入力のモック文字起こしです。"


def create_app(config: SttConfig | None = None) -> FastAPI:
    cfg = config or load_config()

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        app.state.config = cfg
        app.state.model = None
        if not cfg.mock:
            # faster-whisper は任意依存。実STT時のみ読み込む(mock/テストでは不要)。
            from faster_whisper import WhisperModel

            app.state.model = WhisperModel(
                cfg.model,
                device=cfg.device,
                compute_type=cfg.compute_type,
            )
        yield

    app = FastAPI(title="Gemma4 Irodori STT Server", lifespan=lifespan)

    @app.get("/health")
    async def health() -> dict[str, object]:
        return {"ok": True, "model": cfg.model, "mock": cfg.mock}

    # OpenAI互換風の文字起こしエンドポイント。会話サーバーがプロキシする。
    @app.post("/v1/audio/transcriptions")
    async def transcriptions(
        file: UploadFile = File(...),
        model: str = Form(default=""),
        language: str = Form(default=""),
        response_format: str = Form(default="json"),
    ) -> dict[str, str]:
        content = await file.read()
        if not content:
            raise HTTPException(status_code=400, detail="empty_audio")

        if cfg.mock:
            return {"text": MOCK_TRANSCRIPT}

        whisper_model = app.state.model
        if whisper_model is None:  # pragma: no cover - lifespanで読み込み済みのはず
            raise HTTPException(status_code=503, detail="model_not_loaded")

        lang = language.strip() or cfg.language or None
        suffix = Path(file.filename or "audio").suffix or ".bin"
        with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
            tmp.write(content)
            tmp_path = Path(tmp.name)
        try:
            segments, _info = whisper_model.transcribe(
                str(tmp_path),
                language=lang,
                beam_size=cfg.beam_size,
            )
            text = "".join(segment.text for segment in segments).strip()
        finally:
            tmp_path.unlink(missing_ok=True)
        return {"text": text}

    return app


app = create_app()
