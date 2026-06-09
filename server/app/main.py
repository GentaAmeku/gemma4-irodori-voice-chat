from __future__ import annotations

from contextlib import asynccontextmanager
from pathlib import Path
import shutil
import tempfile

from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
import httpx

from .adapters import IrodoriTtsClient, OllamaClient
from .config import AppConfig, load_config
from .models import AppSettings, HealthResponse, HistoryResponse, SpeakerOption, TextTurnRequest
from .service import ConversationBusyError, ConversationService
from .storage import ConversationHistory, SettingsStore


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
