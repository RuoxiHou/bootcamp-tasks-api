import os
import json
import time

from fastapi import Depends, FastAPI, HTTPException, Request
from pydantic import BaseModel
from typing import Optional, List
from sqlalchemy.orm import Session

from prometheus_client import generate_latest
from starlette.responses import RedirectResponse, Response
from sqlalchemy import func

try:
    from .redis_client import redis_client
    from .database import Base, get_db, get_engine
    from .models import TaskDB
    from .metrics import (
        ACTIVE_TASKS_COUNT,
        HTTP_REQUESTS_TOTAL,
        HTTP_REQUEST_DURATION_SECONDS,
        TASKS_BY_STATUS,
        TASKS_CREATED_TOTAL,
        TASKS_TOTAL,
    )
except ImportError:
    # Allow running as module "main" inside the container image.
    from redis_client import redis_client
    from database import Base, get_db, get_engine
    from models import TaskDB
    from metrics import (
        ACTIVE_TASKS_COUNT,
        HTTP_REQUESTS_TOTAL,
        HTTP_REQUEST_DURATION_SECONDS,
        TASKS_BY_STATUS,
        TASKS_CREATED_TOTAL,
        TASKS_TOTAL,
    )

import logging

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
)

logger = logging.getLogger(__name__)

app = FastAPI(
    title="Tasks API",
    description="Bootcamp demo app — Week 1/2/8",
)


def refresh_task_metrics():
    if os.environ.get("TESTING") == "1":
        return

    try:
        engine = get_engine()
    except KeyError:
        return
    except Exception as exc:
        logger.warning("Failed to initialize database for task metrics: %s", exc)
        return

    session = None
    try:
        session = Session(bind=engine)

        total_tasks = session.query(func.count(TaskDB.id)).scalar() or 0
        active_tasks = session.query(func.count(TaskDB.id)).filter(TaskDB.done.is_(False)).scalar() or 0
        completed_tasks = total_tasks - active_tasks

        TASKS_TOTAL.set(total_tasks)
        ACTIVE_TASKS_COUNT.set(active_tasks)
        TASKS_BY_STATUS.labels(status="active").set(active_tasks)
        TASKS_BY_STATUS.labels(status="completed").set(completed_tasks)
    except Exception as exc:
        logger.warning("Failed to refresh task metrics: %s", exc)
    finally:
        if session is not None:
            session.close()


@app.middleware("http")
async def metrics_middleware(request: Request, call_next):
    # otherwise scraping /metrics would itself generate another HTTP request metric.
    if request.url.path == "/metrics":
        return await call_next(request)

    start_time = time.perf_counter()

    response = await call_next(request)

    duration = time.perf_counter() - start_time

    path = request.url.path
    method = request.method
    status = str(response.status_code)

    HTTP_REQUESTS_TOTAL.labels(
        method=method,
        path=path,
        status=status,
    ).inc()

    HTTP_REQUEST_DURATION_SECONDS.labels(
        method=method,
        path=path,
        status=status,
    ).observe(duration)

    return response


@app.get("/metrics")
async def metrics(request: Request):
    grafana_dashboards_url = os.environ.get("GRAFANA_DASHBOARDS_URL")
    accepts = request.headers.get("accept", "")

    if grafana_dashboards_url and "text/html" in accepts:
        return RedirectResponse(grafana_dashboards_url, status_code=307)

    refresh_task_metrics()

    return Response(
        content=generate_latest(),
        media_type="text/plain; version=0.0.4",
    )


@app.on_event("startup")
def on_startup():
    if os.environ.get("TESTING") == "1":
        return

    try:
        engine = get_engine()
    except KeyError:
        logger.warning("DATABASE_URL not set; skipping database initialization")
        return

    # Create tables only when a real database is configured.
    Base.metadata.create_all(bind=engine)
    refresh_task_metrics()


