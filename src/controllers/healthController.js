/**
 * 健康检查控制器
 */

export function healthCheck(req, res) {
  res.json({
    success: true,
    status: "ok",
    timestamp: new Date().toISOString(),
    service: "site-dashboard-server",
  });
}

