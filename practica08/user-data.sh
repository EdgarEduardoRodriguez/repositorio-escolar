#!/bin/bash
set -euo pipefail

dnf install -y httpd

TOKEN=$(curl -fsS -X PUT \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" \
  http://169.254.169.254/latest/api/token)
INSTANCE_ID=$(curl -fsS \
  -H "X-aws-ec2-metadata-token: ${TOKEN}" \
  http://169.254.169.254/latest/meta-data/instance-id)
AVAILABILITY_ZONE=$(curl -fsS \
  -H "X-aws-ec2-metadata-token: ${TOKEN}" \
  http://169.254.169.254/latest/meta-data/placement/availability-zone)

cat > /var/www/html/index.html <<EOF
<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>Repositorio escolar - Alta disponibilidad</title>
  <style>
    body{font-family:Arial,sans-serif;background:#eef4fa;margin:0;display:grid;place-items:center;min-height:100vh;color:#17324d}
    main{background:white;border-top:8px solid #1f5f9f;border-radius:12px;box-shadow:0 12px 32px #0002;padding:36px;max-width:680px}
    h1{margin-top:0}.dato{background:#e7f1fb;padding:12px 16px;border-radius:8px;margin:10px 0}
  </style>
</head>
<body>
  <main>
    <h1>Repositorio escolar</h1>
    <p>Práctica 08 - Alta disponibilidad y escalamiento automático</p>
    <div class="dato"><strong>Instancia:</strong> ${INSTANCE_ID}</div>
    <div class="dato"><strong>Zona de disponibilidad:</strong> ${AVAILABILITY_ZONE}</div>
    <p>Respuesta servida correctamente por el grupo de escalamiento.</p>
  </main>
</body>
</html>
EOF

printf 'ok\n' > /var/www/html/health
systemctl enable --now httpd
