import os
from dotenv import load_dotenv
from fastapi import FastAPI
from titiler.application.main import app as titiler_app
import sentry_sdk
from sentry_sdk.integrations.fastapi import FastApiIntegration
from sentry_sdk.integrations.starlette import StarletteIntegration

# Load environment variables from .env
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), ".env"))

# Initialize Sentry
sentry_dsn = os.getenv("SENTRY_DSN")
if sentry_dsn:
    sentry_sdk.init(
        dsn=sentry_dsn,
        integrations=[
            FastApiIntegration(auto_enabling_instrumentations=False),
            StarletteIntegration(auto_enabling_instrumentations=False),
        ],
        traces_sample_rate=0.1,  # Capture 10% of transactions for performance monitoring
        environment=os.getenv("ENVIRONMENT", "production"),
    )

# Disable docs/redoc for production
app = FastAPI(
    title="Turfscore TiTiler",
    openapi_url=None,
    docs_url=None,
    redoc_url=None,
)

# Mount TiTiler's built-in routes
app.mount("", titiler_app)

@app.get("/")
def root():
    return {"name": "Turfscore TiTiler", "status": "ok"}
