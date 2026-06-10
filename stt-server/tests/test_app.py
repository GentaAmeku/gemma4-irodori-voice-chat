from __future__ import annotations

from fastapi.testclient import TestClient

from app.config import SttConfig
from app.main import MOCK_TRANSCRIPT, create_app


def test_health_reports_mock_mode() -> None:
    app = create_app(SttConfig(mock=True))
    with TestClient(app) as client:
        response = client.get("/health")

    assert response.status_code == 200
    body = response.json()
    assert body["ok"] is True
    assert body["mock"] is True


def test_transcription_returns_text_in_mock_mode() -> None:
    app = create_app(SttConfig(mock=True))
    with TestClient(app) as client:
        response = client.post(
            "/v1/audio/transcriptions",
            files={"file": ("speech.wav", b"RIFF", "audio/wav")},
            data={"model": "whisper-1", "language": "ja"},
        )

    assert response.status_code == 200
    assert response.json() == {"text": MOCK_TRANSCRIPT}


def test_transcription_rejects_empty_audio() -> None:
    app = create_app(SttConfig(mock=True))
    with TestClient(app) as client:
        response = client.post(
            "/v1/audio/transcriptions",
            files={"file": ("speech.wav", b"", "audio/wav")},
        )

    assert response.status_code == 400
    assert response.json()["detail"] == "empty_audio"
