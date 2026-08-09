from fastapi import Depends, FastAPI, HTTPException
from pydantic import BaseModel
from typing import Optional, List

from sqlalchemy.orm import Session

from database import Base, engine, get_db
from models import TaskDB


app = FastAPI(
    title="Tasks API",
    description="Bootcamp demo app — Week 1/2/8",
)


# Create database tables when the application starts.
# For this first version we use SQLAlchemy directly.
# Later we can replace this with Alembic migrations.
Base.metadata.create_all(bind=engine)


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
    tasks = db.query(TaskDB).all()

    return [
        {
            "id": task.id,
            "title": task.title,
            "description": task.description,
            "done": task.done,
            "priority": task.priority,
        }
        for task in tasks
    ]


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

    return None