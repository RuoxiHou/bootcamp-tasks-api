import os
import redis

# Use a plain Redis client for single-endpoint Azure Redis / Managed Redis
# The previous code used RedisCluster with parameters that do not match a
# single-host Azure Redis endpoint, which can cause commands (delete/get/set)
# to fail and result in stale cache data being served.
redis_client = redis.Redis(
    host=os.environ.get("REDIS_HOST"),
    port=int(os.environ.get("REDIS_PORT", "10000")),
    password=os.environ.get("REDIS_PASSWORD"),
    ssl=True,
    ssl_cert_reqs=None,
    socket_connect_timeout=5,
    socket_timeout=5,
    decode_responses=True,
)