def invalidate_tasks_cache():
    """Attempt to remove the tasks list cache and log the outcome.

    Uses DEL first; if it reports 0 keys removed also try UNLINK
    (non-blocking) to cover any Redis server semantics.
    """
    key = "tasks:all"
    try:
        deleted = redis_client.delete(key)
        if deleted:
            logger.info("Cache invalidated: deleted %s key(s) for %s", deleted, key)
            return
        # If DEL returned 0, try UNLINK as a fallback (non-blocking removal)
        try:
            unlinked = redis_client.unlink(key)
            logger.info("Cache invalidated via UNLINK: %s for %s", unlinked, key)
            return
        except Exception as e:
            logger.debug("UNLINK failed for %s: %s", key, e)
        # Final check: log whether key still exists
        try:
            exists = redis_client.exists(key)
            logger.info("Post-invalidation existence for %s: %s", key, exists)
        except Exception:
            logger.debug("Could not check existence of %s", key)
    except Exception as e:
        logger.warning("Failed to invalidate tasks cache: %s", e)


class Task(BaseModel):
    title: str
    description: Optional[str] = None
    done: bool = False
    priority: Optional[str] = None


class TaskOut(Task):
    id: int


@app.get("/health")
def health():
    return {
        "status": "ok",
        "service": "tasks-api",
    }


@app.get("/tasks", response_model=List[TaskOut])
def list_tasks(db: Session = Depends(get_db)):
    cache_key = "tasks:all"

    # Check Redis first
    cached_tasks = redis_client.get(cache_key)

    if cached_tasks:
        logger.info("CACHE HIT: /tasks")
        return json.loads(cached_tasks)

    logger.info("CACHE MISS: /tasks")

    # Cache miss -> query MySQL
    tasks = db.query(TaskDB).all()

    result = [
        {
            "id": task.id,
            "title": task.title,
            "description": task.description,
            "done": task.done,
            "priority": task.priority,
        }
        for task in tasks
    ]

    # Store in Redis for 60 seconds
    redis_client.set(
        cache_key,
        json.dumps(result),
        ex=60,
    )

    return result


@app.post("/tasks", response_model=TaskOut, status_code=201)
def create_task(
    task: Task,
    db: Session = Depends(get_db),
):
    db_task = TaskDB(
        title=task.title,
        description=task.description,
        done=task.done,
        priority=task.priority,
    )

    db.add(db_task)
    db.commit()
    db.refresh(db_task)

    TASKS_CREATED_TOTAL.labels(priority=db_task.priority or "unspecified").inc()
    refresh_task_metrics()

    # Invalidate cached task list
    invalidate_tasks_cache()

    return {
        "id": db_task.id,
        "title": db_task.title,
        "description": db_task.description,
        "done": db_task.done,
        "priority": db_task.priority,
    }


@app.get("/tasks/{task_id}", response_model=TaskOut)
def get_task(
    task_id: int,
    db: Session = Depends(get_db),
):
    task = db.query(TaskDB).filter(TaskDB.id == task_id).first()

    if task is None:
        raise HTTPException(
            status_code=404,
            detail="Task not found",
        )

    return {
        "id": task.id,
        "title": task.title,
        "description": task.description,
        "done": task.done,
        "priority": task.priority,
    }


@app.patch("/tasks/{task_id}", response_model=TaskOut)
def update_task(
    task_id: int,
    task: Task,
    db: Session = Depends(get_db),
):
    db_task = db.query(TaskDB).filter(TaskDB.id == task_id).first()

    if db_task is None:
        raise HTTPException(
            status_code=404,
            detail="Task not found",
        )

    db_task.title = task.title
    db_task.description = task.description
    db_task.done = task.done
    db_task.priority = task.priority

    db.commit()
    db.refresh(db_task)

    refresh_task_metrics()

    # Invalidate cached task list
    invalidate_tasks_cache()

    return {
        "id": db_task.id,
        "title": db_task.title,
        "description": db_task.description,
        "done": db_task.done,
        "priority": db_task.priority,
    }


@app.delete("/tasks/{task_id}", status_code=204)
def delete_task(
    task_id: int,
    db: Session = Depends(get_db),
):
    db_task = db.query(TaskDB).filter(TaskDB.id == task_id).first()

    if db_task is None:
        raise HTTPException(
            status_code=404,
            detail="Task not found",
        )

    db.delete(db_task)
    db.commit()

    refresh_task_metrics()

    # Invalidate cached task list
    invalidate_tasks_cache()

    return None