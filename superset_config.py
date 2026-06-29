import logging
import os

from celery.schedules import crontab
from cachelib.redis import RedisCache

from bx_app_initializer import BxAppInitializer
from bx_custom_security_manager import BxCustomSecurityManager

logger = logging.getLogger()

# ───────────────────────────────────────────────────────────────────
# Core
# ───────────────────────────────────────────────────────────────────
APP_INITIALIZER = BxAppInitializer
CUSTOM_SECURITY_MANAGER = BxCustomSecurityManager

SECRET_KEY = os.getenv("SUPERSET_SECRET_KEY", "CHANGE_ME_TO_A_COMPLEX_RANDOM_SECRET")

# ───────────────────────────────────────────────────────────────────
# Database
# ───────────────────────────────────────────────────────────────────
DATABASE_DIALECT = os.getenv("DATABASE_DIALECT", "mysql+pymysql")
DATABASE_USER = os.getenv("DATABASE_USER", "superset")
DATABASE_PASSWORD = os.getenv("DATABASE_PASSWORD", "superset")
DATABASE_HOST = os.getenv("DATABASE_HOST", "mysql")
DATABASE_PORT = os.getenv("DATABASE_PORT", "3306")
DATABASE_DB = os.getenv("DATABASE_DB", "superset")

SQLALCHEMY_DATABASE_URI = (
    f"{DATABASE_DIALECT}://"
    f"{DATABASE_USER}:{DATABASE_PASSWORD}@"
    f"{DATABASE_HOST}:{DATABASE_PORT}/{DATABASE_DB}"
)

# ───────────────────────────────────────────────────────────────────
# Redis
# ───────────────────────────────────────────────────────────────────
REDIS_HOST = os.getenv("REDIS_HOST", "redis")
REDIS_PORT = os.getenv("REDIS_PORT", "6379")
REDIS_DB = os.getenv("REDIS_DB", "0")

RESULTS_BACKEND = RedisCache(
    host=REDIS_HOST, port=int(REDIS_PORT), key_prefix="superset_results", db=int(REDIS_DB)
)

CACHE_CONFIG = {
    "CACHE_TYPE": "RedisCache",
    "CACHE_KEY_PREFIX": "superset_cache",
    "CACHE_DEFAULT_TIMEOUT": 3600,
    "CACHE_REDIS_DB": REDIS_DB,
    "CACHE_REDIS_HOST": REDIS_HOST,
    "CACHE_REDIS_PORT": REDIS_PORT,
}
FILTER_STATE_CACHE_CONFIG = {
    "CACHE_TYPE": "RedisCache",
    "CACHE_KEY_PREFIX": "superset_filter_state",
    "CACHE_DEFAULT_TIMEOUT": 86400,
    "CACHE_REDIS_DB": REDIS_DB,
    "CACHE_REDIS_HOST": REDIS_HOST,
    "CACHE_REDIS_PORT": REDIS_PORT,
}
EXPLORE_FORM_DATA_CACHE_CONFIG = {
    "CACHE_TYPE": "RedisCache",
    "CACHE_KEY_PREFIX": "superset_explore_form_data",
    "CACHE_DEFAULT_TIMEOUT": 86400,
    "CACHE_REDIS_DB": REDIS_DB,
    "CACHE_REDIS_HOST": REDIS_HOST,
    "CACHE_REDIS_PORT": REDIS_PORT,
}
DATA_CACHE_CONFIG = {
    "CACHE_TYPE": "RedisCache",
    "CACHE_KEY_PREFIX": "superset_data",
    "CACHE_DEFAULT_TIMEOUT": 3600,
    "CACHE_REDIS_DB": REDIS_DB,
    "CACHE_REDIS_HOST": REDIS_HOST,
    "CACHE_REDIS_PORT": REDIS_PORT,
}

