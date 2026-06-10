from __future__ import annotations

from contextlib import asynccontextmanager
from pathlib import Path
import re
import shutil
import tempfile

from fastapi import FastAPI, File, HTTPException, Query, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
import httpx

from .adapters import IrodoriTtsClient, OllamaClient
from .config import AppConfig, load_config
from .models import AppSettings, HealthResponse, HistoryResponse, SpeakerOption, TextTurnRequest
from .service import ConversationBusyError, ConversationService, TurnFailedError
from .storage import ConversationHistory, SettingsStore


VOICE_ID_PATTERN = re.compile(r"^[A-Za-z0-9_-]+$")
ALLOWED_VOICE_SUFFIXES = {".wav", ".flac", ".mp3", ".m4a", ".ogg", ".opus", ".aac", ".webm"}
MAX_REFERENCE_VOICE_BYTES = 50 * 1024 * 1024

# 会話ターン失敗コード -> HTTPステータス。timeout は 504、依存先不通・空応答は 502。
TURN_ERROR_STATUS = {
    "llm_timeout": 504,
    "tts_timeout": 504,
    "llm_unavailable": 502,
    "tts_unavailable": 502,
    "llm_empty": 502,
}


def create_app(config: AppConfig | None = None) -> FastAPI:
    app_config = config or load_config()
    app_config.data_dir.mkdir(parents=True, exist_ok=True)
    app_config.audio_dir.mkdir(parents=True, exist_ok=True)

    @asynccontextmanager
    async def lifespan(app: FastAPI):
        timeout = httpx.Timeout(app_config.request_timeout_seconds)
        async with httpx.AsyncClient(timeout=timeout) as client:
            settings_store = SettingsStore(app_config.data_dir)
            history = ConversationHistory()
            ollama = OllamaClient(app_config, client)
            tts = IrodoriTtsClient(app_config, client)
            app.state.config = app_config
            app.state.settings_store = settings_store
            app.state.history = history
            app.state.ollama = ollama
            app.state.tts = tts
            app.state.conversation_service = ConversationService(settings_store, history, ollama, tts)
            yield

    app = FastAPI(title="Gemma4 Irodori Chat Server", lifespan=lifespan)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
    )
    app.mount("/media/audio", StaticFiles(directory=app_config.audio_dir), name="audio")

    @app.get("/api/health", response_model=HealthResponse)
    async def health() -> HealthResponse:
        ollama_status = await app.state.ollama.health()
        tts_status = await app.state.tts.health()
        ready = ollama_status.ok and tts_status.ok
        return HealthResponse(
            server_ok=True,
            ready=ready,
            model=app.state.config.ollama_model,
            ollama_base_url=app.state.config.ollama_base_url,
            tts_base_url=app.state.config.tts_base_url,
            mock_services=app.state.config.mock_services,
            ollama=ollama_status,
            tts=tts_status,
        )

    @app.get("/api/settings", response_model=AppSettings)
    async def get_settings() -> AppSettings:
        return app.state.settings_store.load()

    @app.put("/api/settings", response_model=AppSettings)
    async def put_settings(settings: AppSettings) -> AppSettings:
        return app.state.conversation_service.save_settings(settings)

    @app.get("/api/speakers", response_model=list[SpeakerOption])
    async def speakers() -> list[SpeakerOption]:
        return await app.state.tts.speakers()

    @app.post("/api/speakers/{speaker_id}", response_model=list[SpeakerOption])
    async def register_speaker(
        speaker_id: str,
        file: UploadFile = File(...),
        replace: bool = Query(default=False),
    ) -> list[SpeakerOption]:
        if not VOICE_ID_PATTERN.fullmatch(speaker_id):
            raise HTTPException(status_code=400, detail="invalid_speaker_id")

        filename = Path(file.filename or "").name
        suffix = Path(filename).suffix.lower()
        if suffix not in ALLOWED_VOICE_SUFFIXES:
            raise HTTPException(status_code=400, detail="unsupported_voice_type")

        content = await file.read(MAX_REFERENCE_VOICE_BYTES + 1)
        if len(content) > MAX_REFERENCE_VOICE_BYTES:
            raise HTTPException(status_code=413, detail="voice_file_too_large")
        if not content:
            raise HTTPException(status_code=400, detail="empty_voice_file")

        try:
            return await app.state.tts.register_voice(
                speaker_id,
                filename,
                content,
                file.content_type or "application/octet-stream",
                replace,
            )
        except httpx.HTTPStatusError as exc:
            status_code = 409 if exc.response.status_code == 409 else 502
            raise HTTPException(status_code=status_code, detail="irodori_voice_registration_failed") from exc

    @app.get("/api/history", response_model=HistoryResponse)
    async def get_history() -> HistoryResponse:
        return HistoryResponse(turns=app.state.history.all())

    @app.delete("/api/history", response_model=HistoryResponse)
    async def clear_history() -> HistoryResponse:
        app.state.history.clear()
        return HistoryResponse(turns=[])

    @app.post("/api/turns/text")
    async def text_turn(request: TextTurnRequest):
        try:
            return await app.state.conversation_service.text_turn(request.text.strip())
        except ConversationBusyError as exc:
            raise HTTPException(status_code=409, detail=str(exc)) from exc
        except TurnFailedError as exc:
            raise HTTPException(status_code=TURN_ERROR_STATUS.get(exc.code, 502), detail=exc.code) from exc

    @app.get("/api/character-image")
    async def get_character_image():
        image = app.state.settings_store.find_character_image()
        if not image:
            raise HTTPException(status_code=404, detail="character_image_not_found")
        return FileResponse(image)

    @app.post("/api/character-image")
    async def upload_character_image(file: UploadFile = File(...)):
        allowed = {
            "image/png": ".png",
            "image/jpeg": ".jpg",
            "image/webp": ".webp",
            "image/svg+xml": ".svg",
        }
        suffix = allowed.get(file.content_type or "")
        if not suffix:
            raise HTTPException(status_code=400, detail="unsupported_image_type")

        with tempfile.NamedTemporaryFile(delete=False) as temp:
            temp_path = Path(temp.name)
            shutil.copyfileobj(file.file, temp)
        try:
            saved = app.state.settings_store.save_character_image(temp_path, suffix)
        finally:
            temp_path.unlink(missing_ok=True)
        return {"image_url": "/api/character-image", "filename": saved.name}

    return app


app = create_app()
