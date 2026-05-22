#!/bin/sh
set -e

# Generate env.js from environment variables at container start
cat > /usr/share/nginx/html/env.js <<EOF
window._env_ = {
  REACT_APP_BACKEND_URL: "${REACT_APP_BACKEND_URL}"
};
EOF

exec nginx -g 'daemon off;'