# ───────────────────────────────────────────────────────────────────
# Celery
# ───────────────────────────────────────────────────────────────────
class CeleryConfig:
    broker_url = f"redis://{REDIS_HOST}:{REDIS_PORT}/{REDIS_DB}"
    imports = (
        "superset.sql_lab",
        "superset.tasks.scheduler",
        "superset.tasks.thumbnails",
        "superset.tasks.cache",
    )
    result_backend = f"redis://{REDIS_HOST}:{REDIS_PORT}/{REDIS_DB}"
    worker_prefetch_multiplier = 1
    task_acks_late = False
    task_annotations = {
        "sql_lab.get_sql_results": {
            "rate_limit": "100/s",
        }
    }
    beat_schedule = {
        "reports.scheduler": {
            "task": "reports.scheduler",
            "schedule": crontab(minute="*", hour="*"),
        },
        "reports.prune_log": {
            "task": "reports.prune_log",
            "schedule": crontab(minute=10, hour=0),
        },
    }


CELERY_CONFIG = CeleryConfig

# ───────────────────────────────────────────────────────────────────
# HTTP / Security
# ───────────────────────────────────────────────────────────────────
HTTP_HEADERS = {"X-Frame-Options": "ALLOWALL"}
ENABLE_PROXY_FIX = True
TALISMAN_ENABLED = False

REMEMBER_COOKIE_DURATION = 86400
REMEMBER_COOKIE_SAMESITE = "Lax"

GUEST_TOKEN_JWT_EXP_SECONDS = 8640000000
GUEST_ROLE_NAME = "Gamma"
GUEST_TOKEN_JWT_SECRET = os.getenv("SUPERSET_SECRET_KEY", "CHANGE_ME_TO_A_COMPLEX_RANDOM_SECRET")
JWT_ACCESS_TOKEN_EXPIRES = 86400

# ───────────────────────────────────────────────────────────────────
# Feature flags
# ───────────────────────────────────────────────────────────────────
FEATURE_FLAGS = {
    "ENABLE_TEMPLATE_PROCESSING": True,
    "EMBEDDED_SUPERSET": True,
    "FAB_API_SWAGGER_UI": True,
    "HORIZONTAL_FILTER_BAR": False,
    "DASHBOARD_VIRTUALIZATION": False,
    "BX_CLEAR_CACHE_ENDPOINT": True,
}

# ───────────────────────────────────────────────────────────────────
# Branding / i18n
# ───────────────────────────────────────────────────────────────────
APP_NAME = os.getenv("APP_NAME", "BI Конструктор")
APP_ICON = "/static/assets/images/bi-constructor-logo.svg"
FAVICONS = [{"href": "/static/assets/images/bi-favicon.png"}]

BABEL_DEFAULT_LOCALE = os.getenv("BABEL_DEFAULT_LOCALE", "ru")
LANGUAGES = {
    "ru": {"flag": "ru", "name": "Русский"},
    "en": {"flag": "gb", "name": "English"},
}

CURRENCIES = ["RUB", "KZT", "USD", "EUR", "GBP", "JPY", "CNY", "INR", "MXN"]

# ───────────────────────────────────────────────────────────────────
# Logging
# ───────────────────────────────────────────────────────────────────
log_level_text = os.getenv("SUPERSET_LOG_LEVEL", "INFO")
LOG_LEVEL = getattr(logging, log_level_text.upper(), logging.INFO)

# ───────────────────────────────────────────────────────────────────
# Jinja context (portal_url helper)
# ───────────────────────────────────────────────────────────────────
def get_portal_name() -> str:
    from superset import db
    from superset.models import core
    from urllib import parse
    import json

    database = (
        db.session.query(core.Database).filter_by(database_name="trino").first()
    )
    if not database:
        return ""

    db_uri = parse.unquote(database.sqlalchemy_uri_decrypted)
    session_properties = parse.parse_qs(db_uri).get("session_properties", [""])[0]
    if not session_properties:
        return ""
    properties = json.loads(session_properties)
    portal_name = properties.get("bi.server_url", "")
    return portal_name


JINJA_CONTEXT_ADDONS = {
    "portal_url": get_portal_name,
}

FAB_ADD_SECURITY_API = True

import urllib3
urllib3.disable_warnings()
