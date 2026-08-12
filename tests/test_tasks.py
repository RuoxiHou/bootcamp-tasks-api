from unittest.mock import MagicMock

from app.main import redis_client


def test_health(client):
    response = client.get("/health")

    assert response.status_code == 200
    assert response.json() == {
        "status": "ok",
        "service": "tasks-api",
    }


def test_list_tasks_empty(client):
    redis_client.get = MagicMock(return_value=None)
    redis_client.set = MagicMock()

    response = client.get("/tasks")

    assert response.status_code == 200
    assert response.json() == []


def test_create_task(client):
    redis_client.get = MagicMock(return_value=None)
    redis_client.set = MagicMock()
    redis_client.delete = MagicMock(return_value=0)
    redis_client.unlink = MagicMock(return_value=0)
    redis_client.exists = MagicMock(return_value=False)

    response = client.post(
        "/tasks",
        json={
            "title": "Test task",
            "description": "Created by pytest",
            "done": False,
            "priority": "high",
        },
    )

    assert response.status_code == 201

    data = response.json()

    assert data["id"] == 1
    assert data["title"] == "Test task"
    assert data["description"] == "Created by pytest"
    assert data["done"] is False
    assert data["priority"] == "high"


def test_get_task(client):
    redis_client.get = MagicMock(return_value=None)
    redis_client.set = MagicMock()
    redis_client.delete = MagicMock(return_value=0)
    redis_client.unlink = MagicMock(return_value=0)
    redis_client.exists = MagicMock(return_value=False)

    create_response = client.post(
        "/tasks",
        json={
            "title": "Get me",
            "description": "Test",
            "done": False,
            "priority": "medium",
        },
    )

    task_id = create_response.json()["id"]

    response = client.get(f"/tasks/{task_id}")

    assert response.status_code == 200
    assert response.json()["id"] == task_id
    assert response.json()["title"] == "Get me"


def test_get_nonexistent_task(client):
    response = client.get("/tasks/999")

    assert response.status_code == 404
    assert response.json()["detail"] == "Task not found"

def test_update_task(client):
    redis_client.get = MagicMock(return_value=None)
    redis_client.set = MagicMock()
    redis_client.delete = MagicMock(return_value=0)
    redis_client.unlink = MagicMock(return_value=0)
    redis_client.exists = MagicMock(return_value=False)

    create_response = client.post(
        "/tasks",
        json={
            "title": "Original title",
            "description": "Original",
            "done": False,
            "priority": "low",
        },
    )

    task_id = create_response.json()["id"]

    response = client.patch(
        f"/tasks/{task_id}",
        json={
            "title": "Updated title",
            "description": "Updated",
            "done": True,
            "priority": "high",
        },
    )

    assert response.status_code == 200

    data = response.json()

    assert data["id"] == task_id
    assert data["title"] == "Updated title"
    assert data["description"] == "Updated"
    assert data["done"] is True
    assert data["priority"] == "high"

def test_delete_task(client):
    redis_client.get = MagicMock(return_value=None)
    redis_client.set = MagicMock()
    redis_client.delete = MagicMock(return_value=1)

    create_response = client.post(
        "/tasks",
        json={
            "title": "Delete me",
            "description": "Temporary",
            "done": False,
            "priority": "low",
        },
    )

    task_id = create_response.json()["id"]

    response = client.delete(f"/tasks/{task_id}")

    assert response.status_code == 204

    response = client.get(f"/tasks/{task_id}")

    assert response.status_code == 404

