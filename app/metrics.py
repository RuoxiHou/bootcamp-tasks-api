from prometheus_client import Counter, Gauge, Histogram


HTTP_REQUESTS_TOTAL = Counter(
    "http_requests_total",
    "Total number of HTTP requests",
    ["method", "path", "status"],
)

HTTP_REQUEST_DURATION_SECONDS = Histogram(
    "http_request_duration_seconds",
    "HTTP request duration in seconds",
    ["method", "path", "status"],
)

TASKS_CREATED_TOTAL = Counter(
    "tasks_created_total",
    "Total number of tasks created",
    ["priority"],
)

for priority in ("low", "medium", "high"):
    TASKS_CREATED_TOTAL.labels(priority=priority)

ACTIVE_TASKS_COUNT = Gauge(
    "active_tasks_count",
    "Current number of active tasks",
)

TASKS_TOTAL = Gauge(
    "tasks_total",
    "Current total number of tasks",
)

TASKS_BY_STATUS = Gauge(
    "tasks_by_status",
    "Current number of tasks by completion status",
    ["status"],
)