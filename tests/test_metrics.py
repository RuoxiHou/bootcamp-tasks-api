def test_metrics_endpoint(client):
    response = client.get("/metrics")

    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/plain")
    assert "http_requests_total" in response.text
    assert "http_request_duration_seconds" in response.text
    assert "active_tasks_count" in response.text
    assert "tasks_total" in response.text


def test_metrics_endpoint_redirects_browser_to_grafana(client, monkeypatch):
    dashboard_url = (
        "https://api.ruoxi-projects.space/metrics/grafana/d/"
        "tasks-api-observability/tasks-api-observability"
    )
    monkeypatch.setenv("GRAFANA_DASHBOARDS_URL", dashboard_url)

    response = client.get(
        "/metrics",
        headers={"Accept": "text/html"},
        follow_redirects=False,
    )

    assert response.status_code == 307
    assert response.headers["location"] == dashboard_url


def test_metrics_endpoint_keeps_scraper_output_when_grafana_is_configured(client, monkeypatch):
    monkeypatch.setenv(
        "GRAFANA_DASHBOARDS_URL",
        "https://api.ruoxi-projects.space/metrics/grafana/d/tasks-api-observability",
    )

    response = client.get("/metrics", headers={"Accept": "text/plain"})

    assert response.status_code == 200
    assert response.headers["content-type"].startswith("text/plain")
    assert "http_requests_total" in response.text